#!/bin/bash
# Pandoc Document Converter — Merge multiple files into one output
# Usage: bash merge-convert.sh <input-dir> <output-file> [pandoc-options...]

set -e

INPUT_DIR="$1"
OUTPUT="$2"
shift 2 2>/dev/null || true

if [[ -z "$INPUT_DIR" || -z "$OUTPUT" ]]; then
  echo "Usage: bash merge-convert.sh <input-dir> <output-file> [pandoc-options...]"
  echo ""
  echo "Examples:"
  echo "  bash merge-convert.sh ./chapters/ book.pdf --toc"
  echo "  bash merge-convert.sh ./docs/ manual.docx"
  echo "  bash merge-convert.sh ./sections/ output.epub --metadata title='My Book'"
  exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "❌ Directory not found: $INPUT_DIR"
  exit 1
fi

if ! command -v pandoc &>/dev/null; then
  echo "❌ Pandoc not found. Run: bash scripts/install.sh"
  exit 1
fi

# Find and sort input files
FILES=()
while IFS= read -r -d '' file; do
  FILES+=("$file")
done < <(find "$INPUT_DIR" -maxdepth 1 \( -name "*.md" -o -name "*.markdown" -o -name "*.txt" -o -name "*.html" -o -name "*.rst" \) -type f -print0 | sort -z)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "⚠️  No files found in $INPUT_DIR"
  exit 0
fi

# Detect PDF engine
OUT_EXT="${OUTPUT##*.}"
PDF_ENGINE=""
if [[ "$OUT_EXT" == "pdf" ]]; then
  if command -v xelatex &>/dev/null; then
    PDF_ENGINE="--pdf-engine=xelatex"
  elif command -v pdflatex &>/dev/null; then
    PDF_ENGINE="--pdf-engine=pdflatex"
  elif command -v wkhtmltopdf &>/dev/null; then
    PDF_ENGINE="--pdf-engine=wkhtmltopdf"
  fi
fi

# Create output directory
OUT_DIR=$(dirname "$OUTPUT")
[[ "$OUT_DIR" != "." ]] && mkdir -p "$OUT_DIR"

echo "📚 Merging ${#FILES[@]} files → $OUTPUT"
for f in "${FILES[@]}"; do
  echo "   • $(basename "$f")"
done

START_TIME=$(date +%s%3N)

pandoc "${FILES[@]}" -o "$OUTPUT" $PDF_ENGINE "$@"

END_TIME=$(date +%s%3N)
ELAPSED=$(( END_TIME - START_TIME ))

OUT_SIZE=$(wc -c < "$OUTPUT" | tr -d ' ')
if (( OUT_SIZE >= 1048576 )); then
  SIZE_STR="$(echo "scale=1; $OUT_SIZE/1048576" | bc)MB"
elif (( OUT_SIZE >= 1024 )); then
  SIZE_STR="$(echo "scale=1; $OUT_SIZE/1024" | bc)KB"
else
  SIZE_STR="${OUT_SIZE}B"
fi

echo ""
echo "✅ Merged ${#FILES[@]} files → $OUTPUT"
echo "   Size: $SIZE_STR | Time: ${ELAPSED}ms"
