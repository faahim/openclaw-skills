#!/bin/bash
# Image Optimizer — Main Script
# Batch optimize images: compress, resize, convert to WebP/AVIF
set -e

# ── Defaults ──
INPUT=""
OUTPUT="./optimized"
FORMAT="webp"
QUALITY=85
MAX_WIDTH=""
MAX_HEIGHT=""
RESPONSIVE=""
STRIP_META=false
LOSSLESS=false
INPLACE=false
RECURSIVE=true
DRY_RUN=false
REPORT=true
PARALLEL=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# ── Parse Args ──
while [[ $# -gt 0 ]]; do
  case $1 in
    --input)          INPUT="$2"; shift 2 ;;
    --output)         OUTPUT="$2"; shift 2 ;;
    --format)         FORMAT="$2"; shift 2 ;;
    --quality)        QUALITY="$2"; shift 2 ;;
    --max-width)      MAX_WIDTH="$2"; shift 2 ;;
    --max-height)     MAX_HEIGHT="$2"; shift 2 ;;
    --responsive)     RESPONSIVE="$2"; shift 2 ;;
    --strip-metadata) STRIP_META=true; shift ;;
    --lossless)       LOSSLESS=true; shift ;;
    --inplace)        INPLACE=true; shift ;;
    --no-recursive)   RECURSIVE=false; shift ;;
    --dry-run)        DRY_RUN=true; shift ;;
    --no-report)      REPORT=false; shift ;;
    --parallel)       PARALLEL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: optimize.sh --input <file|dir> [options]"
      echo ""
      echo "Options:"
      echo "  --input <path>       Input file or directory (required)"
      echo "  --output <path>      Output directory (default: ./optimized)"
      echo "  --format <fmt>       webp|avif|jpg|png|original (default: webp)"
      echo "  --quality <1-100>    Quality level (default: 85)"
      echo "  --max-width <px>     Maximum width (maintains aspect ratio)"
      echo "  --max-height <px>    Maximum height"
      echo "  --responsive <w,w>   Generate multiple widths (e.g. 480,768,1024)"
      echo "  --strip-metadata     Remove EXIF data"
      echo "  --lossless           Lossless compression"
      echo "  --inplace            Overwrite originals"
      echo "  --dry-run            Preview without processing"
      echo "  --parallel <n>       Concurrent jobs (default: CPU cores)"
      exit 0
      ;;
    *) echo "❌ Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$INPUT" ]; then
  echo "❌ --input is required. Use --help for usage."
  exit 1
fi

# ── Collect Files ──
IMAGE_EXTS="jpg|jpeg|png|gif|bmp|tiff|tif|webp|avif"
FILES=()

if [ -f "$INPUT" ]; then
  FILES+=("$INPUT")
elif [ -d "$INPUT" ]; then
  if $RECURSIVE; then
    while IFS= read -r -d '' f; do
      FILES+=("$f")
    done < <(find "$INPUT" -type f -regextype posix-extended -iregex ".*\.($IMAGE_EXTS)$" -print0 2>/dev/null || \
             find "$INPUT" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" -o -iname "*.avif" \) -print0)
  else
    while IFS= read -r -d '' f; do
      FILES+=("$f")
    done < <(find "$INPUT" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" -o -iname "*.avif" \) -print0)
  fi
else
  echo "❌ Input not found: $INPUT"
  exit 1
fi

TOTAL=${#FILES[@]}
if [ "$TOTAL" -eq 0 ]; then
  echo "⚠️  No images found in $INPUT"
  exit 0
fi

echo "Processing $TOTAL images..."
echo ""

# ── Setup Output ──
if ! $INPLACE; then
  mkdir -p "$OUTPUT"
fi

# ── Stats ──
TOTAL_INPUT_SIZE=0
TOTAL_OUTPUT_SIZE=0
REPORT_LINES=()
COUNT=0
SKIPPED=0

# ── Get file extension for format ──
get_ext() {
  case "$1" in
    webp) echo "webp" ;;
    avif) echo "avif" ;;
    jpg)  echo "jpg" ;;
    png)  echo "png" ;;
    original) echo "" ;;
  esac
}

# ── Human readable size ──
human_size() {
  local bytes=$1
  if [ "$bytes" -ge 1048576 ]; then
    echo "$(echo "scale=1; $bytes / 1048576" | bc)MB"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$(echo "scale=0; $bytes / 1024" | bc)KB"
  else
    echo "${bytes}B"
  fi
}

# ── Process single image ──
process_image() {
  local input_file="$1"
  local basename=$(basename "$input_file")
  local name="${basename%.*}"
  local input_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null)

  # Determine output format
  local out_format="$FORMAT"
  if [ "$out_format" = "original" ]; then
    local ext="${basename##*.}"
    out_format=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  fi
  local out_ext=$(get_ext "$out_format")
  [ -z "$out_ext" ] && out_ext="${basename##*.}"

  # Handle responsive sizes
  if [ -n "$RESPONSIVE" ]; then
    IFS=',' read -ra WIDTHS <<< "$RESPONSIVE"
    for w in "${WIDTHS[@]}"; do
      local out_file
      if $INPLACE; then
        out_file="$(dirname "$input_file")/${name}-${w}w.${out_ext}"
      else
        out_file="${OUTPUT}/${name}-${w}w.${out_ext}"
      fi

      if $DRY_RUN; then
        echo "[DRY] $basename → ${name}-${w}w.${out_ext}"
        continue
      fi

      convert_image "$input_file" "$out_file" "$out_format" "$w" ""
    done
    return
  fi

  # Single output
  local out_file
  if $INPLACE; then
    out_file="$(dirname "$input_file")/${name}.${out_ext}"
    # If same extension, use temp file
    if [ "$out_file" = "$input_file" ]; then
      out_file="${input_file}.tmp.${out_ext}"
    fi
  else
    out_file="${OUTPUT}/${name}.${out_ext}"
  fi

  if $DRY_RUN; then
    echo "[DRY] $basename → $(basename "$out_file")"
    return
  fi

  convert_image "$input_file" "$out_file" "$out_format" "$MAX_WIDTH" "$MAX_HEIGHT"

  # Handle inplace rename
  if $INPLACE && [ "$out_file" != "$input_file" ]; then
    if [ "${out_file%.tmp.*}" != "$out_file" ]; then
      local final="${input_file%.*}.${out_ext}"
      mv "$out_file" "$final"
      [ "$final" != "$input_file" ] && rm -f "$input_file"
      out_file="$final"
    fi
  fi

  local output_size=$(stat -f%z "$out_file" 2>/dev/null || stat -c%s "$out_file" 2>/dev/null)

  # Check if output is larger — keep original
  if [ "$output_size" -ge "$input_size" ] && [ "$out_format" != "$(echo "${basename##*.}" | tr '[:upper:]' '[:lower:]')" ]; then
    # Output is larger, copy original instead
    if ! $INPLACE; then
      cp "$input_file" "${OUTPUT}/${basename}"
      rm -f "$out_file"
      output_size=$input_size
      out_file="${OUTPUT}/${basename}"
    fi
  fi

  COUNT=$((COUNT + 1))
  TOTAL_INPUT_SIZE=$((TOTAL_INPUT_SIZE + input_size))
  TOTAL_OUTPUT_SIZE=$((TOTAL_OUTPUT_SIZE + output_size))

  local saved=0
  if [ "$input_size" -gt 0 ]; then
    saved=$(( (input_size - output_size) * 100 / input_size ))
  fi

  local in_human=$(human_size $input_size)
  local out_human=$(human_size $output_size)

  echo "[${COUNT}/${TOTAL}] $basename (${in_human}) → $(basename "$out_file") (${out_human}) — saved ${saved}%"
  REPORT_LINES+=("$basename | $in_human | $(basename "$out_file") | $out_human | ${saved}%")
}

# ── Convert using best available tool ──
convert_image() {
  local src="$1" dst="$2" fmt="$3" width="$4" height="$5"

  case "$fmt" in
    webp)
      if command -v cwebp &>/dev/null && ! $LOSSLESS; then
        local resize_args=""
        if [ -n "$width" ]; then
          resize_args="-resize $width 0"
        fi
        local meta_args=""
        if $STRIP_META; then
          meta_args="-metadata none"
        else
          meta_args="-metadata all"
        fi
        cwebp -q "$QUALITY" $resize_args $meta_args "$src" -o "$dst" 2>/dev/null
      else
        local resize_args=""
        if [ -n "$width" ]; then
          resize_args="-resize ${width}x>"
        fi
        local strip_args=""
        $STRIP_META && strip_args="-strip"
        convert "$src" -quality "$QUALITY" $resize_args $strip_args "$dst" 2>/dev/null
      fi
      ;;
    avif)
      if command -v avifenc &>/dev/null; then
        # avifenc needs pre-resized input if resize needed
        if [ -n "$width" ]; then
          local tmp="/tmp/imgopt_$$.png"
          convert "$src" -resize "${width}x>" "$tmp"
          avifenc --min 0 --max 63 -a end-usage=q -a cq-level=$((63 - QUALITY * 63 / 100)) "$tmp" "$dst" 2>/dev/null
          rm -f "$tmp"
        else
          avifenc --min 0 --max 63 -a end-usage=q -a cq-level=$((63 - QUALITY * 63 / 100)) "$src" "$dst" 2>/dev/null
        fi
      else
        convert "$src" -quality "$QUALITY" "$dst" 2>/dev/null
      fi
      ;;
    jpg|jpeg)
      local resize_args=""
      [ -n "$width" ] && resize_args="-resize ${width}x>"
      local strip_args=""
      $STRIP_META && strip_args="-strip"
      convert "$src" -quality "$QUALITY" $resize_args $strip_args -sampling-factor 4:2:0 -interlace Plane "$dst" 2>/dev/null
      ;;
    png)
      local resize_args=""
      [ -n "$width" ] && resize_args="-resize ${width}x>"
      local strip_args=""
      $STRIP_META && strip_args="-strip"
      if $LOSSLESS; then
        convert "$src" $resize_args $strip_args -define png:compression-filter=5 -define png:compression-level=9 -define png:compression-strategy=1 "$dst" 2>/dev/null
      else
        convert "$src" -quality "$QUALITY" $resize_args $strip_args "$dst" 2>/dev/null
      fi
      ;;
    *)
      local resize_args=""
      [ -n "$width" ] && resize_args="-resize ${width}x>"
      local strip_args=""
      $STRIP_META && strip_args="-strip"
      convert "$src" -quality "$QUALITY" $resize_args $strip_args "$dst" 2>/dev/null
      ;;
  esac
}

# ── Process All ──
for f in "${FILES[@]}"; do
  process_image "$f"
done

echo ""

# ── Summary ──
if [ "$TOTAL_INPUT_SIZE" -gt 0 ]; then
  TOTAL_SAVED=$(( (TOTAL_INPUT_SIZE - TOTAL_OUTPUT_SIZE) * 100 / TOTAL_INPUT_SIZE ))
  echo "✅ Done! $COUNT images optimized."
  echo "   Total: $(human_size $TOTAL_INPUT_SIZE) → $(human_size $TOTAL_OUTPUT_SIZE) (saved ${TOTAL_SAVED}%)"
else
  echo "✅ Done! $COUNT images processed."
fi

# ── Report ──
if $REPORT && ! $DRY_RUN && ! $INPLACE; then
  REPORT_FILE="${OUTPUT}/optimization-report.txt"
  {
    echo "Image Optimization Report"
    echo "========================="
    echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "Format: $FORMAT | Quality: $QUALITY"
    [ -n "$MAX_WIDTH" ] && echo "Max Width: ${MAX_WIDTH}px"
    [ -n "$RESPONSIVE" ] && echo "Responsive: $RESPONSIVE"
    echo ""
    echo "Input | Size | Output | Size | Saved"
    echo "------|------|--------|------|------"
    for line in "${REPORT_LINES[@]}"; do
      echo "$line"
    done
    echo ""
    echo "Total: $(human_size $TOTAL_INPUT_SIZE) → $(human_size $TOTAL_OUTPUT_SIZE) (saved ${TOTAL_SAVED}%)"
  } > "$REPORT_FILE"
  echo "   Report: $REPORT_FILE"
fi
