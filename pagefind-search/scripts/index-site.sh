#!/bin/bash
# Index a static site with Pagefind
set -euo pipefail

SITE_DIR="${1:?Usage: index-site.sh <site-dir> [output-subdir]}"
OUTPUT_SUBDIR="${2:-_pagefind}"

if [ ! -d "$SITE_DIR" ]; then
  echo "❌ Directory not found: $SITE_DIR"
  exit 1
fi

# Count HTML files
HTML_COUNT=$(find "$SITE_DIR" -name "*.html" | wc -l)
if [ "$HTML_COUNT" -eq 0 ]; then
  echo "❌ No HTML files found in $SITE_DIR"
  exit 1
fi

echo "📄 Found $HTML_COUNT HTML files in $SITE_DIR"
echo "🔍 Indexing with Pagefind..."

# Find pagefind binary
PAGEFIND=""
for loc in pagefind "$HOME/.local/bin/pagefind" /usr/local/bin/pagefind; do
  if command -v "$loc" &>/dev/null || [ -x "$loc" ]; then
    PAGEFIND="$loc"
    break
  fi
done

if [ -z "$PAGEFIND" ]; then
  echo "❌ Pagefind not found. Run: bash scripts/install.sh"
  exit 1
fi

# Run indexing
"$PAGEFIND" --site "$SITE_DIR" --output-subdir "$OUTPUT_SUBDIR"

echo ""
echo "✅ Indexing complete!"
echo "📁 Search index at: $SITE_DIR/$OUTPUT_SUBDIR/"
echo ""
echo "Add to your HTML:"
echo '  <link href="/'$OUTPUT_SUBDIR'/pagefind-ui.css" rel="stylesheet">'
echo '  <script src="/'$OUTPUT_SUBDIR'/pagefind-ui.js"></script>'
echo '  <div id="search"></div>'
echo '  <script>new PagefindUI({ element: "#search", showSubResults: true });</script>'
