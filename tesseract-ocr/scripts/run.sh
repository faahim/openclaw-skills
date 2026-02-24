#!/bin/bash
# Tesseract OCR Tool — Extract text from images and PDFs
set -euo pipefail

# Defaults
INPUT=""
OUTPUT=""
FORMAT="txt"
LANG="eng"
DPI=300
PSM=3
OEM=3
PREPROCESS=false
CONFIDENCE=false
QUIET=false
PARALLEL=1
PAGES=""
WHITELIST=""
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --lang) LANG="$2"; shift 2 ;;
    --dpi) DPI="$2"; shift 2 ;;
    --psm) PSM="$2"; shift 2 ;;
    --oem) OEM="$2"; shift 2 ;;
    --preprocess) PREPROCESS=true; shift ;;
    --confidence) CONFIDENCE=true; shift ;;
    --quiet) QUIET=true; shift ;;
    --parallel) PARALLEL="$2"; shift 2 ;;
    --pages) PAGES="$2"; shift 2 ;;
    --whitelist) WHITELIST="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 --input <file|dir> [--output <file|dir>] [--format txt|json|searchable-pdf|hocr] [--lang eng] [--dpi 300] [--psm 3] [--preprocess] [--confidence] [--parallel N] [--pages 1-5,8] [--whitelist '0-9.']"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "[OCR] ❌ --input is required"
  exit 1
fi

# Check dependencies
for cmd in tesseract; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[OCR] ❌ $cmd not found. Run: bash scripts/install.sh"
    exit 1
  fi
done

log() {
  if [[ "$QUIET" != true ]]; then
    echo "$@"
  fi
}

# Preprocess image for better OCR
preprocess_image() {
  local src="$1"
  local dst="$2"
  
  if ! command -v convert &>/dev/null; then
    log "[OCR] ⚠️  ImageMagick not found, skipping preprocessing"
    cp "$src" "$dst"
    return
  fi

  convert "$src" \
    -deskew 40% \
    -sharpen 0x1 \
    -threshold 50% \
    -morphology Open Diamond \
    "$dst" 2>/dev/null || cp "$src" "$dst"
}

# Build tesseract config
build_tess_config() {
  local config=""
  if [[ -n "$WHITELIST" ]]; then
    config="$TMPDIR/tess.config"
    echo "tessedit_char_whitelist $WHITELIST" > "$config"
    echo "$config"
  fi
}

# OCR a single image file
ocr_image() {
  local input_file="$1"
  local output_file="$2"
  local basename=$(basename "$input_file")
  
  local process_file="$input_file"
  
  # Preprocess if requested
  if [[ "$PREPROCESS" == true ]]; then
    process_file="$TMPDIR/preprocessed_$(basename "$input_file").png"
    preprocess_image "$input_file" "$process_file"
  fi

  local tess_args=(-l "$LANG" --psm "$PSM" --oem "$OEM")
  local config_file=$(build_tess_config)
  if [[ -n "$config_file" ]]; then
    tess_args+=("$config_file")
  fi

  case "$FORMAT" in
    txt)
      tesseract "$process_file" stdout "${tess_args[@]}" 2>/dev/null > "$output_file"
      local chars=$(wc -c < "$output_file")
      log "[OCR] ✅ $basename → $output_file ($chars chars)"
      
      if [[ "$QUIET" != true && ! -d "$INPUT" ]]; then
        cat "$output_file"
      fi
      ;;
    json)
      local text
      text=$(tesseract "$process_file" stdout "${tess_args[@]}" 2>/dev/null)
      local chars=${#text}
      local conf=""
      
      if [[ "$CONFIDENCE" == true ]]; then
        conf=$(tesseract "$process_file" stdout "${tess_args[@]}" -c hocr_font_info=0 tsv 2>/dev/null | awk -F'\t' 'NR>1 && $11!="" {sum+=$11; n++} END {if(n>0) printf "%.1f", sum/n; else print "0"}')
      fi
      
      # Escape JSON
      local json_text
      json_text=$(echo "$text" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"$text\"")
      
      {
        echo "{"
        echo "  \"file\": \"$basename\","
        echo "  \"text\": $json_text,"
        if [[ -n "$conf" ]]; then
          echo "  \"confidence\": $conf,"
        fi
        echo "  \"characters\": $chars,"
        echo "  \"language\": \"$LANG\","
        echo "  \"processed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
        echo "}"
      } > "$output_file"
      
      log "[OCR] ✅ $basename → $output_file (JSON, $chars chars)"
      
      if [[ "$QUIET" != true && ! -d "$INPUT" ]]; then
        cat "$output_file"
      fi
      ;;
    hocr)
      tesseract "$process_file" "$TMPDIR/hocr_out" "${tess_args[@]}" hocr 2>/dev/null
      mv "$TMPDIR/hocr_out.hocr" "$output_file"
      log "[OCR] ✅ $basename → $output_file (hOCR)"
      ;;
    searchable-pdf)
      tesseract "$process_file" "${output_file%.pdf}" "${tess_args[@]}" pdf 2>/dev/null
      log "[OCR] ✅ $basename → $output_file (searchable PDF)"
      ;;
  esac
}

# Extract pages from PDF
pdf_to_images() {
  local pdf="$1"
  local outdir="$2"
  
  if ! command -v pdftoppm &>/dev/null; then
    echo "[OCR] ❌ pdftoppm not found. Run: sudo apt-get install poppler-utils"
    exit 1
  fi

  local page_args=""
  if [[ -n "$PAGES" ]]; then
    # Parse page ranges (e.g., "1-5,8,12")
    IFS=',' read -ra RANGES <<< "$PAGES"
    for range in "${RANGES[@]}"; do
      if [[ "$range" == *-* ]]; then
        local first="${range%-*}"
        local last="${range#*-}"
        pdftoppm -r "$DPI" -f "$first" -l "$last" -png "$pdf" "$outdir/page"
      else
        pdftoppm -r "$DPI" -f "$range" -l "$range" -png "$pdf" "$outdir/page"
      fi
    done
  else
    pdftoppm -r "$DPI" -png "$pdf" "$outdir/page"
  fi
}

# Get default output path
default_output() {
  local input_path="$1"
  local ext="$2"
  
  if [[ -d "$input_path" ]]; then
    echo "${input_path%/}_ocr"
  else
    local base="${input_path%.*}"
    echo "${base}.${ext}"
  fi
}

# Main logic
if [[ -z "$OUTPUT" ]]; then
  case "$FORMAT" in
    searchable-pdf) OUTPUT=$(default_output "$INPUT" "pdf") ;;
    hocr) OUTPUT=$(default_output "$INPUT" "hocr") ;;
    json) OUTPUT=$(default_output "$INPUT" "json") ;;
    *) OUTPUT=$(default_output "$INPUT" "txt") ;;
  esac
fi

# Handle directory input (batch mode)
if [[ -d "$INPUT" ]]; then
  mkdir -p "$OUTPUT"
  
  FILES=()
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(find "$INPUT" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.tiff' -o -iname '*.tif' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.pdf' \) -print0 | sort -z)
  
  log "[OCR] Found ${#FILES[@]} files in $INPUT"
  
  SUCCESS=0
  FAIL=0
  
  for f in "${FILES[@]}"; do
    base=$(basename "$f")
    name="${base%.*}"
    
    ext="txt"
    case "$FORMAT" in
      json) ext="json" ;;
      hocr) ext="hocr" ;;
      searchable-pdf) ext="pdf" ;;
    esac
    
    out="$OUTPUT/${name}.${ext}"
    
    if [[ "${f,,}" == *.pdf ]]; then
      PDF_IMGS="$TMPDIR/pdf_pages_${name}"
      mkdir -p "$PDF_IMGS"
      pdf_to_images "$f" "$PDF_IMGS"
      
      # OCR each page and merge
      > "$out"
      for page in "$PDF_IMGS"/page-*.png; do
        [[ -f "$page" ]] || continue
        tesseract "$page" stdout -l "$LANG" --psm "$PSM" --oem "$OEM" 2>/dev/null >> "$out"
        echo -e "\n--- Page Break ---\n" >> "$out"
      done
      
      chars_count=$(wc -c < "$out")
      log "[OCR] ✅ $base → $out ($chars_count chars)"
      SUCCESS=$((SUCCESS + 1))
    else
      if ocr_image "$f" "$out" 2>/dev/null; then
        SUCCESS=$((SUCCESS + 1))
      else
        log "[OCR] ❌ $base — failed"
        FAIL=$((FAIL + 1))
      fi
    fi
  done
  
  log "[OCR] Done: $SUCCESS/${#FILES[@]} files processed, $FAIL failures"

# Handle PDF input
elif [[ "${INPUT,,}" == *.pdf ]]; then
  log "[OCR] Extracting pages from $INPUT (DPI: $DPI)..."
  PDF_IMGS="$TMPDIR/pdf_pages"
  mkdir -p "$PDF_IMGS"
  pdf_to_images "$INPUT" "$PDF_IMGS"
  
  PAGE_COUNT=$(find "$PDF_IMGS" -name "page-*.png" | wc -l)
  log "[OCR] Found $PAGE_COUNT pages"
  
  if [[ "$FORMAT" == "searchable-pdf" ]]; then
    # Create searchable PDF directly
    > "$TMPDIR/pdf_list.txt"
    for page in $(ls "$PDF_IMGS"/page-*.png | sort -V); do
      echo "$page" >> "$TMPDIR/pdf_list.txt"
    done
    
    # OCR each page to PDF, then merge
    PDF_PARTS=()
    i=0
    for page in $(ls "$PDF_IMGS"/page-*.png | sort -V); do
      ((i++))
      log "[OCR] Processing page $i/$PAGE_COUNT..."
      out_base="$TMPDIR/part_$(printf '%04d' $i)"
      tesseract "$page" "$out_base" -l "$LANG" --psm "$PSM" --oem "$OEM" pdf 2>/dev/null
      PDF_PARTS+=("${out_base}.pdf")
    done
    
    if command -v pdfunite &>/dev/null && [[ ${#PDF_PARTS[@]} -gt 1 ]]; then
      pdfunite "${PDF_PARTS[@]}" "$OUTPUT"
    else
      cp "${PDF_PARTS[0]}" "$OUTPUT"
    fi
    
    log "[OCR] ✅ Searchable PDF → $OUTPUT ($PAGE_COUNT pages)"
  else
    # OCR each page to text and merge
    > "$OUTPUT"
    i=0
    for page in $(ls "$PDF_IMGS"/page-*.png | sort -V); do
      ((i++))
      log "[OCR] Processing page $i/$PAGE_COUNT..."
      
      if [[ "$PREPROCESS" == true ]]; then
        processed="$TMPDIR/processed_page_$i.png"
        preprocess_image "$page" "$processed"
        page="$processed"
      fi
      
      tesseract "$page" stdout -l "$LANG" --psm "$PSM" --oem "$OEM" 2>/dev/null >> "$OUTPUT"
      echo -e "\n--- Page $i ---\n" >> "$OUTPUT"
    done
    
    TOTAL_CHARS=$(wc -c < "$OUTPUT")
    log "[OCR] ✅ All pages merged → $OUTPUT ($TOTAL_CHARS chars)"
    
    if [[ "$QUIET" != true ]]; then
      cat "$OUTPUT"
    fi
  fi

# Handle single image
else
  if [[ ! -f "$INPUT" ]]; then
    echo "[OCR] ❌ File not found: $INPUT"
    exit 1
  fi
  
  log "[OCR] Processing: $(basename "$INPUT")"
  log "[OCR] Language: $LANG | PSM: $PSM | OEM: $OEM"
  
  ocr_image "$INPUT" "$OUTPUT"
fi
