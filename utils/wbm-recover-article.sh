#!/usr/bin/env bash
# Recover a single trilema.com article from the Wayback Machine.
# Usage: ./utils/wbm-recover-article.sh YYYY/slug
# Example: ./utils/wbm-recover-article.sh 2015/basic-bitcoin-competency-certification
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="http://trilema.com"
WBM_API="https://archive.org/wayback/available"
SLEEP_BETWEEN=1

die()  { echo "FAIL $1: $2" >&2; exit 1; }
info() { echo "  $*" >&2; }

wbm_fetch() {
    local url="$1" out="$2" attempt=0 max=3 code
    while (( attempt < max )); do
        code=$(curl -s -o "$out" -w '%{http_code}' "$url")
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

# --- Args ---
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 YYYY/slug" >&2
    exit 1
fi

path="$1"
year="${path%%/*}"
slug="${path#*/}"
dest="$REPO/$year/$slug"

if [[ -f "$dest/index.html" ]]; then
    echo "SKIP $path: already exists"
    exit 0
fi

# --- Query WBM availability ---
info "querying WBM for $path..."
api_response=$(curl -s "$WBM_API?url=$DOMAIN/$path")
available=$(echo "$api_response" | python3 -c "
import sys, json
d = json.load(sys.stdin)
s = d.get('archived_snapshots', {}).get('closest', {})
if s.get('available'):
    print(s['timestamp'])
else:
    print('')
" 2>/dev/null)

if [[ -z "$available" ]]; then
    die "$path" "not found on WBM"
fi

timestamp="$available"
info "found snapshot $timestamp"

# --- Fetch raw HTML ---
sleep "$SLEEP_BETWEEN"
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

raw_url="https://web.archive.org/web/${timestamp}id_/$DOMAIN/$path/"
if ! wbm_fetch "$raw_url" "$tmpfile"; then
    die "$path" "failed to fetch $raw_url"
fi

# --- Rewrite URLs and normalize background ---
sed -i \
    -e "s|http://trilema\.com/|/|g" \
    -e "s|http://trilema\.com|/|g" \
    "$tmpfile"
sed -i -E 's#bg_[a-z0-9_]*\.(jpg|jpeg|png|gif|webp)#bg_oct2009.jpg#g' "$tmpfile"

# --- Check for missing assets ---
assets_downloaded=0
while IFS= read -r asset_path; do
    [[ -z "$asset_path" ]] && continue
    local_path="$REPO$asset_path"
    if [[ ! -f "$local_path" ]]; then
        info "downloading missing asset: $asset_path"
        sleep "$SLEEP_BETWEEN"
        asset_dir=$(dirname "$local_path")
        mkdir -p "$asset_dir"
        asset_url="https://web.archive.org/web/${timestamp}id_/$DOMAIN$asset_path"
        if wbm_fetch "$asset_url" "$local_path"; then
            (( assets_downloaded++ ))
        else
            info "warning: could not download $asset_path"
            rm -f "$local_path"
        fi
    fi
done < <(grep -oP '(?:src|href)="(/wp-content/[^"]+)"' "$tmpfile" | sed 's/.*="//;s/"$//' | sort -u)

# --- Save ---
mkdir -p "$dest"
mv "$tmpfile" "$dest/index.html"
trap - EXIT

echo "OK $path (assets downloaded: $assets_downloaded)"
