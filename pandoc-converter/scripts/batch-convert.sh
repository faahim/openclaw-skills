#!/bin/bash
# Pandoc Document Converter — Batch conversion
# Usage: bash batch-convert.sh <input-dir> <output-format> [pandoc-options...]

set -e

INPUT_DIR="$1"
OUT_FORMAT="$2"
shift 2 2>/dev/null || true

PARALLEL=1
EXTRA_ARGS=()

# Parse our args vs pandoc args
while [[ $# -gt 0 ]]; do
  case $1 in
    --parallel) PARALLEL="$2"; shift 2 ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done

if [[ -z "$INPUT_DIR" || -z "$OUT_FORMAT" ]]; then
  echo "Usage: bash batch-convert.sh <input-dir> <output-format> [--parallel N] [pandoc-options...]"
  echo ""
  echo "Examples:"
  echo "  bash batch-convert.sh ./docs/ pdf"
  echo "  bash batch-convert.sh ./docs/ pdf --toc --parallel 4"
  echo "  bash batch-convert.sh ./pages/ docx"
  exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "❌ Directory not found: $INPUT_DIR"
  exit 1
fi

# Map format to extensions to search for
case "$OUT_FORMAT" in
  pdf|docx|html|epub|rst|odt|rtf|pptx|latex|tex)
    # Accept common input formats
    PATTERN="*.md *.markdown *.html *.htm *.docx *.tex *.rst *.org *.textile"
    ;;
  md|markdown)
    PATTERN="*.html *.htm *.docx *.tex *.rst *.org"
    OUT_FORMAT="md"
    ;;
  *)
    echo "❌ Unsupported output format: $OUT_FORMAT"
    exit 1
    ;;
esac

# Find input files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${INPUT_DIR%/}_${OUT_FORMAT}"
mkdir -p "$OUTPUT_DIR"

# Collect files
FILES=()
for pat in $PATTERN; do
  while IFS= read -r -d '' file; do
    # Don't convert to same format
    ext="${file##*.}"
    if [[ "$ext" != "$OUT_FORMAT" ]]; then
      FILES+=("$file")
    fi
  done < <(find "$INPUT_DIR" -maxdepth 1 -name "$pat" -type f -print0 2>/dev/null | sort -z)
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "⚠️  No convertible files found in $INPUT_DIR"
  exit 0
fi

echo "📂 Batch converting ${#FILES[@]} files → $OUT_FORMAT"
echo "   Output: $OUTPUT_DIR/"
echo ""

SUCCESS=0
FAILED=0

convert_file() {
  local input="$1"
  local basename=$(basename "$input")
  local name="${basename%.*}"
  local output="${OUTPUT_DIR}/${name}.${OUT_FORMAT}"

  if bash "$SCRIPT_DIR/convert.sh" "$input" "$output" "${EXTRA_ARGS[@]}" 2>/dev/null; then
    return 0
  else
    echo "❌ Failed: $input"
    return 1
  fi
}

if [[ "$PARALLEL" -gt 1 ]] && command -v parallel &>/dev/null; then
  # GNU parallel available
  export -f convert_file
  export SCRIPT_DIR OUTPUT_DIR OUT_FORMAT
  export EXTRA_ARGS
  printf '%s\n' "${FILES[@]}" | parallel -j "$PARALLEL" convert_file {}
else
  # Sequential
  for file in "${FILES[@]}"; do
    if convert_file "$file"; then
      ((SUCCESS++))
    else
      ((FAILED++))
    fi
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Batch complete: $SUCCESS converted, $FAILED failed"
echo "   Output: $OUTPUT_DIR/"
