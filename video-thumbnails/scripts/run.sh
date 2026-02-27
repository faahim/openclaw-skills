#!/bin/bash
# Video Thumbnails — Extract thumbnails, contact sheets, and GIF previews from videos
# Requires: ffmpeg, imagemagick (montage, convert)

set -euo pipefail

VERSION="1.0.0"
QUALITY="${VT_QUALITY:-85}"
WIDTH="${VT_WIDTH:-640}"
FORMAT="${VT_FORMAT:-jpg}"
MAX_GIF_SIZE="${VT_MAX_GIF_SIZE:-10}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "[video-thumbnails] $1"; }
ok()  { echo -e "[video-thumbnails] ${GREEN}✅ $1${NC}"; }
err() { echo -e "[video-thumbnails] ${RED}❌ $1${NC}" >&2; }
warn(){ echo -e "[video-thumbnails] ${YELLOW}⚠️  $1${NC}"; }

usage() {
  cat <<EOF
Video Thumbnails v${VERSION}

Usage: bash run.sh <command> [options]

Commands:
  thumbnails      Extract evenly-spaced thumbnails
  contact-sheet   Generate a grid contact sheet
  gif             Create animated GIF preview
  timestamps      Extract frames at specific times
  batch           Process multiple videos

Options:
  --input FILE        Input video file (required)
  --input-dir DIR     Input directory (batch mode)
  --output FILE       Output file path
  --output-dir DIR    Output directory (default: ./thumbs)
  --count N           Number of thumbnails (default: 8)
  --width N           Thumbnail width in px (default: 640)
  --format FMT        Output format: jpg, png, webp (default: jpg)
  --quality N         Quality 1-100 (default: 85)
  --cols N            Contact sheet columns (default: 4)
  --rows N            Contact sheet rows (default: 3)
  --timestamp         Overlay timestamp on thumbnails
  --fps N             GIF frames per second (default: 1)
  --duration N        GIF duration in seconds (default: 10)
  --start TIME        Start time (HH:MM:SS, default: auto)
  --times "T1,T2,..." Comma-separated timestamps
  --header TEXT       Contact sheet header text
  --mode MODE         Batch mode: thumbnails|contact-sheet|gif
  -h, --help          Show this help

Examples:
  bash run.sh thumbnails --input movie.mp4 --count 12
  bash run.sh contact-sheet --input movie.mp4 --cols 4 --rows 3 --timestamp
  bash run.sh gif --input movie.mp4 --duration 15 --width 320
  bash run.sh timestamps --input movie.mp4 --times "00:05:00,00:30:00,01:00:00"
  bash run.sh batch --input-dir ./videos --mode contact-sheet
EOF
  exit 0
}

check_deps() {
  local missing=()
  command -v ffmpeg >/dev/null 2>&1 || missing+=("ffmpeg")
  command -v ffprobe >/dev/null 2>&1 || missing+=("ffprobe")
  command -v montage >/dev/null 2>&1 || missing+=("imagemagick (montage)")
  command -v convert >/dev/null 2>&1 || missing+=("imagemagick (convert)")

  if [ ${#missing[@]} -gt 0 ]; then
    err "Missing dependencies: ${missing[*]}"
    echo "Install with:"
    echo "  Ubuntu/Debian: sudo apt-get install -y ffmpeg imagemagick"
    echo "  macOS: brew install ffmpeg imagemagick"
    exit 1
  fi
}

get_duration() {
  local input="$1"
  ffprobe -v error -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null | cut -d. -f1
}

get_duration_fmt() {
  local secs="$1"
  printf "%02d:%02d:%02d" $((secs/3600)) $(((secs%3600)/60)) $((secs%60))
}

secs_from_timestamp() {
  local ts="$1"
  local h m s
  IFS=: read -r h m s <<< "$ts"
  echo $(( 10#$h * 3600 + 10#$m * 60 + 10#$s ))
}

basename_no_ext() {
  local name
  name=$(basename "$1")
  echo "${name%.*}"
}

cmd_thumbnails() {
  local input="" count=8 width="$WIDTH" output_dir="./thumbs" fmt="$FORMAT" quality="$QUALITY" start_offset=0 timestamp=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --count) count="$2"; shift 2 ;;
      --width) width="$2"; shift 2 ;;
      --output-dir) output_dir="$2"; shift 2 ;;
      --format) fmt="$2"; shift 2 ;;
      --quality) quality="$2"; shift 2 ;;
      --start) start_offset=$(secs_from_timestamp "$2"); shift 2 ;;
      --timestamp) timestamp=true; shift ;;
      *) shift ;;
    esac
  done

  [[ -z "$input" ]] && { err "Missing --input"; exit 1; }
  [[ ! -f "$input" ]] && { err "File not found: $input"; exit 1; }

  mkdir -p "$output_dir"
  local duration
  duration=$(get_duration "$input")
  [[ -z "$duration" || "$duration" -eq 0 ]] && { err "Could not determine video duration"; exit 1; }

  local effective_duration=$((duration - start_offset))
  [[ $effective_duration -le 0 ]] && { err "Start offset exceeds video duration"; exit 1; }

  local interval=$((effective_duration / (count + 1)))
  local vname
  vname=$(basename_no_ext "$input")

  log "Extracting $count thumbnails from $(basename "$input") (duration: $(get_duration_fmt "$duration"))"
  log "Frame interval: every ${interval}s, width: ${width}px"

  for i in $(seq 1 "$count"); do
    local ts=$((start_offset + interval * i))
    local ts_fmt
    ts_fmt=$(get_duration_fmt "$ts")
    local outfile="${output_dir}/${vname}_$(printf '%03d' "$i").${fmt}"

    local scale_filter="scale=${width}:-1"
    local draw_filter=""
    if $timestamp; then
      draw_filter=",drawtext=text='${ts_fmt}':x=10:y=h-30:fontsize=18:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=4"
    fi

    ffmpeg -y -ss "$ts" -i "$input" \
      -vframes 1 \
      -vf "${scale_filter}${draw_filter}" \
      -q:v $((100 - quality > 1 ? (100 - quality) / 3 : 1)) \
      "$outfile" 2>/dev/null

    if [[ -f "$outfile" ]]; then
      ok "$outfile ($ts_fmt)"
    else
      warn "Failed to extract frame at $ts_fmt"
    fi
  done

  log "Done — $count thumbnails saved to $output_dir/"
}

cmd_contact_sheet() {
  local input="" cols=4 rows=3 thumb_width=320 timestamp=false header="" output="" fmt="$FORMAT" quality="$QUALITY"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --cols) cols="$2"; shift 2 ;;
      --rows) rows="$2"; shift 2 ;;
      --thumb-width) thumb_width="$2"; shift 2 ;;
      --timestamp) timestamp=true; shift ;;
      --header) header="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --format) fmt="$2"; shift 2 ;;
      --quality) quality="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$input" ]] && { err "Missing --input"; exit 1; }
  [[ ! -f "$input" ]] && { err "File not found: $input"; exit 1; }

  local count=$((cols * rows))
  local vname
  vname=$(basename_no_ext "$input")
  [[ -z "$output" ]] && output="${vname}_contact_sheet.${fmt}"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" EXIT

  local ts_flag=""
  $timestamp && ts_flag="--timestamp"

  cmd_thumbnails --input "$input" --count "$count" --width "$thumb_width" --output-dir "$tmpdir" --format "$fmt" --quality "$quality" $ts_flag

  local tile="${cols}x${rows}"
  local geometry="${thumb_width}x+4+4"

  log "Compositing ${tile} contact sheet..."

  local label_args=()
  if [[ -n "$header" ]]; then
    label_args=(-label "$header" -gravity North)
  fi

  montage "$tmpdir"/*.${fmt} \
    -tile "$tile" \
    -geometry "$geometry" \
    -background "#1a1a1a" \
    -border 2 \
    -bordercolor "#333333" \
    -quality "$quality" \
    "${label_args[@]}" \
    "$output" 2>/dev/null

  if [[ -f "$output" ]]; then
    local size
    size=$(du -h "$output" | cut -f1)
    ok "Contact sheet: $output ($size)"
  else
    err "Failed to create contact sheet"
    exit 1
  fi
}

cmd_gif() {
  local input="" duration=10 fps=1 width=320 start="" output=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --duration) duration="$2"; shift 2 ;;
      --fps) fps="$2"; shift 2 ;;
      --width) width="$2"; shift 2 ;;
      --start) start="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$input" ]] && { err "Missing --input"; exit 1; }
  [[ ! -f "$input" ]] && { err "File not found: $input"; exit 1; }

  local vname
  vname=$(basename_no_ext "$input")
  [[ -z "$output" ]] && output="${vname}_preview.gif"

  local vid_duration
  vid_duration=$(get_duration "$input")

  # If no start specified, pick a point ~10% into the video
  if [[ -z "$start" ]]; then
    local start_secs=$((vid_duration / 10))
    start=$(get_duration_fmt "$start_secs")
  fi

  log "Creating GIF preview: ${duration}s @ ${fps}fps, ${width}px wide"
  log "Starting at $start"

  # Two-pass for better quality GIF
  local palette
  palette=$(mktemp /tmp/palette_XXXX.png)
  trap "rm -f $palette" EXIT

  ffmpeg -y -ss "$start" -t "$duration" -i "$input" \
    -vf "fps=${fps},scale=${width}:-1:flags=lanczos,palettegen=stats_mode=diff" \
    "$palette" 2>/dev/null

  ffmpeg -y -ss "$start" -t "$duration" -i "$input" -i "$palette" \
    -lavfi "fps=${fps},scale=${width}:-1:flags=lanczos [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=3" \
    "$output" 2>/dev/null

  if [[ -f "$output" ]]; then
    local size
    size=$(du -h "$output" | cut -f1)
    ok "GIF preview: $output ($size)"

    local size_mb
    size_mb=$(du -m "$output" | cut -f1)
    if [[ "$size_mb" -gt "$MAX_GIF_SIZE" ]]; then
      warn "GIF is ${size_mb}MB (limit: ${MAX_GIF_SIZE}MB). Try reducing --width, --fps, or --duration."
    fi
  else
    err "Failed to create GIF"
    exit 1
  fi
}

cmd_timestamps() {
  local input="" times="" width="$WIDTH" output_dir="./thumbs" fmt="$FORMAT" quality="$QUALITY"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --times) times="$2"; shift 2 ;;
      --width) width="$2"; shift 2 ;;
      --output-dir) output_dir="$2"; shift 2 ;;
      --format) fmt="$2"; shift 2 ;;
      --quality) quality="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$input" ]] && { err "Missing --input"; exit 1; }
  [[ -z "$times" ]] && { err "Missing --times"; exit 1; }
  [[ ! -f "$input" ]] && { err "File not found: $input"; exit 1; }

  mkdir -p "$output_dir"
  local vname
  vname=$(basename_no_ext "$input")

  log "Extracting frames at specific timestamps from $(basename "$input")"

  IFS=',' read -ra TIMESTAMPS <<< "$times"
  local i=1
  for ts in "${TIMESTAMPS[@]}"; do
    ts=$(echo "$ts" | xargs)  # trim whitespace
    local outfile="${output_dir}/${vname}_${ts//:/}.${fmt}"

    ffmpeg -y -ss "$ts" -i "$input" \
      -vframes 1 \
      -vf "scale=${width}:-1" \
      -q:v 2 \
      "$outfile" 2>/dev/null

    if [[ -f "$outfile" ]]; then
      ok "$outfile ($ts)"
    else
      warn "Failed at $ts"
    fi
    ((i++))
  done

  log "Done — ${#TIMESTAMPS[@]} frames saved to $output_dir/"
}

cmd_batch() {
  local input_dir="" mode="contact-sheet" output_dir="./sheets" cols=4 rows=3 count=8 width="$WIDTH"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --input-dir) input_dir="$2"; shift 2 ;;
      --mode) mode="$2"; shift 2 ;;
      --output-dir) output_dir="$2"; shift 2 ;;
      --cols) cols="$2"; shift 2 ;;
      --rows) rows="$2"; shift 2 ;;
      --count) count="$2"; shift 2 ;;
      --width) width="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$input_dir" ]] && { err "Missing --input-dir"; exit 1; }
  [[ ! -d "$input_dir" ]] && { err "Directory not found: $input_dir"; exit 1; }

  mkdir -p "$output_dir"

  local processed=0
  for video in "$input_dir"/*.{mp4,mkv,avi,mov,webm,flv,wmv} ; do
    [[ ! -f "$video" ]] && continue
    log "Processing: $(basename "$video")"

    case "$mode" in
      thumbnails)
        local vname
        vname=$(basename_no_ext "$video")
        cmd_thumbnails --input "$video" --count "$count" --width "$width" --output-dir "$output_dir/$vname"
        ;;
      contact-sheet)
        local vname
        vname=$(basename_no_ext "$video")
        cmd_contact_sheet --input "$video" --cols "$cols" --rows "$rows" --output "$output_dir/${vname}_sheet.jpg"
        ;;
      gif)
        local vname
        vname=$(basename_no_ext "$video")
        cmd_gif --input "$video" --width "$width" --output "$output_dir/${vname}_preview.gif"
        ;;
      *)
        err "Unknown mode: $mode (use thumbnails, contact-sheet, or gif)"
        exit 1
        ;;
    esac

    ((processed++))
  done

  if [[ $processed -eq 0 ]]; then
    warn "No video files found in $input_dir"
  else
    ok "Batch complete — processed $processed videos"
  fi
}

# Main
check_deps

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  thumbnails)     cmd_thumbnails "$@" ;;
  contact-sheet)  cmd_contact_sheet "$@" ;;
  gif)            cmd_gif "$@" ;;
  timestamps)     cmd_timestamps "$@" ;;
  batch)          cmd_batch "$@" ;;
  -h|--help|help) usage ;;
  "")             usage ;;
  *)              err "Unknown command: $COMMAND"; usage ;;
esac
