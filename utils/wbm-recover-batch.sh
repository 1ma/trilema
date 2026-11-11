#!/usr/bin/env bash
# Batch-recover missing trilema.com articles from the Wayback Machine.
# Usage:
#   ./scripts/wbm-recover-batch.sh 2020          # all missing from 2020
#   ./scripts/wbm-recover-batch.sh missing.txt    # from a file, one YYYY/slug per line
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/scripts/wbm-recover-article.sh"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 YYYY | file-with-slugs" >&2
    exit 1
fi

arg="$1"

if [[ -f "$arg" ]]; then
    slugs=$(cat "$arg")
elif [[ "$arg" =~ ^20[0-9]{2}$ ]]; then
    slugs=$(python3 "$REPO/scripts/wbm-list-missing.py" "$arg")
else
    echo "Argument must be a year (YYYY) or a file with slugs" >&2
    exit 1
fi

total=$(echo "$slugs" | grep -c . || true)
if [[ "$total" -eq 0 ]]; then
    echo "Nothing to recover."
    exit 0
fi

echo "Recovering $total articles..."
i=0
ok=0
fail=0
skip=0

while IFS= read -r slug; do
    [[ -z "$slug" ]] && continue
    (( i++ ))
    result=$("$SCRIPT" "$slug" 2>/dev/null) || true
    case "$result" in
        OK*)   (( ok++ ));   printf "[%d/%d] %s\n" "$i" "$total" "$result" ;;
        SKIP*) (( skip++ )); printf "[%d/%d] %s\n" "$i" "$total" "$result" ;;
        FAIL*) (( fail++ )); printf "[%d/%d] %s\n" "$i" "$total" "$result" ;;
        *)     (( fail++ )); printf "[%d/%d] FAIL %s: %s\n" "$i" "$total" "$slug" "$result" ;;
    esac
done <<< "$slugs"

echo ""
echo "Done. OK: $ok | Skipped: $skip | Failed: $fail | Total: $total"
