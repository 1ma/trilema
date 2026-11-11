#!/usr/bin/env bash
# Recover missing articles from the Wayback Machine.
# Reads relative URLs from stdin, one per line: /YYYY/slug/
# Skips articles that already exist locally.
# Usage: ./utils/list-month-posts.sh 2008/12 | ./utils/recover-missing.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="http://trilema.com"
WBM_API="https://archive.org/wayback/available"
SLEEP_BETWEEN=1

die()  { echo "FAIL $1: $2" >&2; }
info() { echo "  $*" >&2; }

wbm_fetch() {
    local url="$1" out="$2" attempt=0 max=3 code
    while (( attempt < max )); do
        code=$(curl -sL -o "$out" -w '%{http_code}' "$url")
        case "$code" in
            200) return 0 ;;
            429) info "rate-limited, waiting 30s..."; sleep 30 ;;
            503|502|500) info "server error ($code), waiting 10s..."; sleep 10 ;;
            404) return 1 ;;
            *)   info "unexpected HTTP $code"; return 1 ;;
        esac
        (( attempt++ ))
    done
    return 1
}

recover_one() {
    local url="$1"
    # Normalize: strip leading/trailing slashes
    local path="${url#/}"
    path="${path%/}"

    local dest="$REPO/$path"

    if [[ -f "$dest/index.html" ]]; then
        echo "SKIP $path: already exists"
        return
    fi

    # Query WBM availability
    info "querying WBM for $path..."
    local api_response timestamp
    api_response=$(curl -s "$WBM_API?url=$DOMAIN/$path")
    timestamp=$(echo "$api_response" | python3 -c "
import sys, json
d = json.load(sys.stdin)
s = d.get('archived_snapshots', {}).get('closest', {})
if s.get('available'):
    print(s['timestamp'])
else:
    print('')
" 2>/dev/null)

    if [[ -z "$timestamp" ]]; then
        echo "MISS $path: not found on WBM"
        return
    fi

    info "found snapshot $timestamp"

    # Fetch raw HTML (id_ = original without WBM toolbar)
    sleep "$SLEEP_BETWEEN"
    local tmpfile
    tmpfile=$(mktemp)

    local raw_url="https://web.archive.org/web/${timestamp}id_/$DOMAIN/$path/"
    if ! wbm_fetch "$raw_url" "$tmpfile"; then
        echo "FAIL $path: could not fetch from WBM"
        rm -f "$tmpfile"
        return
    fi

    # Rewrite absolute URLs to relative
    sed -i \
        -e "s|https\?://trilema\.com/|/|g" \
        -e "s|https\?://trilema\.com|/|g" \
        "$tmpfile"

    # Normalize splash background image
    sed -i -E 's#bg_[a-z0-9_]*\.(jpg|jpeg|png|gif|webp)#bg_oct2009.jpg#g' "$tmpfile"

    # Download missing wp-content assets
    local assets_downloaded=0
    while IFS= read -r asset_path; do
        [[ -z "$asset_path" ]] && continue
        local local_path="$REPO$asset_path"
        if [[ ! -f "$local_path" ]]; then
            info "downloading missing asset: $asset_path"
            sleep "$SLEEP_BETWEEN"
            mkdir -p "$(dirname "$local_path")"
            local asset_url="https://web.archive.org/web/${timestamp}id_/$DOMAIN$asset_path"
            if wbm_fetch "$asset_url" "$local_path"; then
                (( assets_downloaded++ )) || true
            else
                info "warning: could not download $asset_path"
                rm -f "$local_path"
            fi
        fi
    done < <(grep -oP '(?:src|href)="(/wp-content/[^"]+)"' "$tmpfile" | sed 's/.*="//;s/"$//' | sort -u)

    # Save
    mkdir -p "$dest"
    mv "$tmpfile" "$dest/index.html"

    echo "OK $path (assets: $assets_downloaded)"
}

# Read URLs from stdin
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    recover_one "$line"
    sleep "$SLEEP_BETWEEN"
done
