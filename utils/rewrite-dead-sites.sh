#!/usr/bin/env bash
# Rewrite dead external site URLs to local copies across all index.html files.
# Usage: ./utils/rewrite-dead-sites.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

# Rewrite dead external site URLs to local copies
dead_dir="$REPO/dead_external_sites"
if [[ -d "$dead_dir" ]]; then
    sed_args=()
    while IFS= read -r asset; do
        rel="${asset#$dead_dir/}"
        domain="${rel%%/*}"
        sed_args+=(-e "s|http://${domain//./\\.}/${rel#*/}|/dead_external_sites/${rel}|g")
    done < <(find "$dead_dir" -type f)
fi

if [[ ${#sed_args[@]} -eq 0 ]]; then
    echo "No files found in dead_external_sites/" >&2
    exit 1
fi

echo "Substitutions loaded: ${#sed_args[@]}"
printf '  %s\n' "${sed_args[@]}"

find "$REPO" -path "$REPO/wp-content" -prune -o -name 'index.html' -print \
    -exec sed -i "${sed_args[@]}" {} +

echo "Done."
