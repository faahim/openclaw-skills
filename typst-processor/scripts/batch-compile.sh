#!/bin/bash
# Batch compile all .typ files in a directory
set -euo pipefail

DIR="${1:-.}"
TYPST="${TYPST_BIN:-typst}"

if ! command -v "$TYPST" >/dev/null 2>&1; then
  if [ -f "$HOME/.local/bin/typst" ]; then
    TYPST="$HOME/.local/bin/typst"
  else
    echo "❌ Typst not found. Run: bash scripts/install.sh"
    exit 1
  fi
fi

COUNT=0
ERRORS=0

for f in "$DIR"/*.typ; do
  [ -f "$f" ] || continue
  OUT="${f%.typ}.pdf"
  echo -n "📄 $(basename "$f") → $(basename "$OUT")... "
  if $TYPST compile "$f" "$OUT" 2>/dev/null; then
    echo "✅"
    ((COUNT++))
  else
    echo "❌"
    ((ERRORS++))
  fi
done

echo ""
echo "Done: $COUNT compiled, $ERRORS errors"
