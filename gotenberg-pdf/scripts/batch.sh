#!/bin/bash
# Gotenberg PDF API — Batch convert files
set -e

DIR=""
TYPE=""
OUTPUT_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case $1 in
    --dir) DIR="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[[ -z "$DIR" ]] && echo "❌ --dir required" && exit 1
[[ -z "$TYPE" ]] && echo "❌ --type required (html, docx, xlsx, pptx, odt, md)" && exit 1
OUTPUT_DIR="${OUTPUT_DIR:-./pdfs}"
mkdir -p "$OUTPUT_DIR"

# Map type to convert mode
case "$TYPE" in
  html|htm) MODE="--html" ;;
  md|markdown) MODE="--markdown" ;;
  docx|xlsx|pptx|odt|ods|odp) MODE="--office" ;;
  *) echo "❌ Unsupported type: $TYPE"; exit 1 ;;
esac

COUNT=0
FAILED=0

for file in "$DIR"/*."$TYPE"; do
  [[ ! -f "$file" ]] && continue
  BASENAME=$(basename "$file" ".$TYPE")
  OUTPUT_FILE="$OUTPUT_DIR/${BASENAME}.pdf"
  
  echo "Converting: $file → $OUTPUT_FILE"
  if bash "$SCRIPT_DIR/convert.sh" $MODE "$file" --output "$OUTPUT_FILE" 2>/dev/null; then
    COUNT=$((COUNT + 1))
  else
    echo "  ⚠️  Failed: $file"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "📊 Batch complete: $COUNT converted, $FAILED failed"
echo "   Output: $OUTPUT_DIR/"
