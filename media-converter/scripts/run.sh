#!/bin/bash
# Media Converter — ffmpeg-based media conversion, compression, and extraction
# Usage: bash run.sh <command> [options]

set -euo pipefail

# Defaults
FFMPEG="${FFMPEG_BIN:-ffmpeg}"
FFPROBE="${FFPROBE_BIN:-ffprobe}"
OUTPUT_DIR="${MEDIA_CONVERTER_OUTPUT:-.}"
QUALITY="${MEDIA_CONVERTER_QUALITY:-medium}"
JOBS="${MEDIA_CONVERTER_JOBS:-4}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
ok()   { log "${GREEN}✅ $1${NC}"; }
err()  { log "${RED}❌ $1${NC}"; }
info() { log "${BLUE}🎬 $1${NC}"; }

# Check dependencies
check_deps() {
  if ! command -v "$FFMPEG" &>/dev/null; then
    err "ffmpeg not found. Install: sudo apt-get install ffmpeg (or brew install ffmpeg)"
    exit 1
  fi
  if ! command -v "$FFPROBE" &>/dev/null; then
    err "ffprobe not found. Install with ffmpeg."
    exit 1
  fi
}

# Get CRF value from quality preset
get_crf() {
  case "${1:-medium}" in
    low)      echo 28 ;;
    medium)   echo 23 ;;
    high)     echo 18 ;;
    lossless) echo 0 ;;
    *)        echo 23 ;;
  esac
}

# Get preset speed from quality
get_preset() {
  case "${1:-medium}" in
    low)      echo "veryfast" ;;
    medium)   echo "medium" ;;
    high)     echo "slow" ;;
    lossless) echo "veryslow" ;;
    *)        echo "medium" ;;
  esac
}

# File size in human-readable format
human_size() {
  local bytes
  bytes=$(stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null)
  if [ "$bytes" -ge 1073741824 ]; then
    echo "$(echo "scale=1; $bytes/1073741824" | bc) GB"
  elif [ "$bytes" -ge 1048576 ]; then
    echo "$(echo "scale=1; $bytes/1048576" | bc) MB"
  else
    echo "$(echo "scale=1; $bytes/1024" | bc) KB"
  fi
}

# Get media duration
get_duration() {
  $FFPROBE -v quiet -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null | cut -d. -f1
}

# Get media info string
get_info() {
  local file="$1"
  local size=$(human_size "$file")
  local dur=$($FFPROBE -v quiet -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null)
  local res=$($FFPROBE -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$file" 2>/dev/null | head -1)
  local dur_fmt=""
  if [ -n "$dur" ] && [ "$dur" != "N/A" ]; then
    dur_fmt=$(printf '%02d:%02d:%02d' $(echo "$dur/3600" | bc) $(echo "$dur%3600/60" | bc) $(echo "$dur%60" | bc) 2>/dev/null || echo "")
  fi
  echo "${size}${res:+, ${res}}${dur_fmt:+, ${dur_fmt}}"
}

# ===== COMMANDS =====

cmd_convert() {
  local input="" output="" quality="$QUALITY" bitrate="" extra=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input|-i)   input="$2"; shift 2 ;;
      --output|-o)  output="$2"; shift 2 ;;
      --quality|-q) quality="$2"; shift 2 ;;
      --bitrate|-b) bitrate="$2"; shift 2 ;;
      --extra)      extra="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "Missing --input"; exit 1; }
  [ ! -f "$input" ] && { err "File not found: $input"; exit 1; }
  [ -z "$output" ] && { output="${OUTPUT_DIR}/$(basename "${input%.*}").mp4"; }

  mkdir -p "$(dirname "$output")"
  info "Converting $(basename "$input") → $(basename "$output")"

  local crf=$(get_crf "$quality")
  local preset=$(get_preset "$quality")

  local ext="${output##*.}"
  local cmd=("$FFMPEG" -y -i "$input")

  if [ -n "$extra" ]; then
    eval cmd+=($extra)
  elif [[ "$ext" =~ ^(mp4|m4v)$ ]]; then
    cmd+=(-c:v libx264 -crf "$crf" -preset "$preset" -c:a aac)
    [ -n "$bitrate" ] && cmd+=(-b:a "$bitrate")
  elif [[ "$ext" =~ ^(webm)$ ]]; then
    cmd+=(-c:v libvpx-vp9 -crf "$crf" -b:v 0 -c:a libopus)
  elif [[ "$ext" =~ ^(mkv)$ ]]; then
    cmd+=(-c:v libx264 -crf "$crf" -preset "$preset" -c:a copy)
  elif [[ "$ext" =~ ^(mp3)$ ]]; then
    cmd+=(-vn -c:a libmp3lame)
    [ -n "$bitrate" ] && cmd+=(-b:a "$bitrate") || cmd+=(-b:a 192k)
  elif [[ "$ext" =~ ^(flac)$ ]]; then
    cmd+=(-vn -c:a flac)
  elif [[ "$ext" =~ ^(wav)$ ]]; then
    cmd+=(-vn -c:a pcm_s16le)
  elif [[ "$ext" =~ ^(aac|m4a)$ ]]; then
    cmd+=(-vn -c:a aac)
    [ -n "$bitrate" ] && cmd+=(-b:a "$bitrate") || cmd+=(-b:a 192k)
  else
    cmd+=(-c:v libx264 -crf "$crf" -preset "$preset" -c:a aac)
  fi

  cmd+=("$output")
  "${cmd[@]}" 2>/dev/null

  if [ -f "$output" ]; then
    ok "Done — $(basename "$output") ($(get_info "$output"))"
  else
    err "Conversion failed"
    exit 1
  fi
}

cmd_extract_audio() {
  local input="" format="mp3" bitrate="" output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input|-i)   input="$2"; shift 2 ;;
      --format|-f)  format="$2"; shift 2 ;;
      --bitrate|-b) bitrate="$2"; shift 2 ;;
      --output|-o)  output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "Missing --input"; exit 1; }
  [ ! -f "$input" ] && { err "File not found: $input"; exit 1; }
  [ -z "$output" ] && output="${OUTPUT_DIR}/$(basename "${input%.*}").${format}"

  mkdir -p "$(dirname "$output")"
  info "Extracting audio from $(basename "$input") → $(basename "$output")"

  cmd_convert --input "$input" --output "$output" ${bitrate:+--bitrate "$bitrate"}
}

cmd_compress() {
  local input="" output="" target_size="" max_width="" preset=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input|-i)       input="$2"; shift 2 ;;
      --output|-o)      output="$2"; shift 2 ;;
      --target-size|-t) target_size="$2"; shift 2 ;;
      --max-width|-w)   max_width="$2"; shift 2 ;;
      --preset|-p)      preset="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "Missing --input"; exit 1; }
  [ ! -f "$input" ] && { err "File not found: $input"; exit 1; }
  [ -z "$output" ] && output="${OUTPUT_DIR}/$(basename "${input%.*}")-compressed.mp4"

  mkdir -p "$(dirname "$output")"

  # Apply preset defaults
  case "${preset:-}" in
    web)    max_width="${max_width:-1280}"; local crf=26 ;;
    social) max_width="${max_width:-1080}"; local crf=24 ;;
    email)  max_width="${max_width:-854}";  local crf=28 ;;
    *)      local crf=23 ;;
  esac

  info "Compressing $(basename "$input") → $(basename "$output")"

  local cmd=("$FFMPEG" -y -i "$input" -c:v libx264 -crf "$crf" -preset medium -c:a aac -b:a 128k)

  if [ -n "$max_width" ]; then
    cmd+=(-vf "scale='min(${max_width},iw)':-2")
  fi

  if [ -n "$target_size" ]; then
    # Calculate target bitrate from target size and duration
    local dur=$(get_duration "$input")
    local target_bytes
    case "$target_size" in
      *M) target_bytes=$(echo "${target_size%M} * 1048576" | bc | cut -d. -f1) ;;
      *G) target_bytes=$(echo "${target_size%G} * 1073741824" | bc | cut -d. -f1) ;;
      *K) target_bytes=$(echo "${target_size%K} * 1024" | bc | cut -d. -f1) ;;
      *)  target_bytes="$target_size" ;;
    esac
    if [ -n "$dur" ] && [ "$dur" -gt 0 ]; then
      local target_bitrate=$(echo "$target_bytes * 8 / $dur" | bc)
      cmd=("$FFMPEG" -y -i "$input" -c:v libx264 -b:v "${target_bitrate}" -preset medium -c:a aac -b:a 128k)
      [ -n "$max_width" ] && cmd+=(-vf "scale='min(${max_width},iw)':-2")
    fi
  fi

  cmd+=("$output")
  "${cmd[@]}" 2>/dev/null

  if [ -f "$output" ]; then
    local orig_size=$(human_size "$input")
    local new_size=$(human_size "$output")
    ok "Done — $(basename "$output") ($new_size, was $orig_size)"
  else
    err "Compression failed"
    exit 1
  fi
}

cmd_thumbnail() {
  local input="" output="" at="" interval="" output_dir=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input|-i)      input="$2"; shift 2 ;;
      --output|-o)     output="$2"; shift 2 ;;
      --at)            at="$2"; shift 2 ;;
      --interval)      interval="$2"; shift 2 ;;
      --output-dir|-d) output_dir="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "Missing --input"; exit 1; }
  [ ! -f "$input" ] && { err "File not found: $input"; exit 1; }

  if [ -n "$interval" ]; then
    # Multiple thumbnails
    output_dir="${output_dir:-${OUTPUT_DIR}/thumbs}"
    mkdir -p "$output_dir"
    info "Generating thumbnails every ${interval}s from $(basename "$input")"
    $FFMPEG -y -i "$input" -vf "fps=1/${interval}" "${output_dir}/thumb_%04d.jpg" 2>/dev/null
    local count=$(ls "$output_dir"/thumb_*.jpg 2>/dev/null | wc -l)
    ok "Generated $count thumbnails in $output_dir"
  else
    # Single thumbnail
    if [ -z "$at" ]; then
      # Default to 50% mark
      local dur=$(get_duration "$input")
      at=$(echo "${dur:-10} / 2" | bc)
    fi
    output="${output:-${OUTPUT_DIR}/$(basename "${input%.*}")-thumb.jpg}"
    mkdir -p "$(dirname "$output")"
    info "Generating thumbnail at ${at} from $(basename "$input")"
    $FFMPEG -y -ss "$at" -i "$input" -vframes 1 -q:v 2 "$output" 2>/dev/null
    ok "Thumbnail: $output"
  fi
}

cmd_gif() {
  local input="" output="" start="00:00:00" duration=5 width=480 quality="medium"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input|-i)    input="$2"; shift 2 ;;
      --output|-o)   output="$2"; shift 2 ;;
      --start|-s)    start="$2"; shift 2 ;;
      --duration|-d) duration="$2"; shift 2 ;;
      --width|-w)    width="$2"; shift 2 ;;
      --quality|-q)  quality="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "Missing --input"; exit 1; }
  [ ! -f "$input" ] && { err "File not found: $input"; exit 1; }
  output="${output:-${OUTPUT_DIR}/$(basename "${input%.*}").gif}"
  mkdir -p "$(dirname "$output")"

  local fps=15
  [ "$quality" = "high" ] && fps=24

  info "Creating GIF from $(basename "$input") (${duration}s, ${width}px)"

  if [ "$quality" = "high" ]; then
    # Two-pass with palette for better quality
    local palette="/tmp/palette_$$.png"
    $FFMPEG -y -ss "$start" -t "$duration" -i "$input" \
      -vf "fps=${fps},scale=${width}:-1:flags=lanczos,palettegen" "$palette" 2>/dev/null
    $FFMPEG -y -ss "$start" -t "$duration" -i "$input" -i "$palette" \
      -lavfi "fps=${fps},scale=${width}:-1:flags=lanczos [x]; [x][1:v] paletteuse" "$output" 2>/dev/null
    rm -f "$palette"
  else
    $FFMPEG -y -ss "$start" -t "$duration" -i "$input" \
      -vf "fps=${fps},scale=${width}:-1:flags=lanczos" "$output" 2>/dev/null
  fi

  if [ -f "$output" ]; then
    ok "GIF created: $output ($(human_size "$output"))"
  else
    err "GIF creation failed"
    exit 1
  fi
}

cmd_trim() {
  local input="" output="" start="" end="" duration=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input|-i)    input="$2"; shift 2 ;;
      --output|-o)   output="$2"; shift 2 ;;
      --start|-s)    start="$2"; shift 2 ;;
      --end|-e)      end="$2"; shift 2 ;;
      --duration|-d) duration="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "Missing --input"; exit 1; }
  [ ! -f "$input" ] && { err "File not found: $input"; exit 1; }

  local ext="${input##*.}"
  output="${output:-${OUTPUT_DIR}/$(basename "${input%.*}")-trimmed.${ext}}"
  mkdir -p "$(dirname "$output")"

  info "Trimming $(basename "$input")"

  local cmd=("$FFMPEG" -y)
  [ -n "$start" ] && cmd+=(-ss "$start")
  cmd+=(-i "$input")
  [ -n "$end" ] && cmd+=(-to "$end")
  [ -n "$duration" ] && cmd+=(-t "$duration")
  cmd+=(-c copy "$output")

  "${cmd[@]}" 2>/dev/null

  if [ -f "$output" ]; then
    ok "Trimmed: $output ($(get_info "$output"))"
  else
    err "Trim failed"
    exit 1
  fi
}

cmd_merge() {
  local inputs="" file_list="" output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --inputs)     inputs="$2"; shift 2 ;;
      --file-list)  file_list="$2"; shift 2 ;;
      --output|-o)  output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  output="${output:-${OUTPUT_DIR}/merged.mp4}"
  mkdir -p "$(dirname "$output")"

  local concat_file="/tmp/concat_$$.txt"

  if [ -n "$file_list" ]; then
    cp "$file_list" "$concat_file"
  elif [ -n "$inputs" ]; then
    IFS=',' read -ra FILES <<< "$inputs"
    for f in "${FILES[@]}"; do
      echo "file '$(realpath "$f")'" >> "$concat_file"
    done
  else
    err "Provide --inputs or --file-list"
    exit 1
  fi

  local count=$(wc -l < "$concat_file")
  info "Merging $count files → $(basename "$output")"

  $FFMPEG -y -f concat -safe 0 -i "$concat_file" -c copy "$output" 2>/dev/null
  rm -f "$concat_file"

  if [ -f "$output" ]; then
    ok "Merged: $output ($(get_info "$output"))"
  else
    err "Merge failed"
    exit 1
  fi
}

cmd_info() {
  local input=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input|-i) input="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { err "Missing --input"; exit 1; }
  [ ! -f "$input" ] && { err "File not found: $input"; exit 1; }

  echo "━━━ Media Info: $(basename "$input") ━━━"
  echo "Size: $(human_size "$input")"

  $FFPROBE -v quiet -show_format -show_streams "$input" 2>/dev/null | while IFS='=' read -r key val; do
    case "$key" in
      format_long_name) echo "Format: $val" ;;
      duration)         printf "Duration: %02d:%02d:%02d\n" $(echo "$val/3600" | bc) $(echo "$val%3600/60" | bc) $(echo "$val%60/1" | bc) 2>/dev/null ;;
      width)            printf "Width: %s\n" "$val" ;;
      height)           printf "Height: %s\n" "$val" ;;
      codec_name)       echo "Codec: $val" ;;
      sample_rate)      echo "Sample Rate: $val Hz" ;;
      channels)         echo "Channels: $val" ;;
      bit_rate)         [ "$val" != "N/A" ] && echo "Bitrate: $(echo "$val/1000" | bc) kbps" ;;
    esac
  done
}

cmd_batch() {
  local input_dir="" output_dir="" format="mp4" quality="$QUALITY" bitrate=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input-dir|-i)  input_dir="$2"; shift 2 ;;
      --output-dir|-o) output_dir="$2"; shift 2 ;;
      --format|-f)     format="$2"; shift 2 ;;
      --quality|-q)    quality="$2"; shift 2 ;;
      --bitrate|-b)    bitrate="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input_dir" ] && { err "Missing --input-dir"; exit 1; }
  [ ! -d "$input_dir" ] && { err "Directory not found: $input_dir"; exit 1; }
  output_dir="${output_dir:-${OUTPUT_DIR}/converted}"
  mkdir -p "$output_dir"

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$input_dir" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.webm" -o -name "*.mov" -o -name "*.flv" -o -name "*.wmv" -o -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.aac" -o -name "*.ogg" \) -print0 | sort -z)

  local total=${#files[@]}
  [ "$total" -eq 0 ] && { err "No media files found in $input_dir"; exit 1; }

  log "📂 Processing $total files from $input_dir"

  local done_count=0 fail_count=0
  for f in "${files[@]}"; do
    done_count=$((done_count + 1))
    local basename_f=$(basename "${f%.*}")
    local output_file="${output_dir}/${basename_f}.${format}"
    info "$done_count/$total $(basename "$f") → $(basename "$output_file")"
    if cmd_convert --input "$f" --output "$output_file" --quality "$quality" ${bitrate:+--bitrate "$bitrate"} 2>/dev/null; then
      :
    else
      fail_count=$((fail_count + 1))
    fi
  done

  ok "Batch complete — $((done_count - fail_count))/$total converted"
  [ "$fail_count" -gt 0 ] && log "${YELLOW}⚠️  $fail_count files failed${NC}"
}

# ===== MAIN =====

check_deps

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  convert)       cmd_convert "$@" ;;
  extract-audio) cmd_extract_audio "$@" ;;
  compress)      cmd_compress "$@" ;;
  thumbnail)     cmd_thumbnail "$@" ;;
  gif)           cmd_gif "$@" ;;
  trim)          cmd_trim "$@" ;;
  merge)         cmd_merge "$@" ;;
  info)          cmd_info "$@" ;;
  batch)         cmd_batch "$@" ;;
  help|*)
    echo "Media Converter — ffmpeg-based media processing"
    echo ""
    echo "Usage: bash run.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  convert        Convert between formats (video/audio)"
    echo "  extract-audio  Extract audio track from video"
    echo "  compress       Compress video for web/social/email"
    echo "  thumbnail      Generate thumbnail images from video"
    echo "  gif            Create animated GIF from video"
    echo "  trim           Cut/trim a segment from media"
    echo "  merge          Concatenate multiple files"
    echo "  info           Show media file information"
    echo "  batch          Batch convert a directory"
    echo ""
    echo "Options (vary by command):"
    echo "  --input, -i     Input file path"
    echo "  --output, -o    Output file path"
    echo "  --format, -f    Output format (mp4, webm, mp3, etc.)"
    echo "  --quality, -q   Quality preset (low, medium, high, lossless)"
    echo "  --bitrate, -b   Audio bitrate (e.g., 320k)"
    echo ""
    echo "Examples:"
    echo "  bash run.sh convert -i video.mkv -o video.mp4"
    echo "  bash run.sh extract-audio -i video.mp4 -f mp3"
    echo "  bash run.sh compress -i large.mp4 --target-size 50M"
    echo "  bash run.sh gif -i video.mp4 --duration 5 --width 480"
    echo "  bash run.sh batch -i ./raw -o ./converted -f mp4"
    ;;
esac
