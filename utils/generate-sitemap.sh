#!/bin/bash
set -euo pipefail

DOMAIN="https://trilema-mirror.pages.dev"
OUT="sitemap.xml"

cat > "$OUT" <<'HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
HEADER

find . -name 'index.html' -not -path './.git/*' -not -path './.tokensave/*' \
    -not -path '*/feed/*' -not -path '*/trackback/*' \
    | sed 's|^\./||; s|/index\.html$|/|; s|^index\.html$|/|' \
    | sort \
    | while IFS= read -r path; do
    echo "  <url><loc>${DOMAIN}/${path}</loc></url>"
done >> "$OUT"

echo '</urlset>' >> "$OUT"

echo "Generated $OUT with $(grep -c '<url>' "$OUT") URLs"
