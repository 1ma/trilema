#!/usr/bin/env bash
# Download missing wp-content/uploads assets for all posts in a month.
# Usage: ./utils/recover-month-assets.sh YYYY/MM
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="http://trilema.com"
SLEEP_BETWEEN=0.4

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
            *)   info "unexpected HTTP $code for $url"; return 1 ;;
        esac
        (( attempt++ ))
    done
    return 1
}

cdx_timestamps() {
    local asset_path="$1"
    curl -s "https://web.archive.org/cdx/search/cdx?url=trilema.com${asset_path}&output=json&fl=timestamp,statuscode&filter=statuscode:200" \
        | python3 -c "
import sys, json
try:
    rows = json.load(sys.stdin)
    for ts, _ in reversed(rows[1:]):
        print(ts)
except: pass
" 2>/dev/null
}

extract_assets() {
    local file="$1"
    {
        grep -oP '(?:src|href)="(/wp-content/[^"]+)"' "$file" 2>/dev/null | sed 's/.*="//;s/"$//' || true
        grep -oP '(?:src|href)=(/wp-content/[^ >"'"'"']+)' "$file" 2>/dev/null | sed 's/.*=//' || true
        grep -oP "url\(['\"]?(/wp-content/[^)\"']+)" "$file" 2>/dev/null | sed "s/.*url(//;s/['\"]//g" || true
    } | sort -u
}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 YYYY/MM" >&2
    exit 1
fi

path="$1"
year="${path%%/*}"
month_page="$REPO/$path/index.html"

if [[ ! -f "$month_page" ]]; then
    echo "ABORT: $month_page does not exist" >&2
    exit 1
fi

# Get post slugs from the month index
post_slugs=$(grep -oP '<div class="title"><a href="\K/'"$year"'/[^"]+' "$month_page")

total_missing=0
total_downloaded=0
total_failed=0

for slug in $post_slugs; do
    slug="${slug#/}"
    slug="${slug%/}"
    article="$REPO/$slug/index.html"

    if [[ ! -f "$article" ]]; then
        echo "SKIP $slug: article not downloaded yet"
        continue
    fi

    assets=$(extract_assets "$article")
    [[ -z "$assets" ]] && continue

    missing=()
    while IFS= read -r asset_path; do
        [[ -z "$asset_path" ]] && continue
        [[ -f "$REPO$asset_path" ]] || missing+=("$asset_path")
    done <<< "$assets"

    [[ ${#missing[@]} -eq 0 ]] && continue

    echo "$slug: ${#missing[@]} missing assets"
    (( total_missing += ${#missing[@]} ))

    i=0
    for asset_path in "${missing[@]}"; do
        (( i++ )) || true
        local_path="$REPO$asset_path"
        mkdir -p "$(dirname "$local_path")"

        info "[$i/${#missing[@]}] downloading $asset_path"
        sleep "$SLEEP_BETWEEN"
        asset_url="https://web.archive.org/web/2id_/$DOMAIN$asset_path"
        if wbm_fetch "$asset_url" "$local_path"; then
            (( total_downloaded++ )) || true
        else
            # Fallback: query CDX for older snapshots
            info "  latest failed, querying CDX..."
            sleep "$SLEEP_BETWEEN"
            got_it=false
            while IFS= read -r ts; do
                [[ -z "$ts" ]] && continue
                info "  trying snapshot $ts"
                sleep "$SLEEP_BETWEEN"
                if wbm_fetch "https://web.archive.org/web/${ts}id_/$DOMAIN$asset_path" "$local_path"; then
                    got_it=true
                    break
                fi
            done < <(cdx_timestamps "$asset_path")

            if $got_it; then
                (( total_downloaded++ )) || true
            else
                info "MISS $asset_path"
                rm -f "$local_path"
                (( total_failed++ )) || true
            fi
        fi
    done
done

echo "Done: $total_missing missing, $total_downloaded downloaded, $total_failed failed"
