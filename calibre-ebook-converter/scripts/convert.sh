#!/bin/bash
# Ebook format converter using Calibre
set -e

BATCH_MODE=false
BATCH_DIR=""
FORMAT="${CALIBRE_DEFAULT_FORMAT:-mobi}"
OUTPUT_DIR="${CALIBRE_OUTPUT_DIR:-}"
FROM_FORMAT=""
EXTRA_ARGS=""
INPUT_FILE=""
OUTPUT_FILE=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0") <input> <output> [--extra "args"]
  $(basename "$0") --batch <dir> --format <fmt> [--output <dir>] [--from <fmt>] [--extra "args"]

Single file:
  $(basename "$0") book.epub book.mobi
  $(basename "$0") book.epub book.pdf --extra "--pdf-default-font-size 14"

Batch:
  $(basename "$0") --batch ~/Books --format mobi
  $(basename "$0") --batch ~/Books --format pdf --output ~/PDFs --from epub
EOF
  exit 1
}

# Check calibre
if ! command -v ebook-convert &>/dev/null; then
  echo "❌ ebook-convert not found. Run: bash scripts/install.sh"
  exit 1
fi

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --batch) BATCH_MODE=true; BATCH_DIR="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --from) FROM_FORMAT="$2"; shift 2 ;;
    --extra) EXTRA_ARGS="$2"; shift 2 ;;
    --help|-h) usage ;;
    *)
      if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE="$1"
      elif [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="$1"
      fi
      shift ;;
  esac
done

convert_file() {
  local input="$1"
  local output="$2"
  local label="$3"
  
  local start=$(date +%s%3N 2>/dev/null || date +%s)
  
  if [[ -n "$label" ]]; then
    printf "%s Converting: %s → %s ... " "$label" "$(basename "$input")" "${output##*.}"
  fi
  
  if eval ebook-convert "\"$input\"" "\"$output\"" $EXTRA_ARGS >/dev/null 2>&1; then
    local end=$(date +%s%3N 2>/dev/null || date +%s)
    local elapsed=$(( (end - start) ))
    if [[ $elapsed -gt 1000 ]]; then
      printf "✅ (%.1fs)\n" "$(echo "scale=1; $elapsed/1000" | bc 2>/dev/null || echo "${elapsed}ms")"
    else
      printf "✅ (%sms)\n" "$elapsed"
    fi
    return 0
  else
    printf "❌ FAILED\n"
    return 1
  fi
}

if [[ "$BATCH_MODE" == true ]]; then
  # Batch mode
  [[ -z "$BATCH_DIR" ]] && { echo "❌ --batch requires a directory"; exit 1; }
  [[ ! -d "$BATCH_DIR" ]] && { echo "❌ Directory not found: $BATCH_DIR"; exit 1; }
  
  # Set output dir
  [[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$BATCH_DIR/converted-$FORMAT"
  mkdir -p "$OUTPUT_DIR"
  
  # Find files
  if [[ -n "$FROM_FORMAT" ]]; then
    PATTERN="*.$FROM_FORMAT"
  else
    PATTERN="*.epub *.mobi *.azw3 *.pdf *.docx *.odt *.rtf *.txt *.html *.fb2 *.lit *.cbz *.cbr"
  fi
  
  FILES=()
  if [[ -n "$FROM_FORMAT" ]]; then
    while IFS= read -r -d '' f; do
      FILES+=("$f")
    done < <(find "$BATCH_DIR" -maxdepth 1 -name "*.$FROM_FORMAT" -print0 2>/dev/null)
  else
    for ext in epub mobi azw3 pdf docx odt rtf txt html fb2 lit cbz cbr; do
      while IFS= read -r -d '' f; do
        FILES+=("$f")
      done < <(find "$BATCH_DIR" -maxdepth 1 -name "*.$ext" -print0 2>/dev/null)
    done
  fi
  
  TOTAL=${#FILES[@]}
  [[ $TOTAL -eq 0 ]] && { echo "❌ No ebook files found in $BATCH_DIR"; exit 1; }
  
  echo "📚 Found $TOTAL files to convert to $FORMAT"
  echo ""
  
  SUCCESS=0
  FAILED=0
  
  for i in "${!FILES[@]}"; do
    FILE="${FILES[$i]}"
    BASENAME="$(basename "${FILE%.*}")"
    OUTPUT="$OUTPUT_DIR/$BASENAME.$FORMAT"
    
    LABEL="[$(( i + 1 ))/$TOTAL]"
    
    if convert_file "$FILE" "$OUTPUT" "$LABEL"; then
      ((SUCCESS++))
    else
      ((FAILED++))
    fi
  done
  
  echo ""
  echo "✅ Batch complete: $SUCCESS/$TOTAL converted, $FAILED failed"
  echo "Output: $OUTPUT_DIR/"
  
else
  # Single file mode
  [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]] && usage
  [[ ! -f "$INPUT_FILE" ]] && { echo "❌ File not found: $INPUT_FILE"; exit 1; }
  
  echo "📖 Converting: $(basename "$INPUT_FILE") → $(basename "$OUTPUT_FILE")"
  convert_file "$INPUT_FILE" "$OUTPUT_FILE" ""
  echo "✅ Done: $OUTPUT_FILE"
fi
