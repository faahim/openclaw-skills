#!/bin/bash
# Pandoc Document Converter — Single file conversion
# Usage: bash convert.sh <input> <output> [pandoc-options...]

set -e

INPUT="$1"
OUTPUT="$2"
shift 2 2>/dev/null || true

if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
  echo "Usage: bash convert.sh <input-file> <output-file> [pandoc-options...]"
  echo ""
  echo "Examples:"
  echo "  bash convert.sh README.md output.pdf"
  echo "  bash convert.sh README.md output.pdf --toc --pdf-engine=xelatex"
  echo "  bash convert.sh page.html output.md --wrap=none"
  echo "  bash convert.sh report.docx output.md --extract-media=./media/"
  exit 1
fi

# Check pandoc
if ! command -v pandoc &>/dev/null; then
  echo "❌ Pandoc not found. Run: bash scripts/install.sh"
  exit 1
fi

# Check input exists
if [[ ! -f "$INPUT" ]]; then
  echo "❌ Input file not found: $INPUT"
  exit 1
fi

# Detect output format from extension
OUT_EXT="${OUTPUT##*.}"
IN_EXT="${INPUT##*.}"

# Auto-select PDF engine if not specified
PDF_ENGINE=""
if [[ "$OUT_EXT" == "pdf" ]]; then
  HAS_ENGINE=false
  for arg in "$@"; do
    if [[ "$arg" == --pdf-engine=* ]]; then
      HAS_ENGINE=true
      break
    fi
  done

  if [[ "$HAS_ENGINE" == "false" ]]; then
    if command -v xelatex &>/dev/null; then
      PDF_ENGINE="--pdf-engine=xelatex"
    elif command -v pdflatex &>/dev/null; then
      PDF_ENGINE="--pdf-engine=pdflatex"
    elif command -v wkhtmltopdf &>/dev/null; then
      PDF_ENGINE="--pdf-engine=wkhtmltopdf"
    elif command -v weasyprint &>/dev/null; then
      PDF_ENGINE="--pdf-engine=weasyprint"
    else
      echo "❌ No PDF engine found. Install one of: texlive, wkhtmltopdf, weasyprint"
      echo "   Quick fix: sudo apt-get install -y wkhtmltopdf"
      exit 1
    fi
  fi
fi

# Create output directory if needed
OUT_DIR=$(dirname "$OUTPUT")
if [[ "$OUT_DIR" != "." && "$OUT_DIR" != "" ]]; then
  mkdir -p "$OUT_DIR"
fi

# Get input file size
IN_SIZE=$(wc -c < "$INPUT" | tr -d ' ')
START_TIME=$(date +%s%3N)

# Run pandoc
echo "🔄 Converting: $INPUT → $OUTPUT"
pandoc "$INPUT" -o "$OUTPUT" $PDF_ENGINE "$@"

END_TIME=$(date +%s%3N)
ELAPSED=$(( (END_TIME - START_TIME) ))

# Get output info
OUT_SIZE=$(wc -c < "$OUTPUT" | tr -d ' ')

# Human-readable sizes
format_size() {
  local bytes=$1
  if (( bytes >= 1048576 )); then
    echo "$(echo "scale=1; $bytes/1048576" | bc)MB"
  elif (( bytes >= 1024 )); then
    echo "$(echo "scale=1; $bytes/1024" | bc)KB"
  else
    echo "${bytes}B"
  fi
}

IN_HUMAN=$(format_size "$IN_SIZE")
OUT_HUMAN=$(format_size "$OUT_SIZE")

# Page count for PDF
PAGES=""
if [[ "$OUT_EXT" == "pdf" ]] && command -v pdfinfo &>/dev/null; then
  PAGE_COUNT=$(pdfinfo "$OUTPUT" 2>/dev/null | grep "Pages:" | awk '{print $2}')
  if [[ -n "$PAGE_COUNT" ]]; then
    PAGES=" | Pages: $PAGE_COUNT"
  fi
fi

echo "✅ Converted $INPUT → $OUTPUT"
echo "   Input: ${IN_HUMAN} ($IN_EXT) | Output: ${OUT_HUMAN} ($OUT_EXT)${PAGES} | Time: ${ELAPSED}ms"
