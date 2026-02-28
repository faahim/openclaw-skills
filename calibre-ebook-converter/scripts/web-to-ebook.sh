#!/bin/bash
# Convert web page to ebook using Calibre
set -e

if ! command -v ebook-convert &>/dev/null; then
  echo "❌ ebook-convert not found. Run: bash scripts/install.sh"
  exit 1
fi

URL="$1"
OUTPUT="${2:-output.epub}"
TITLE=""
EXTRA_ARGS=""

shift 2 2>/dev/null || true

while [[ $# -gt 0 ]]; do
  case $1 in
    --title) TITLE="$2"; shift 2 ;;
    --extra) EXTRA_ARGS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -z "$URL" ]] && { echo "Usage: $(basename "$0") <url> [output.epub] [--title \"Title\"]"; exit 1; }

echo "🌐 Fetching: $URL"

# Create temp file for the recipe
TMPDIR=$(mktemp -d)
RECIPE="$TMPDIR/web.recipe"

cat > "$RECIPE" <<RECIPE_EOF
from calibre.web.feeds.recipes import BasicNewsRecipe

class WebPageRecipe(BasicNewsRecipe):
    title = '${TITLE:-Web Article}'
    no_stylesheets = True
    remove_javascript = True
    use_embedded_content = False
    
    def build_index(self):
        return '$URL'
RECIPE_EOF

# Try direct conversion first (simpler)
echo "📖 Converting to $(basename "$OUTPUT")..."

TITLE_ARG=""
[[ -n "$TITLE" ]] && TITLE_ARG="--title \"$TITLE\""

if eval ebook-convert "\"$URL\"" "\"$OUTPUT\"" $TITLE_ARG $EXTRA_ARGS 2>/dev/null; then
  echo "✅ Saved: $OUTPUT"
else
  echo "❌ Conversion failed. URL might not be accessible or format unsupported."
  exit 1
fi

rm -rf "$TMPDIR"
