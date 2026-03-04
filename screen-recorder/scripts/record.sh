#!/bin/bash
# Screen Recorder — Record screen to video or GIF using ffmpeg
# Supports Linux (X11) and macOS (AVFoundation)

set -euo pipefail

# Defaults
DURATION=""
OUTPUT=""
FPS="${SCREEN_REC_FPS:-30}"
REGION=""
AUDIO=""
MIC=""
FORMAT="${SCREEN_REC_FORMAT:-mp4}"
CRF="23"
PICK_WINDOW=false
WEBCAM=""
WEBCAM_SIZE="320x240"
WEBCAM_POS="bottom-right"
TO_GIF=""
COMPRESS=""
CLIP=""
CLIP_START="00:00:00"
CLIP_END=""
GIF_WIDTH="${SCREEN_REC_GIF_WIDTH:-480}"
NO_CURSOR=false
OUTPUT_DIR="${SCREEN_REC_OUTPUT_DIR:-$(pwd)}"
SEGMENT=""

show_help() {
  cat <<EOF
Screen Recorder — Record your screen using ffmpeg

USAGE:
  record.sh [OPTIONS]

RECORDING OPTIONS:
  --duration N        Record for N seconds (default: until Ctrl+C)
  --output FILE       Output file path
  --fps N             Frames per second (default: 30)
  --region WxH+X+Y    Record specific region
  --audio DEVICE      Capture system audio (pulse/alsa/default)
  --mic DEVICE        Capture microphone
  --format FMT        Output format: mp4, webm, mkv, avi (default: mp4)
  --crf N             Quality 0-51, lower=better (default: 23)
  --pick-window       Click to select a window to record
  --no-cursor         Hide mouse cursor
  --webcam DEV        Add webcam overlay (/dev/video0)
  --webcam-size WxH   Webcam size (default: 320x240)
  --webcam-position P Position: top-left, top-right, bottom-left, bottom-right

POST-PROCESSING:
  --to-gif FILE       Convert video file to animated GIF
  --compress FILE     Compress a video file
  --clip FILE         Extract clip from video
  --start HH:MM:SS   Clip start time
  --end HH:MM:SS     Clip end time
  --width N           GIF width in pixels (default: 480)

EXAMPLES:
  record.sh --duration 30 --output demo.mp4
  record.sh --region 1280x720+100+200 --duration 60 --output region.mp4
  record.sh --to-gif recording.mp4 --width 640 --fps 10 --output demo.gif
  record.sh --compress input.mp4 --crf 28 --output small.mp4
  record.sh --clip input.mp4 --start 00:01:00 --end 00:02:30 --output clip.mp4
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h) show_help ;;
    --duration) DURATION="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --fps) FPS="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --audio) AUDIO="$2"; shift 2 ;;
    --mic) MIC="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --crf) CRF="$2"; shift 2 ;;
    --pick-window) PICK_WINDOW=true; shift ;;
    --no-cursor) NO_CURSOR=true; shift ;;
    --webcam) WEBCAM="$2"; shift 2 ;;
    --webcam-size) WEBCAM_SIZE="$2"; shift 2 ;;
    --webcam-position) WEBCAM_POS="$2"; shift 2 ;;
    --to-gif) TO_GIF="$2"; shift 2 ;;
    --compress) COMPRESS="$2"; shift 2 ;;
    --clip) CLIP="$2"; shift 2 ;;
    --start) CLIP_START="$2"; shift 2 ;;
    --end) CLIP_END="$2"; shift 2 ;;
    --width) GIF_WIDTH="$2"; shift 2 ;;
    --segment) SEGMENT="$2"; shift 2 ;;
    *) echo "❌ Unknown option: $1"; echo "Run with --help for usage."; exit 1 ;;
  esac
done

# Check ffmpeg
if ! command -v ffmpeg &>/dev/null; then
  echo "❌ ffmpeg not found. Install it:"
  echo "   Ubuntu/Debian: sudo apt-get install -y ffmpeg"
  echo "   Mac: brew install ffmpeg"
  exit 1
fi

# Detect OS
OS="$(uname -s)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# ============================================
# POST-PROCESSING MODES
# ============================================

# Convert to GIF
if [[ -n "$TO_GIF" ]]; then
  [[ ! -f "$TO_GIF" ]] && echo "❌ File not found: $TO_GIF" && exit 1
  OUTPUT="${OUTPUT:-${TO_GIF%.*}.gif}"
  GIF_FPS="${FPS:-10}"
  echo "🔄 Converting $TO_GIF → $OUTPUT"
  echo "📐 Width: ${GIF_WIDTH}px | FPS: $GIF_FPS"

  # Two-pass for quality: generate palette then apply
  PALETTE="/tmp/screen_rec_palette_$$.png"
  ffmpeg -y -i "$TO_GIF" \
    -vf "fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=lanczos,palettegen=stats_mode=diff" \
    "$PALETTE" 2>/dev/null

  ffmpeg -y -i "$TO_GIF" -i "$PALETTE" \
    -lavfi "fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=lanczos [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    "$OUTPUT" 2>/dev/null

  rm -f "$PALETTE"
  SIZE=$(du -h "$OUTPUT" | cut -f1)
  echo "✅ Saved to $OUTPUT ($SIZE)"
  exit 0
fi

# Compress video
if [[ -n "$COMPRESS" ]]; then
  [[ ! -f "$COMPRESS" ]] && echo "❌ File not found: $COMPRESS" && exit 1
  OUTPUT="${OUTPUT:-${COMPRESS%.*}_compressed.${COMPRESS##*.}}"
  ORIG_SIZE=$(du -h "$COMPRESS" | cut -f1)
  echo "🗜️  Compressing $COMPRESS ($ORIG_SIZE)"

  ffmpeg -y -i "$COMPRESS" \
    -c:v libx264 -crf "$CRF" -preset medium \
    -c:a aac -b:a 128k \
    "$OUTPUT" 2>/dev/null

  NEW_SIZE=$(du -h "$OUTPUT" | cut -f1)
  ORIG_BYTES=$(stat -f%z "$COMPRESS" 2>/dev/null || stat -c%s "$COMPRESS" 2>/dev/null)
  NEW_BYTES=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null)
  if [[ -n "$ORIG_BYTES" && -n "$NEW_BYTES" && "$ORIG_BYTES" -gt 0 ]]; then
    REDUCTION=$(( (ORIG_BYTES - NEW_BYTES) * 100 / ORIG_BYTES ))
    echo "✅ Saved to $OUTPUT ($NEW_SIZE) — ${REDUCTION}% reduction"
  else
    echo "✅ Saved to $OUTPUT ($NEW_SIZE)"
  fi
  exit 0
fi

# Extract clip
if [[ -n "$CLIP" ]]; then
  [[ ! -f "$CLIP" ]] && echo "❌ File not found: $CLIP" && exit 1
  OUTPUT="${OUTPUT:-${CLIP%.*}_clip.${CLIP##*.}}"
  echo "✂️  Extracting clip from $CLIP"
  echo "⏱️  Start: $CLIP_START | End: ${CLIP_END:-end of file}"

  CLIP_ARGS=(-y -ss "$CLIP_START")
  [[ -n "$CLIP_END" ]] && CLIP_ARGS+=(-to "$CLIP_END")
  CLIP_ARGS+=(-i "$CLIP" -c copy "$OUTPUT")

  ffmpeg "${CLIP_ARGS[@]}" 2>/dev/null
  SIZE=$(du -h "$OUTPUT" | cut -f1)
  echo "✅ Saved to $OUTPUT ($SIZE)"
  exit 0
fi

# ============================================
# SCREEN RECORDING
# ============================================

# Set default output
OUTPUT="${OUTPUT:-${OUTPUT_DIR}/recording_${TIMESTAMP}.${FORMAT}}"

# Detect screen size
get_screen_size() {
  if [[ "$OS" == "Darwin" ]]; then
    # macOS
    system_profiler SPDisplaysDataType 2>/dev/null | grep Resolution | head -1 | awk '{print $2"x"$4}'
  else
    # Linux X11
    if command -v xdpyinfo &>/dev/null; then
      xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}'
    elif command -v xrandr &>/dev/null; then
      xrandr 2>/dev/null | grep '\*' | head -1 | awk '{print $1}'
    else
      echo "1920x1080"
    fi
  fi
}

# Get window geometry (Linux)
get_window_geometry() {
  if ! command -v xdotool &>/dev/null; then
    echo "❌ xdotool required for --pick-window. Install: sudo apt-get install xdotool"
    exit 1
  fi
  echo "🖱️  Click on the window you want to record..."
  WINDOW_ID=$(xdotool selectwindow 2>/dev/null)
  eval "$(xdotool getwindowgeometry --shell "$WINDOW_ID" 2>/dev/null)"
  echo "${WIDTH}x${HEIGHT}+${X}+${Y}"
}

# Build ffmpeg command
FFMPEG_ARGS=(-y)

# Duration
[[ -n "$DURATION" ]] && FFMPEG_ARGS+=(-t "$DURATION")

if [[ "$OS" == "Darwin" ]]; then
  # macOS — AVFoundation
  SCREEN_INPUT="1"  # Default screen device index
  FFMPEG_ARGS+=(-f avfoundation)
  
  if [[ -n "$AUDIO" ]]; then
    FFMPEG_ARGS+=(-i "${SCREEN_INPUT}:0")  # screen:audio
  else
    FFMPEG_ARGS+=(-i "${SCREEN_INPUT}:none")
  fi
  FFMPEG_ARGS+=(-r "$FPS")
else
  # Linux — X11
  SCREEN_SIZE=$(get_screen_size)
  
  if [[ "$PICK_WINDOW" == true ]]; then
    REGION=$(get_window_geometry)
  fi
  
  if [[ -n "$REGION" ]]; then
    # Parse WxH+X+Y
    REC_SIZE=$(echo "$REGION" | grep -oP '^\d+x\d+')
    REC_OFFSET=$(echo "$REGION" | grep -oP '\+\d+\+\d+' | tr '+' ',')
    REC_OFFSET="${REC_OFFSET#,}"  # Remove leading comma
    FFMPEG_ARGS+=(-f x11grab -framerate "$FPS" -video_size "$REC_SIZE" -i "${DISPLAY:-:0}.0+${REC_OFFSET}")
  else
    FFMPEG_ARGS+=(-f x11grab -framerate "$FPS" -video_size "$SCREEN_SIZE" -i "${DISPLAY:-:0}.0+0,0")
  fi
  
  # Cursor
  if [[ "$NO_CURSOR" == true ]]; then
    FFMPEG_ARGS+=(-draw_mouse 0)
  fi
  
  # Audio input
  if [[ -n "$AUDIO" ]]; then
    FFMPEG_ARGS+=(-f pulse -i "$AUDIO")
  fi
  
  # Microphone
  if [[ -n "$MIC" ]]; then
    FFMPEG_ARGS+=(-f pulse -i "$MIC")
  fi
fi

# Video encoding
case "$FORMAT" in
  mp4)
    FFMPEG_ARGS+=(-c:v libx264 -crf "$CRF" -preset ultrafast -pix_fmt yuv420p)
    [[ -n "$AUDIO" || -n "$MIC" ]] && FFMPEG_ARGS+=(-c:a aac -b:a 128k)
    ;;
  webm)
    FFMPEG_ARGS+=(-c:v libvpx-vp9 -crf "$CRF" -b:v 0 -pix_fmt yuv420p)
    [[ -n "$AUDIO" || -n "$MIC" ]] && FFMPEG_ARGS+=(-c:a libopus -b:a 128k)
    ;;
  mkv)
    FFMPEG_ARGS+=(-c:v libx264 -crf "$CRF" -preset ultrafast)
    [[ -n "$AUDIO" || -n "$MIC" ]] && FFMPEG_ARGS+=(-c:a aac -b:a 128k)
    ;;
  avi)
    FFMPEG_ARGS+=(-c:v mpeg4 -q:v 5)
    [[ -n "$AUDIO" || -n "$MIC" ]] && FFMPEG_ARGS+=(-c:a mp3 -b:a 128k)
    ;;
esac

# Webcam overlay
if [[ -n "$WEBCAM" ]]; then
  FFMPEG_ARGS+=(-f v4l2 -video_size "$WEBCAM_SIZE" -i "$WEBCAM")
  
  # Calculate overlay position
  case "$WEBCAM_POS" in
    top-left)     OVERLAY="overlay=10:10" ;;
    top-right)    OVERLAY="overlay=main_w-overlay_w-10:10" ;;
    bottom-left)  OVERLAY="overlay=10:main_h-overlay_h-10" ;;
    bottom-right) OVERLAY="overlay=main_w-overlay_w-10:main_h-overlay_h-10" ;;
    *) OVERLAY="overlay=main_w-overlay_w-10:main_h-overlay_h-10" ;;
  esac
  
  FFMPEG_ARGS+=(-filter_complex "$OVERLAY")
fi

FFMPEG_ARGS+=("$OUTPUT")

# Print info
if [[ -n "$REGION" ]]; then
  echo "🎬 Recording started (region: $REGION)"
else
  echo "🎬 Recording started (full screen, $(get_screen_size))"
fi

DURATION_INFO="${DURATION:-∞}s"
echo "⏱️  Duration: $DURATION_INFO | FPS: $FPS | Format: $FORMAT"
[[ -n "$AUDIO" ]] && echo "🔊 Audio: $AUDIO"
[[ -n "$WEBCAM" ]] && echo "📷 Webcam: $WEBCAM ($WEBCAM_POS)"
echo "📁 Output: $OUTPUT"
[[ -z "$DURATION" ]] && echo "⏹️  Press Ctrl+C to stop recording"
echo ""

# Record
ffmpeg "${FFMPEG_ARGS[@]}" 2>/dev/null

# Report
if [[ -f "$OUTPUT" ]]; then
  SIZE=$(du -h "$OUTPUT" | cut -f1)
  echo ""
  echo "✅ Saved to $OUTPUT ($SIZE)"
else
  echo ""
  echo "❌ Recording failed. Run with ffmpeg directly to debug."
  exit 1
fi
