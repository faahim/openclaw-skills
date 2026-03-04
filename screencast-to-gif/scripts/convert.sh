#!/bin/bash
# screencast-to-gif — Convert video files to optimized GIFs
# Requires: ffmpeg, gifsicle

set -euo pipefail

# Defaults (overridable via env)
WIDTH="${GIF_DEFAULT_WIDTH:-800}"
FPS="${GIF_DEFAULT_FPS:-15}"
COLORS="${GIF_DEFAULT_COLORS:-256}"
OPTIMIZE="${GIF_DEFAULT_OPTIMIZE:-3}"
SPEED="1.0"
START=""
DURATION=""
MAX_SIZE=""
OUTPUT=""
INPUT=""
LOOP="0"
NO_OPTIMIZE=false
PALETTE=""
TEXT=""
TEXT_POS="bottom"
DITHER=false

PREFIX="[screencast-to-gif]"

usage() {
  cat <<EOF
Usage: $(basename "$0") --input <file|dir> [options]

Options:
  --input <path>      Input video file or directory (required)
  --output <path>     Output GIF path (default: <input>.gif)
  --width <px>        Output width in pixels (default: $WIDTH)
  --fps <n>           Frames per second (default: $FPS)
  --start <secs>      Start time in seconds
  --duration <secs>   Duration in seconds
  --speed <mult>      Playback speed multiplier (default: 1.0)
  --max-size <MB>     Max file size in MB (auto-adjusts quality)
  --colors <n>        Palette size 64-256 (default: $COLORS)
  --optimize <1-3>    Gifsicle optimization level (default: $OPTIMIZE)
  --loop <n>          Loop count, 0=infinite (default: 0)
  --palette <file>    Use custom palette PNG
  --text <string>     Add text overlay
  --text-position <p> Text position: top|bottom (default: bottom)
  --dither            Enable dithering for smoother gradients
  --no-optimize       Skip gifsicle optimization pass
  -h|--help           Show this help
EOF
  exit 0
}

check_deps() {
  local missing=()
  command -v ffmpeg >/dev/null 2>&1 || missing+=(ffmpeg)
  command -v gifsicle >/dev/null 2>&1 || missing+=(gifsicle)
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "$PREFIX ❌ Missing dependencies: ${missing[*]}"
    echo "$PREFIX Install with:"
    echo "  Ubuntu/Debian: sudo apt-get install -y ${missing[*]}"
    echo "  macOS:         brew install ${missing[*]}"
    exit 1
  fi
}

get_video_info() {
  local file="$1"
  local w h fps dur
  w=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file" 2>/dev/null | head -1)
  h=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file" 2>/dev/null | head -1)
  fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$file" 2>/dev/null | head -1)
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null | head -1)
  
  # Evaluate fractional fps (e.g., 30000/1001)
  if [[ "$fps" == */* ]]; then
    fps=$(echo "scale=2; $fps" | bc 2>/dev/null || echo "30")
  fi
  dur=$(printf "%.1f" "$dur" 2>/dev/null || echo "0")
  
  echo "${w:-0}x${h:-0}, ${fps}fps, ${dur}s"
}

convert_single() {
  local input_file="$1"
  local output_file="$2"
  
  local basename_noext="${input_file%.*}"
  [[ -z "$output_file" ]] && output_file="${basename_noext}.gif"
  
  local info
  info=$(get_video_info "$input_file")
  echo "$PREFIX Input: $(basename "$input_file") ($info)"
  echo "$PREFIX Converting: ${WIDTH}px wide, ${FPS}fps, optimized palette"
  
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT
  
  # Build ffmpeg filter chain
  local filters="fps=${FPS},scale=${WIDTH}:-1:flags=lanczos"
  
  # Speed adjustment
  if [[ "$SPEED" != "1.0" && "$SPEED" != "1" ]]; then
    local setpts
    setpts=$(echo "scale=4; 1/$SPEED" | bc 2>/dev/null || echo "1")
    filters="setpts=${setpts}*PTS,${filters}"
  fi
  
  # Text overlay
  if [[ -n "$TEXT" ]]; then
    local y_pos="h-th-20"
    [[ "$TEXT_POS" == "top" ]] && y_pos="20"
    filters="${filters},drawtext=text='${TEXT}':fontsize=24:fontcolor=white:borderw=2:bordercolor=black:x=(w-tw)/2:y=${y_pos}"
  fi
  
  # Time options
  local time_opts=()
  [[ -n "$START" ]] && time_opts+=(-ss "$START")
  [[ -n "$DURATION" ]] && time_opts+=(-t "$DURATION")
  
  # Step 1: Generate optimized palette
  local palette_file="${tmpdir}/palette.png"
  if [[ -n "$PALETTE" && -f "$PALETTE" ]]; then
    palette_file="$PALETTE"
  else
    local palette_filters="${filters},palettegen=max_colors=${COLORS}:stats_mode=diff"
    ffmpeg -v warning "${time_opts[@]}" -i "$input_file" \
      -vf "$palette_filters" \
      -y "$palette_file"
  fi
  
  # Step 2: Convert with palette
  local dither_method="sierra2_4a"
  $DITHER && dither_method="bayer:bayer_scale=5"
  
  local gif_raw="${tmpdir}/raw.gif"
  ffmpeg -v warning "${time_opts[@]}" -i "$input_file" -i "$palette_file" \
    -lavfi "${filters} [x]; [x][1:v] paletteuse=dither=${dither_method}" \
    -loop "$LOOP" \
    -y "$gif_raw"
  
  local raw_size
  raw_size=$(stat -f%z "$gif_raw" 2>/dev/null || stat -c%s "$gif_raw" 2>/dev/null || echo "0")
  local raw_mb
  raw_mb=$(echo "scale=1; $raw_size / 1048576" | bc 2>/dev/null || echo "?")
  echo "$PREFIX Raw GIF: ${raw_mb}MB"
  
  # Step 3: Optimize with gifsicle
  if $NO_OPTIMIZE; then
    cp "$gif_raw" "$output_file"
  else
    gifsicle -O"$OPTIMIZE" --lossy=80 "$gif_raw" -o "$output_file" 2>/dev/null || \
    gifsicle -O"$OPTIMIZE" "$gif_raw" -o "$output_file"
  fi
  
  local final_size
  final_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "0")
  local final_mb
  final_mb=$(echo "scale=1; $final_size / 1048576" | bc 2>/dev/null || echo "?")
  
  if [[ "$raw_size" -gt 0 && "$final_size" -gt 0 ]]; then
    local reduction
    reduction=$(echo "scale=0; (1 - $final_size / $raw_size) * 100" | bc 2>/dev/null || echo "?")
    echo "$PREFIX Optimized: ${final_mb}MB (${reduction}% reduction)"
  fi
  
  # Step 4: Max size enforcement (reduce colors iteratively)
  if [[ -n "$MAX_SIZE" ]]; then
    local max_bytes
    max_bytes=$(echo "$MAX_SIZE * 1048576" | bc 2>/dev/null | cut -d. -f1)
    local current_colors=$COLORS
    
    while [[ "$final_size" -gt "$max_bytes" && "$current_colors" -gt 32 ]]; do
      current_colors=$((current_colors / 2))
      [[ $current_colors -lt 32 ]] && current_colors=32
      echo "$PREFIX Size ${final_mb}MB exceeds ${MAX_SIZE}MB limit. Retrying with ${current_colors} colors..."
      
      # Regenerate with fewer colors
      ffmpeg -v warning "${time_opts[@]}" -i "$input_file" \
        -vf "${filters},palettegen=max_colors=${current_colors}:stats_mode=diff" \
        -y "$palette_file"
      
      ffmpeg -v warning "${time_opts[@]}" -i "$input_file" -i "$palette_file" \
        -lavfi "${filters} [x]; [x][1:v] paletteuse=dither=${dither_method}" \
        -loop "$LOOP" \
        -y "$gif_raw"
      
      if $NO_OPTIMIZE; then
        cp "$gif_raw" "$output_file"
      else
        gifsicle -O"$OPTIMIZE" --lossy=80 "$gif_raw" -o "$output_file" 2>/dev/null || \
        gifsicle -O"$OPTIMIZE" "$gif_raw" -o "$output_file"
      fi
      
      final_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "0")
      final_mb=$(echo "scale=1; $final_size / 1048576" | bc 2>/dev/null || echo "?")
    done
    
    if [[ "$final_size" -gt "$max_bytes" ]]; then
      echo "$PREFIX ⚠️ Could not reduce below ${MAX_SIZE}MB. Try shorter duration, lower FPS, or smaller width."
    fi
  fi
  
  echo "$PREFIX ✅ Output: $output_file"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --width) WIDTH="$2"; shift 2 ;;
    --fps) FPS="$2"; shift 2 ;;
    --start) START="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    --speed) SPEED="$2"; shift 2 ;;
    --max-size) MAX_SIZE="$2"; shift 2 ;;
    --colors) COLORS="$2"; shift 2 ;;
    --optimize) OPTIMIZE="$2"; shift 2 ;;
    --loop) LOOP="$2"; shift 2 ;;
    --palette) PALETTE="$2"; shift 2 ;;
    --text) TEXT="$2"; shift 2 ;;
    --text-position) TEXT_POS="$2"; shift 2 ;;
    --dither) DITHER=true; shift ;;
    --no-optimize) NO_OPTIMIZE=true; shift ;;
    -h|--help) usage ;;
    *) echo "$PREFIX Unknown option: $1"; usage ;;
  esac
done

# Validate
[[ -z "$INPUT" ]] && { echo "$PREFIX ❌ --input is required"; usage; }
check_deps

# Directory mode
if [[ -d "$INPUT" ]]; then
  found=0
  for f in "$INPUT"/*.{mp4,webm,mkv,mov,avi,MP4,WebM,MKV,MOV,AVI}; do
    [[ -f "$f" ]] || continue
    found=$((found + 1))
    convert_single "$f" ""
    echo ""
  done
  [[ $found -eq 0 ]] && echo "$PREFIX ❌ No video files found in $INPUT"
  [[ $found -gt 0 ]] && echo "$PREFIX ✅ Converted $found files"
elif [[ -f "$INPUT" ]]; then
  convert_single "$INPUT" "$OUTPUT"
else
  echo "$PREFIX ❌ Input not found: $INPUT"
  exit 1
fi
