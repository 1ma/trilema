#!/usr/bin/env bash
# List missing articles from a monthly archive page.
# Usage: ./utils/list-missing-month-posts.sh YYYY/MM
# Output: one /YYYY/slug/ per line (only posts not yet downloaded)
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 YYYY/MM" >&2
    exit 1
fi

path="$1"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
page="$REPO/$path/index.html"

if [[ ! -f "$page" ]]; then
    echo "ABORT: $page does not exist" >&2
    exit 1
fi

year="${path%%/*}"

grep -oP '<div class="title"><a href="\K/'"$year"'/[^"]+' "$page" \
    | while IFS= read -r slug; do
    local_path="$REPO${slug}/index.html"
    [[ -f "$local_path" ]] && continue
    echo "${slug}/"
done
