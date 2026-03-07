#!/bin/bash
# FFmpeg Toolkit — Main Runner
# Usage: bash run.sh <command> [options]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${FFMPEG_OUTPUT_DIR:-.}"
QUALITY="${FFMPEG_QUALITY:-medium}"
HWACCEL="${FFMPEG_HWACCEL:-auto}"
THREADS="${FFMPEG_THREADS:-0}"

# Quality presets (CRF values for libx264)
declare -A CRF_MAP=([high]=23 [medium]=28 [low]=32)

# ─── Helpers ───

die() { echo "❌ $*" >&2; exit 1; }
require() { command -v "$1" &>/dev/null || die "$1 not found. Run: bash scripts/install.sh"; }
check_deps() { require ffmpeg; require ffprobe; }

get_extension() { echo "${1##*.}" | tr '[:upper:]' '[:lower:]'; }

output_path() {
  local input="$1" suffix="$2" ext="$3"
  local base=$(basename "$input")
  local name="${base%.*}"
  [ -z "$ext" ] && ext=$(get_extension "$input")
  echo "${OUTPUT_DIR}/${name}${suffix}.${ext}"
}

detect_hwaccel() {
  if [ "$HWACCEL" = "auto" ]; then
    if ffmpeg -hwaccels 2>/dev/null | grep -q nvenc; then echo "nvenc"
    elif ffmpeg -hwaccels 2>/dev/null | grep -q vaapi; then echo "vaapi"
    elif ffmpeg -hwaccels 2>/dev/null | grep -q videotoolbox; then echo "videotoolbox"
    elif ffmpeg -hwaccels 2>/dev/null | grep -q qsv; then echo "qsv"
    else echo "none"
    fi
  else
    echo "$HWACCEL"
  fi
}

get_encoder() {
  local accel=$(detect_hwaccel)
  case "$accel" in
    nvenc) echo "h264_nvenc" ;;
    vaapi) echo "h264_vaapi" ;;
    videotoolbox) echo "h264_videotoolbox" ;;
    qsv) echo "h264_qsv" ;;
    *) echo "libx264" ;;
  esac
}

# ─── Commands ───

cmd_convert() {
  local input="" output="" copy=false bitrate=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --copy) copy=true; shift ;;
      --bitrate) bitrate="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh convert --input FILE --output FILE"
  [ -z "$output" ] && output=$(output_path "$input" "_converted" "mp4")

  if $copy; then
    ffmpeg -y -i "$input" -c copy -threads "$THREADS" "$output"
  elif [ -n "$bitrate" ]; then
    ffmpeg -y -i "$input" -b:a "$bitrate" -threads "$THREADS" "$output"
  else
    ffmpeg -y -i "$input" -threads "$THREADS" "$output"
  fi
  echo "✅ Converted: $output ($(du -h "$output" | cut -f1))"
}

cmd_compress() {
  local input="" quality="$QUALITY" target_size="" hwaccel_flag="" codec=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --quality) quality="$2"; shift 2 ;;
      --target-size) target_size="$2"; shift 2 ;;
      --hwaccel) hwaccel_flag="$2"; shift 2 ;;
      --codec) codec="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh compress --input FILE [--quality high|medium|low]"

  local output=$(output_path "$input" "_compressed")
  local crf=${CRF_MAP[$quality]:-28}
  local encoder

  if [ -n "$hwaccel_flag" ]; then
    HWACCEL="$hwaccel_flag"
  fi
  encoder=$(get_encoder)

  if [ -n "$target_size" ]; then
    # Calculate bitrate from target size
    local duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$input" | cut -d. -f1)
    local size_bytes
    case "$target_size" in
      *M|*m) size_bytes=$(echo "${target_size%[Mm]} * 1048576" | bc | cut -d. -f1) ;;
      *G|*g) size_bytes=$(echo "${target_size%[Gg]} * 1073741824" | bc | cut -d. -f1) ;;
      *) size_bytes=$target_size ;;
    esac
    local bitrate=$(( (size_bytes * 8) / duration ))
    ffmpeg -y -i "$input" -c:v "$encoder" -b:v "${bitrate}" -c:a aac -b:a 128k -threads "$THREADS" "$output"
  elif [ "$codec" = "h265" ] || [ "$codec" = "hevc" ]; then
    ffmpeg -y -i "$input" -c:v libx265 -crf "$crf" -preset medium -c:a aac -b:a 128k -threads "$THREADS" "$output"
  else
    ffmpeg -y -i "$input" -c:v "$encoder" -crf "$crf" -preset medium -c:a aac -b:a 128k -threads "$THREADS" "$output"
  fi

  local orig_size=$(du -h "$input" | cut -f1)
  local new_size=$(du -h "$output" | cut -f1)
  echo "✅ Compressed: $output ($orig_size → $new_size)"
}

cmd_trim() {
  local input="" start="" end="" duration="" last=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --start) start="$2"; shift 2 ;;
      --end) end="$2"; shift 2 ;;
      --duration) duration="$2"; shift 2 ;;
      --last) last="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh trim --input FILE --start TIME [--end TIME | --duration SECS]"

  local output=$(output_path "$input" "_trimmed")
  local args=(-y -i "$input")

  if [ -n "$last" ]; then
    local total=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$input")
    start=$(echo "$total - $last" | bc)
    args+=(-ss "$start")
  elif [ -n "$start" ]; then
    args+=(-ss "$start")
  fi

  [ -n "$end" ] && args+=(-to "$end")
  [ -n "$duration" ] && args+=(-t "$duration")

  args+=(-c copy -threads "$THREADS" "$output")
  ffmpeg "${args[@]}"
  echo "✅ Trimmed: $output ($(du -h "$output" | cut -f1))"
}

cmd_split() {
  local input="" segment=300
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --segment) segment="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh split --input FILE --segment SECONDS"

  local base=$(basename "$input")
  local name="${base%.*}"
  local ext=$(get_extension "$input")
  ffmpeg -y -i "$input" -c copy -f segment -segment_time "$segment" \
    -reset_timestamps 1 "${OUTPUT_DIR}/${name}_%03d.${ext}"
  echo "✅ Split into ${segment}s segments in $OUTPUT_DIR/"
}

cmd_extract_audio() {
  local input="" format="mp3" bitrate="192k"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      --bitrate) bitrate="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh extract-audio --input FILE [--format mp3|wav|aac]"

  local output=$(output_path "$input" "_audio" "$format")
  if [ "$format" = "wav" ]; then
    ffmpeg -y -i "$input" -vn -acodec pcm_s16le "$output"
  else
    ffmpeg -y -i "$input" -vn -b:a "$bitrate" "$output"
  fi
  echo "✅ Audio extracted: $output ($(du -h "$output" | cut -f1))"
}

cmd_screenshot() {
  local input="" time="0"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --time) time="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh screenshot --input FILE --time TIME"

  local output=$(output_path "$input" "_screenshot" "png")
  ffmpeg -y -ss "$time" -i "$input" -frames:v 1 -q:v 2 "$output"
  echo "✅ Screenshot: $output"
}

cmd_thumbnails() {
  local input="" interval=30 outdir="./thumbs"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --interval) interval="$2"; shift 2 ;;
      --outdir) outdir="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh thumbnails --input FILE --interval SECS"

  mkdir -p "$outdir"
  local base=$(basename "$input")
  local name="${base%.*}"
  ffmpeg -y -i "$input" -vf "fps=1/$interval" "${outdir}/${name}_%04d.png"
  local count=$(ls "$outdir"/${name}_*.png 2>/dev/null | wc -l)
  echo "✅ Generated $count thumbnails in $outdir/"
}

cmd_contact_sheet() {
  local input="" cols=4 rows=4
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --cols) cols="$2"; shift 2 ;;
      --rows) rows="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh contact-sheet --input FILE"

  local total=$((cols * rows))
  local duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$input" | cut -d. -f1)
  local interval=$((duration / total))
  local output=$(output_path "$input" "_contact_sheet" "png")

  ffmpeg -y -i "$input" \
    -vf "fps=1/$interval,scale=320:-1,tile=${cols}x${rows}" \
    -frames:v 1 "$output"
  echo "✅ Contact sheet: $output"
}

cmd_merge() {
  local inputs="" output="merged.mp4" reencode=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --inputs) inputs="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --reencode) reencode=true; shift ;;
      *) shift ;;
    esac
  done
  [ -z "$inputs" ] && die "Usage: run.sh merge --inputs 'file1 file2 ...' --output FILE"

  local listfile=$(mktemp)
  for f in $inputs; do
    echo "file '$(realpath "$f")'" >> "$listfile"
  done

  if $reencode; then
    ffmpeg -y -f concat -safe 0 -i "$listfile" -c:v libx264 -crf 23 -c:a aac "$output"
  else
    ffmpeg -y -f concat -safe 0 -i "$listfile" -c copy "$output"
  fi
  rm "$listfile"
  echo "✅ Merged: $output ($(du -h "$output" | cut -f1))"
}

cmd_mux() {
  local video="" audio="" output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --video) video="$2"; shift 2 ;;
      --audio) audio="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$video" ] || [ -z "$audio" ] && die "Usage: run.sh mux --video FILE --audio FILE --output FILE"
  [ -z "$output" ] && output=$(output_path "$video" "_muxed")

  ffmpeg -y -i "$video" -i "$audio" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 "$output"
  echo "✅ Muxed: $output"
}

cmd_replace_audio() {
  local video="" audio=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --video) video="$2"; shift 2 ;;
      --audio) audio="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$video" ] || [ -z "$audio" ] && die "Usage: run.sh replace-audio --video FILE --audio FILE"
  local output=$(output_path "$video" "_newaudio")
  ffmpeg -y -i "$video" -i "$audio" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest "$output"
  echo "✅ Audio replaced: $output"
}

cmd_resize() {
  local input="" width="" height="" force=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --width) width="$2"; shift 2 ;;
      --height) height="$2"; shift 2 ;;
      --force) force=true; shift ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh resize --input FILE [--width W] [--height H]"

  local output=$(output_path "$input" "_resized")
  local scale
  if $force && [ -n "$width" ] && [ -n "$height" ]; then
    scale="scale=${width}:${height}"
  elif [ -n "$width" ]; then
    scale="scale=${width}:-2"
  elif [ -n "$height" ]; then
    scale="scale=-2:${height}"
  else
    die "Specify --width and/or --height"
  fi

  ffmpeg -y -i "$input" -vf "$scale" -c:v libx264 -crf 23 -c:a copy "$output"
  echo "✅ Resized: $output"
}

cmd_gif() {
  local input="" start="0" duration="5" quality="medium" width="480"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --start) start="$2"; shift 2 ;;
      --duration) duration="$2"; shift 2 ;;
      --quality) quality="$2"; shift 2 ;;
      --width) width="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh gif --input FILE [--start TIME --duration SECS]"

  local output=$(output_path "$input" "" "gif")
  local fps=15
  [ "$quality" = "high" ] && fps=24

  # Two-pass for better quality
  local palette=$(mktemp /tmp/palette_XXXX.png)
  ffmpeg -y -ss "$start" -t "$duration" -i "$input" \
    -vf "fps=$fps,scale=$width:-1:flags=lanczos,palettegen" "$palette"
  ffmpeg -y -ss "$start" -t "$duration" -i "$input" -i "$palette" \
    -lavfi "fps=$fps,scale=$width:-1:flags=lanczos[x];[x][1:v]paletteuse" "$output"
  rm -f "$palette"
  echo "✅ GIF created: $output ($(du -h "$output" | cut -f1))"
}

cmd_watermark() {
  local input="" text="" image="" position="br" opacity="0.5"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --text) text="$2"; shift 2 ;;
      --image) image="$2"; shift 2 ;;
      --position) position="$2"; shift 2 ;;
      --opacity) opacity="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh watermark --input FILE [--text TEXT | --image FILE]"

  local output=$(output_path "$input" "_watermarked")

  # Position mapping
  local x y
  case "$position" in
    tl) x="10"; y="10" ;;
    tr) x="W-w-10"; y="10" ;;
    bl) x="10"; y="H-h-10" ;;
    br) x="W-w-10"; y="H-h-10" ;;
    center) x="(W-w)/2"; y="(H-h)/2" ;;
    *) x="W-w-10"; y="H-h-10" ;;
  esac

  if [ -n "$text" ]; then
    ffmpeg -y -i "$input" \
      -vf "drawtext=text='$text':fontsize=24:fontcolor=white@0.8:x=$x:y=$y:shadowcolor=black@0.5:shadowx=2:shadowy=2" \
      -c:a copy "$output"
  elif [ -n "$image" ]; then
    ffmpeg -y -i "$input" -i "$image" \
      -filter_complex "[1:v]format=rgba,colorchannelmixer=aa=$opacity[wm];[0:v][wm]overlay=$x:$y" \
      -c:a copy "$output"
  else
    die "Specify --text or --image"
  fi
  echo "✅ Watermarked: $output"
}

cmd_info() {
  local input="" full=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --full) full=true; shift ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh info --input FILE"

  if $full; then
    ffprobe -v quiet -print_format json -show_format -show_streams "$input" | python3 -m json.tool 2>/dev/null || ffprobe -v quiet -print_format json -show_format -show_streams "$input"
  else
    local dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null | cut -d. -f1)
    local size=$(du -h "$input" | cut -f1)
    local res=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$input" 2>/dev/null)
    local codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$input" 2>/dev/null)
    local fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$input" 2>/dev/null)
    local bitrate=$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 "$input" 2>/dev/null)

    local dur_fmt=""
    if [ -n "$dur" ] && [ "$dur" -gt 0 ] 2>/dev/null; then
      dur_fmt=$(printf "%02d:%02d:%02d" $((dur/3600)) $((dur%3600/60)) $((dur%60)))
    else
      dur_fmt="N/A"
    fi

    local br_fmt="N/A"
    if [ -n "$bitrate" ] && [ "$bitrate" -gt 0 ] 2>/dev/null; then
      br_fmt=$(echo "scale=1; $bitrate / 1000000" | bc 2>/dev/null || echo "$bitrate")Mbps
    fi

    echo "📹 $(basename "$input") | ${res:-N/A} | ${codec:-N/A} | ${fps:-N/A}fps | ${br_fmt} | ${dur_fmt} | ${size}"
  fi
}

cmd_subtitles() {
  local input="" srt="" output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --srt) srt="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] || [ -z "$srt" ] && die "Usage: run.sh subtitles --input FILE --srt FILE"
  [ -z "$output" ] && output=$(output_path "$input" "_subbed")

  ffmpeg -y -i "$input" -vf "subtitles=$srt" -c:a copy "$output"
  echo "✅ Subtitles burned: $output"
}

cmd_extract_subs() {
  local input="" output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh extract-subs --input FILE"
  [ -z "$output" ] && output=$(output_path "$input" "_subs" "srt")

  ffmpeg -y -i "$input" -map 0:s:0 "$output"
  echo "✅ Subtitles extracted: $output"
}

cmd_raw() {
  local input="" output="" flags=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --flags) flags="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$input" ] && die "Usage: run.sh raw --input FILE --output FILE --flags 'ffmpeg flags'"
  ffmpeg -y -i "$input" $flags "$output"
  echo "✅ Done: $output"
}

# Batch commands
cmd_batch_convert() {
  local dir="" from="" to="mp4"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dir) dir="$2"; shift 2 ;;
      --from) from="$2"; shift 2 ;;
      --to) to="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$dir" ] || [ -z "$from" ] && die "Usage: run.sh batch-convert --dir DIR --from EXT --to EXT"

  local count=0
  for f in "$dir"/*."$from"; do
    [ -f "$f" ] || continue
    cmd_convert --input "$f" --output "${f%.*}.$to"
    ((count++))
  done
  echo "✅ Batch converted $count files"
}

cmd_batch_compress() {
  local dir="" quality="$QUALITY"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dir) dir="$2"; shift 2 ;;
      --quality) quality="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$dir" ] && die "Usage: run.sh batch-compress --dir DIR [--quality high|medium|low]"

  local count=0
  for f in "$dir"/*.{mp4,mkv,mov,avi,webm}; do
    [ -f "$f" ] || continue
    cmd_compress --input "$f" --quality "$quality"
    ((count++))
  done
  echo "✅ Batch compressed $count files"
}

cmd_batch_extract_audio() {
  local dir="" format="mp3"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dir) dir="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$dir" ] && die "Usage: run.sh batch-extract-audio --dir DIR [--format mp3|wav]"

  local count=0
  for f in "$dir"/*.{mp4,mkv,mov,avi,webm}; do
    [ -f "$f" ] || continue
    cmd_extract_audio --input "$f" --format "$format"
    ((count++))
  done
  echo "✅ Batch extracted audio from $count files"
}

cmd_batch_info() {
  local dir=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dir) dir="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$dir" ] && die "Usage: run.sh batch-info --dir DIR"

  for f in "$dir"/*.{mp4,mkv,mov,avi,webm,mp3,flac,wav}; do
    [ -f "$f" ] || continue
    cmd_info --input "$f"
  done
}

# ─── Main Dispatch ───

CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
  help|--help|-h) ;; # handled below without deps
  *) check_deps ;;
esac

case "$CMD" in
  convert)          cmd_convert "$@" ;;
  compress)         cmd_compress "$@" ;;
  trim)             cmd_trim "$@" ;;
  split)            cmd_split "$@" ;;
  extract-audio)    cmd_extract_audio "$@" ;;
  screenshot)       cmd_screenshot "$@" ;;
  thumbnails)       cmd_thumbnails "$@" ;;
  contact-sheet)    cmd_contact_sheet "$@" ;;
  merge)            cmd_merge "$@" ;;
  mux)              cmd_mux "$@" ;;
  replace-audio)    cmd_replace_audio "$@" ;;
  resize)           cmd_resize "$@" ;;
  gif)              cmd_gif "$@" ;;
  watermark)        cmd_watermark "$@" ;;
  info)             cmd_info "$@" ;;
  subtitles)        cmd_subtitles "$@" ;;
  extract-subs)     cmd_extract_subs "$@" ;;
  raw)              cmd_raw "$@" ;;
  batch-convert)    cmd_batch_convert "$@" ;;
  batch-compress)   cmd_batch_compress "$@" ;;
  batch-extract-audio) cmd_batch_extract_audio "$@" ;;
  batch-info)       cmd_batch_info "$@" ;;
  help|--help|-h)
    echo "🎬 FFmpeg Toolkit — Commands:"
    echo ""
    echo "  convert           Convert between formats"
    echo "  compress          Reduce file size"
    echo "  trim              Cut a clip from a video"
    echo "  split             Split into segments"
    echo "  extract-audio     Extract audio track"
    echo "  screenshot        Capture a frame"
    echo "  thumbnails        Generate thumbnail series"
    echo "  contact-sheet     Create screenshot grid"
    echo "  merge             Concatenate files"
    echo "  mux               Combine video + audio"
    echo "  replace-audio     Replace audio track"
    echo "  resize            Change resolution"
    echo "  gif               Create animated GIF"
    echo "  watermark         Add text/image overlay"
    echo "  info              Show media info"
    echo "  subtitles         Burn subtitles"
    echo "  extract-subs      Extract subtitle track"
    echo "  raw               Run custom ffmpeg command"
    echo "  batch-convert     Convert all files in directory"
    echo "  batch-compress    Compress all files in directory"
    echo "  batch-extract-audio  Extract audio from all files"
    echo "  batch-info        Show info for all files"
    echo ""
    echo "Run: bash run.sh <command> --help for details"
    ;;
  *)
    die "Unknown command: $CMD. Run: bash run.sh help"
    ;;
esac
