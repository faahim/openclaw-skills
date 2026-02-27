#!/bin/bash
# ImageMagick Toolkit — Main Runner
# Usage: bash run.sh <command> [options]
set -euo pipefail

# Detect ImageMagick command (v6: convert, v7: magick)
if command -v magick &>/dev/null; then
  IM="magick"
  IM_CONVERT="magick"
  IM_COMPARE="magick compare"
  IM_MONTAGE="magick montage"
  IM_IDENTIFY="magick identify"
elif command -v convert &>/dev/null; then
  IM="convert"
  IM_CONVERT="convert"
  IM_COMPARE="compare"
  IM_MONTAGE="montage"
  IM_IDENTIFY="identify"
else
  echo "❌ ImageMagick not found. Run: bash scripts/install.sh"
  exit 1
fi

# Defaults
QUALITY="${IM_QUALITY:-85}"
PARALLEL="${IM_PARALLEL:-4}"
FORMAT="${IM_FORMAT:-}"
WATERMARK_OPACITY="${IM_WATERMARK_OPACITY:-50}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "[${1}] ${2}"; }
ok() { echo -e "[${1}] ${GREEN}✅ ${2}${NC}"; }
warn() { echo -e "[${1}] ${YELLOW}⚠️  ${2}${NC}"; }
err() { echo -e "[${1}] ${RED}❌ ${2}${NC}"; }

# Find image files in directory
find_images() {
  local dir="$1"
  find "$dir" -maxdepth 1 -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \
    -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.tiff' -o -iname '*.tif' \
    -o -iname '*.bmp' -o -iname '*.svg' -o -iname '*.heic' -o -iname '*.heif' \
  \) | sort
}

# Get file size in human readable
human_size() {
  local bytes=$1
  if [ "$bytes" -gt 1073741824 ]; then echo "$((bytes / 1073741824))GB"
  elif [ "$bytes" -gt 1048576 ]; then echo "$((bytes / 1048576))MB"
  elif [ "$bytes" -gt 1024 ]; then echo "$((bytes / 1024))KB"
  else echo "${bytes}B"; fi
}

cmd_resize() {
  local input="" output="" width="" height="" percent="" crop=false batch_size=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --width) width="$2"; shift 2 ;;
      --height) height="$2"; shift 2 ;;
      --percent) percent="$2"; shift 2 ;;
      --crop) crop=true; shift ;;
      --batch-size) batch_size="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "resize" "Missing --input"; exit 1; }
  [ -z "$output" ] && { err "resize" "Missing --output"; exit 1; }
  mkdir -p "$output"

  local geometry=""
  if [ -n "$percent" ]; then
    geometry="${percent}%"
  elif [ -n "$width" ] && [ -n "$height" ]; then
    if $crop; then
      geometry="${width}x${height}^"
    else
      geometry="${width}x${height}"
    fi
  elif [ -n "$width" ]; then
    geometry="${width}x"
  elif [ -n "$height" ]; then
    geometry="x${height}"
  else
    err "resize" "Specify --width, --height, or --percent"
    exit 1
  fi

  local files count=0 errors=0 total_in=0 total_out=0
  if [ -d "$input" ]; then
    files=$(find_images "$input")
  else
    files="$input"
  fi

  local total=$(echo "$files" | grep -c . || echo 0)
  log "resize" "Processing $total images → ${geometry}..."

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local base=$(basename "$f")
    local out_file="$output/$base"
    local in_size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)

    if $crop; then
      $IM_CONVERT "$f" -resize "$geometry" -gravity center -extent "${width}x${height}" -quality "$QUALITY" "$out_file" 2>/dev/null
    else
      $IM_CONVERT "$f" -resize "$geometry" -quality "$QUALITY" "$out_file" 2>/dev/null
    fi

    if [ $? -eq 0 ]; then
      local out_size=$(stat -f%z "$out_file" 2>/dev/null || stat -c%s "$out_file" 2>/dev/null || echo 0)
      local dims=$($IM_IDENTIFY -format "%wx%h" "$out_file" 2>/dev/null || echo "?x?")
      local orig_dims=$($IM_IDENTIFY -format "%wx%h" "$f" 2>/dev/null || echo "?x?")
      ok "resize" "$base → $dims (was $orig_dims)"
      total_in=$((total_in + in_size))
      total_out=$((total_out + out_size))
      count=$((count + 1))
    else
      err "resize" "Failed: $base"
      errors=$((errors + 1))
    fi
  done <<< "$files"

  echo ""
  log "resize" "Done: $count/$total processed, $errors errors"
  if [ $total_in -gt 0 ]; then
    log "resize" "Saved $(human_size $((total_in - total_out))) (was $(human_size $total_in) → now $(human_size $total_out))"
  fi
}

cmd_convert() {
  local input="" output="" format="" quality="$QUALITY" density=150
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      --quality) quality="$2"; shift 2 ;;
      --density) density="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "convert" "Missing --input"; exit 1; }
  [ -z "$output" ] && { err "convert" "Missing --output"; exit 1; }
  [ -z "$format" ] && { err "convert" "Missing --format (webp, avif, png, jpg, etc.)"; exit 1; }
  mkdir -p "$output"

  # Handle PDF input
  if [[ "$input" == *.pdf ]]; then
    log "convert" "Converting PDF → ${format^^} (density: ${density}dpi)..."
    $IM_CONVERT -density "$density" "$input" -quality "$quality" "$output/page-%03d.${format}" 2>/dev/null
    local pages=$(ls "$output"/page-*.${format} 2>/dev/null | wc -l)
    ok "convert" "Extracted $pages pages from $(basename "$input")"
    return
  fi

  local files
  if [ -d "$input" ]; then
    files=$(find_images "$input")
  else
    files="$input"
  fi

  local total=$(echo "$files" | grep -c . || echo 0)
  log "convert" "Converting $total images → ${format^^}..."

  local count=0 errors=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local base=$(basename "$f")
    local name="${base%.*}"
    local out_file="$output/${name}.${format}"

    $IM_CONVERT "$f" -quality "$quality" "$out_file" 2>/dev/null
    if [ $? -eq 0 ]; then
      ok "convert" "$base → ${name}.${format}"
      count=$((count + 1))
    else
      err "convert" "Failed: $base"
      errors=$((errors + 1))
    fi
  done <<< "$files"

  echo ""
  log "convert" "Done: $count/$total converted, $errors errors"
}

cmd_watermark() {
  local input="" output="" text="" logo="" position="southeast" opacity="$WATERMARK_OPACITY" scale=20
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --text) text="$2"; shift 2 ;;
      --logo) logo="$2"; shift 2 ;;
      --position) position="$2"; shift 2 ;;
      --opacity) opacity="$2"; shift 2 ;;
      --scale) scale="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "watermark" "Missing --input"; exit 1; }
  [ -z "$output" ] && { err "watermark" "Missing --output"; exit 1; }
  [ -z "$text" ] && [ -z "$logo" ] && { err "watermark" "Specify --text or --logo"; exit 1; }
  mkdir -p "$output"

  local files
  if [ -d "$input" ]; then
    files=$(find_images "$input")
  else
    files="$input"
  fi

  local total=$(echo "$files" | grep -c . || echo 0)
  log "watermark" "Watermarking $total images..."

  local count=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local base=$(basename "$f")
    local out_file="$output/$base"

    if [ -n "$text" ]; then
      $IM_CONVERT "$f" \
        -gravity "$position" \
        -fill "rgba(255,255,255,$(echo "scale=2; $opacity/100" | bc))" \
        -pointsize 36 \
        -annotate +20+20 "$text" \
        -quality "$QUALITY" \
        "$out_file" 2>/dev/null
    elif [ -n "$logo" ]; then
      local img_width=$($IM_IDENTIFY -format "%w" "$f" 2>/dev/null)
      local logo_width=$((img_width * scale / 100))
      $IM_CONVERT "$f" \
        \( "$logo" -resize "${logo_width}x" -alpha set -channel A -evaluate set "${opacity}%" +channel \) \
        -gravity "$position" -geometry +20+20 \
        -composite \
        -quality "$QUALITY" \
        "$out_file" 2>/dev/null
    fi

    if [ $? -eq 0 ]; then
      ok "watermark" "$base"
      count=$((count + 1))
    else
      err "watermark" "Failed: $base"
    fi
  done <<< "$files"

  log "watermark" "Done: $count/$total watermarked"
}

cmd_thumbnail() {
  local input="" output="" size=200
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --size) size="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "thumbnail" "Missing --input"; exit 1; }
  [ -z "$output" ] && { err "thumbnail" "Missing --output"; exit 1; }
  mkdir -p "$output"

  local files
  if [ -d "$input" ]; then
    files=$(find_images "$input")
  else
    files="$input"
  fi

  local total=$(echo "$files" | grep -c . || echo 0)
  log "thumbnail" "Generating ${size}px thumbnails for $total images..."

  local count=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local base=$(basename "$f")
    local out_file="$output/$base"
    $IM_CONVERT "$f" -thumbnail "${size}x${size}^" -gravity center -extent "${size}x${size}" -quality "$QUALITY" "$out_file" 2>/dev/null
    if [ $? -eq 0 ]; then
      ok "thumbnail" "$base → ${size}x${size}"
      count=$((count + 1))
    else
      err "thumbnail" "Failed: $base"
    fi
  done <<< "$files"

  log "thumbnail" "Done: $count/$total thumbnails"
}

cmd_contact_sheet() {
  local input="" output="contact-sheet.jpg" columns=5 thumb_size=200
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --columns) columns="$2"; shift 2 ;;
      --thumb-size) thumb_size="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "contact-sheet" "Missing --input"; exit 1; }

  local files
  if [ -d "$input" ]; then
    files=$(find_images "$input")
  else
    files="$input"
  fi

  local total=$(echo "$files" | grep -c . || echo 0)
  log "contact-sheet" "Creating ${columns}-column contact sheet from $total images..."

  local file_list=()
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    file_list+=("$f")
  done <<< "$files"

  $IM_MONTAGE "${file_list[@]}" -thumbnail "${thumb_size}x${thumb_size}" \
    -geometry "+4+4" -tile "${columns}x" \
    -background white -quality "$QUALITY" \
    "$output" 2>/dev/null

  if [ $? -eq 0 ]; then
    ok "contact-sheet" "Created: $output ($total images, ${columns} columns)"
  else
    err "contact-sheet" "Failed to create contact sheet"
  fi
}

cmd_sprite() {
  local input="" output="sprite.png" css="sprite.css"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --css) css="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "sprite" "Missing --input"; exit 1; }

  local files
  files=$(find_images "$input")
  local total=$(echo "$files" | grep -c . || echo 0)
  log "sprite" "Creating sprite from $total images..."

  # Get dimensions of first image to determine icon size
  local first_file=$(echo "$files" | head -1)
  local icon_w=$($IM_IDENTIFY -format "%w" "$first_file" 2>/dev/null)
  local icon_h=$($IM_IDENTIFY -format "%h" "$first_file" 2>/dev/null)

  # Create horizontal sprite
  local file_list=()
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    file_list+=("$f")
  done <<< "$files"

  $IM_CONVERT "${file_list[@]}" +append "$output" 2>/dev/null

  # Generate CSS
  echo "/* Generated by ImageMagick Toolkit */" > "$css"
  local x=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local base=$(basename "$f")
    local name="${base%.*}"
    local w=$($IM_IDENTIFY -format "%w" "$f" 2>/dev/null)
    local h=$($IM_IDENTIFY -format "%h" "$f" 2>/dev/null)
    echo ".icon-${name} { width: ${w}px; height: ${h}px; background: url('$(basename "$output")') -${x}px 0px; }" >> "$css"
    x=$((x + w))
  done <<< "$files"

  ok "sprite" "Created: $output + $css ($total icons)"
}

cmd_compare() {
  local input1="" input2="" output="diff.png" metric="AE"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input1) input1="$2"; shift 2 ;;
      --input2) input2="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --metric) metric="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input1" ] || [ -z "$input2" ] && { err "compare" "Need --input1 and --input2"; exit 1; }

  local diff_count
  diff_count=$($IM_COMPARE -metric "$metric" "$input1" "$input2" "$output" 2>&1 || true)

  local total_px=$($IM_IDENTIFY -format "%[fx:w*h]" "$input1" 2>/dev/null || echo 1)
  local pct=$(echo "scale=1; ${diff_count:-0} * 100 / $total_px" | bc 2>/dev/null || echo "?")

  log "compare" "Difference: ${diff_count:-0} pixels (${pct}% of total)"
  ok "compare" "Saved diff visualization → $output"
}

cmd_crop() {
  local input="" output="" aspect="" gravity="center" geometry=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --aspect) aspect="$2"; shift 2 ;;
      --gravity) gravity="$2"; shift 2 ;;
      --geometry) geometry="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "crop" "Missing --input"; exit 1; }
  [ -z "$output" ] && { err "crop" "Missing --output"; exit 1; }
  mkdir -p "$(dirname "$output")" 2>/dev/null || mkdir -p "$output" 2>/dev/null || true

  local files
  if [ -d "$input" ]; then
    files=$(find_images "$input")
    [ -d "$output" ] || mkdir -p "$output"
  else
    files="$input"
  fi

  local count=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local base=$(basename "$f")
    local out_file
    [ -d "$output" ] && out_file="$output/$base" || out_file="$output"

    if [ -n "$geometry" ]; then
      $IM_CONVERT "$f" -crop "$geometry" +repage -quality "$QUALITY" "$out_file" 2>/dev/null
    elif [ -n "$aspect" ]; then
      local aw="${aspect%%:*}"
      local ah="${aspect##*:}"
      local w=$($IM_IDENTIFY -format "%w" "$f" 2>/dev/null)
      local h=$($IM_IDENTIFY -format "%h" "$f" 2>/dev/null)
      local target_w=$w
      local target_h=$((w * ah / aw))
      if [ $target_h -gt $h ]; then
        target_h=$h
        target_w=$((h * aw / ah))
      fi
      $IM_CONVERT "$f" -gravity "$gravity" -crop "${target_w}x${target_h}+0+0" +repage -quality "$QUALITY" "$out_file" 2>/dev/null
    fi

    if [ $? -eq 0 ]; then
      ok "crop" "$base"
      count=$((count + 1))
    else
      err "crop" "Failed: $base"
    fi
  done <<< "$files"

  log "crop" "Done: $count cropped"
}

cmd_strip() {
  local input="" output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "strip" "Missing --input"; exit 1; }
  [ -z "$output" ] && { err "strip" "Missing --output"; exit 1; }
  mkdir -p "$output"

  local files
  if [ -d "$input" ]; then
    files=$(find_images "$input")
  else
    files="$input"
  fi

  local count=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local base=$(basename "$f")
    $IM_CONVERT "$f" -strip -quality "$QUALITY" "$output/$base" 2>/dev/null
    if [ $? -eq 0 ]; then
      ok "strip" "$base — metadata removed"
      count=$((count + 1))
    else
      err "strip" "Failed: $base"
    fi
  done <<< "$files"

  log "strip" "Done: $count stripped"
}

cmd_pipeline() {
  local input="" output="" resize="" format="" watermark="" strip_meta=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --resize) resize="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      --watermark) watermark="$2"; shift 2 ;;
      --strip-metadata) strip_meta=true; shift ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "pipeline" "Missing --input"; exit 1; }
  [ -z "$output" ] && { err "pipeline" "Missing --output"; exit 1; }
  mkdir -p "$output"

  local files
  if [ -d "$input" ]; then
    files=$(find_images "$input")
  else
    files="$input"
  fi

  local total=$(echo "$files" | grep -c . || echo 0)
  log "pipeline" "Processing $total images through pipeline..."

  local count=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local base=$(basename "$f")
    local name="${base%.*}"
    local ext="${base##*.}"
    [ -n "$format" ] && ext="$format"
    local out_file="$output/${name}.${ext}"

    local args=("$f")
    [ -n "$resize" ] && args+=("-resize" "${resize}x")
    [ -n "$watermark" ] && args+=("-gravity" "southeast" "-fill" "rgba(255,255,255,0.5)" "-pointsize" "36" "-annotate" "+20+20" "$watermark")
    $strip_meta && args+=("-strip")
    args+=("-quality" "$QUALITY" "$out_file")

    $IM_CONVERT "${args[@]}" 2>/dev/null
    if [ $? -eq 0 ]; then
      ok "pipeline" "$base → ${name}.${ext}"
      count=$((count + 1))
    else
      err "pipeline" "Failed: $base"
    fi
  done <<< "$files"

  log "pipeline" "Done: $count/$total processed"
}

show_help() {
  cat <<EOF
🖼️  ImageMagick Toolkit

Usage: bash run.sh <command> [options]

Commands:
  resize          Batch resize images
  convert         Convert between formats (PNG/JPG/WebP/AVIF/PDF)
  watermark       Add text or image watermark
  thumbnail       Generate square thumbnails
  contact-sheet   Create thumbnail grid / contact sheet
  sprite          Create CSS sprite sheet from icons
  compare         Compare two images, highlight differences
  crop            Crop to aspect ratio or geometry
  strip           Remove EXIF metadata
  pipeline        Chain multiple operations in one pass

Options (all commands):
  --input <path>     Input file or directory
  --output <path>    Output file or directory

Resize options:
  --width <px>       Target width
  --height <px>      Target height
  --percent <N>      Scale by percentage
  --crop             Crop to exact dimensions

Convert options:
  --format <fmt>     Output format (webp, avif, png, jpg, tiff)
  --quality <1-100>  Output quality (default: 85)
  --density <dpi>    PDF rendering density (default: 150)

Watermark options:
  --text <string>    Text watermark
  --logo <path>      Image watermark
  --position <pos>   Gravity: center, southeast, etc. (default: southeast)
  --opacity <0-100>  Watermark opacity (default: 50)
  --scale <1-100>    Logo size as % of image width (default: 20)

Environment:
  IM_QUALITY=85          Default quality
  IM_PARALLEL=4          Parallel workers
  IM_WATERMARK_OPACITY=50 Default watermark opacity

Examples:
  bash run.sh resize --input ./photos --width 1200 --output ./resized
  bash run.sh convert --input ./photos --format webp --output ./web
  bash run.sh watermark --input ./photos --text "© 2026" --output ./marked
  bash run.sh pipeline --input ./raw --resize 1200 --format webp --watermark "© Me" --output ./final
EOF
}

# Main dispatch
COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  resize) cmd_resize "$@" ;;
  convert) cmd_convert "$@" ;;
  watermark) cmd_watermark "$@" ;;
  thumbnail) cmd_thumbnail "$@" ;;
  contact-sheet) cmd_contact_sheet "$@" ;;
  sprite) cmd_sprite "$@" ;;
  compare) cmd_compare "$@" ;;
  crop) cmd_crop "$@" ;;
  strip) cmd_strip "$@" ;;
  pipeline) cmd_pipeline "$@" ;;
  help|--help|-h) show_help ;;
  *) err "main" "Unknown command: $COMMAND"; show_help; exit 1 ;;
esac
