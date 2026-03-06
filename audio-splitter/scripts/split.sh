#!/bin/bash
# Audio Splitter — Main Script
# Split audio by silence, time, chapters, or timestamps
set -e

# Defaults
MODE="silence"
INPUT=""
INPUT_DIR=""
OUTPUT_DIR="./output"
FORMAT="${AUDIO_SPLITTER_FORMAT:-mp3}"
BITRATE="${AUDIO_SPLITTER_BITRATE:-192k}"
SILENCE_THRESH="${AUDIO_SPLITTER_SILENCE_THRESH:--35}"
MIN_SILENCE="${AUDIO_SPLITTER_MIN_SILENCE:-1.0}"
MIN_SEGMENT="${AUDIO_SPLITTER_MIN_SEGMENT:-30}"
INTERVAL=""
TIMESTAMPS=""
PREFIX=""
DRY_RUN=false
FADE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT="$2"; shift 2 ;;
    --input-dir) INPUT_DIR="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --bitrate) BITRATE="$2"; shift 2 ;;
    --silence-thresh) SILENCE_THRESH="$2"; shift 2 ;;
    --min-silence) MIN_SILENCE="$2"; shift 2 ;;
    --min-segment) MIN_SEGMENT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --timestamps) TIMESTAMPS="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --fade) FADE="$2"; shift 2 ;;
    -h|--help) 
      echo "Usage: bash split.sh --input <file> --mode <silence|time|chapters|timestamps>"
      echo ""
      echo "Modes:"
      echo "  silence     Split at silence points (default)"
      echo "  time        Split at fixed intervals (--interval seconds)"
      echo "  chapters    Split by embedded chapter markers"
      echo "  timestamps  Split at specific times (--timestamps '0:00,5:30,...')"
      echo ""
      echo "Options:"
      echo "  --input <file>          Input audio file"
      echo "  --input-dir <dir>       Process all audio in directory"
      echo "  --output-dir <dir>      Output directory (default: ./output)"
      echo "  --format <fmt>          Output format: mp3,wav,flac,ogg,m4a (default: mp3)"
      echo "  --bitrate <rate>        MP3 bitrate (default: 192k)"
      echo "  --silence-thresh <dB>   Silence threshold (default: -35)"
      echo "  --min-silence <sec>     Minimum silence duration (default: 1.0)"
      echo "  --min-segment <sec>     Minimum segment length (default: 30)"
      echo "  --interval <sec>        Time interval for 'time' mode"
      echo "  --timestamps <list>     Comma-separated timestamps for 'timestamps' mode"
      echo "  --prefix <name>         Output file prefix"
      echo "  --fade <sec>            Fade in/out duration"
      echo "  --dry-run               Preview splits without writing files"
      exit 0
      ;;
    *) echo "[audio-splitter] ❌ Unknown option: $1"; exit 1 ;;
  esac
done

# Validate dependencies
for cmd in ffmpeg; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[audio-splitter] ❌ $cmd not found. Run: bash scripts/install.sh"
    exit 1
  fi
done

# Convert timestamp (MM:SS or HH:MM:SS) to seconds
ts_to_seconds() {
  local ts="$1"
  local parts
  IFS=':' read -ra parts <<< "$ts"
  if [ ${#parts[@]} -eq 3 ]; then
    echo "$(echo "${parts[0]}*3600 + ${parts[1]}*60 + ${parts[2]}" | bc)"
  elif [ ${#parts[@]} -eq 2 ]; then
    echo "$(echo "${parts[0]}*60 + ${parts[1]}" | bc)"
  else
    echo "$ts"
  fi
}

# Format seconds to HH:MM:SS.mmm
seconds_to_ts() {
  local s="$1"
  local h=$(echo "$s / 3600" | bc)
  local m=$(echo "($s % 3600) / 60" | bc)
  local sec=$(echo "$s % 60" | bc)
  printf "%02d:%02d:%06.3f" "$h" "$m" "$sec"
}

# Get audio duration
get_duration() {
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null
}

# Build ffmpeg output options
get_output_opts() {
  local fmt="$1"
  case "$fmt" in
    mp3)  echo "-codec:a libmp3lame -b:a $BITRATE" ;;
    wav)  echo "-codec:a pcm_s16le" ;;
    flac) echo "-codec:a flac" ;;
    ogg)  echo "-codec:a libvorbis -b:a $BITRATE" ;;
    m4a)  echo "-codec:a aac -b:a $BITRATE" ;;
    *)    echo "-codec:a libmp3lame -b:a $BITRATE" ;;
  esac
}

# Apply fade if requested
get_fade_filter() {
  local duration="$1"
  if [ -n "$FADE" ]; then
    local fadeout_start=$(echo "$duration - $FADE" | bc)
    echo "-af afade=t=in:st=0:d=$FADE,afade=t=out:st=$fadeout_start:d=$FADE"
  fi
}

# Split a single segment from input
split_segment() {
  local input="$1"
  local start="$2"
  local end="$3"
  local outfile="$4"
  local duration=""

  if [ "$end" != "end" ]; then
    duration=$(echo "$end - $start" | bc)
  fi

  local opts=$(get_output_opts "$FORMAT")
  local fade_filter=""
  if [ -n "$FADE" ] && [ -n "$duration" ]; then
    fade_filter=$(get_fade_filter "$duration")
  fi

  if [ "$end" = "end" ]; then
    eval ffmpeg -y -v error -i "\"$input\"" -ss "$start" $opts $fade_filter "\"$outfile\""
  else
    eval ffmpeg -y -v error -i "\"$input\"" -ss "$start" -t "$duration" $opts $fade_filter "\"$outfile\""
  fi
}

# ── SILENCE MODE ──
split_by_silence() {
  local input="$1"
  local basename=$(basename "$input" | sed 's/\.[^.]*$//')
  local prefix_name="${PREFIX:-$basename}"

  echo "[audio-splitter] Analyzing silence in $(basename "$input")..."

  if ! command -v sox &>/dev/null; then
    echo "[audio-splitter] ❌ sox not found (required for silence detection). Run: bash scripts/install.sh"
    exit 1
  fi

  # Detect silence using sox
  local silence_data
  silence_data=$(sox "$input" -n silence -l 1 0.0 "${SILENCE_THRESH}d" 1 "${MIN_SILENCE}" "${SILENCE_THRESH}d" : newfile : restart 2>&1 || true)

  # Alternative: use ffmpeg silencedetect
  local silence_points=()
  local raw
  raw=$(ffmpeg -i "$input" -af "silencedetect=noise=${SILENCE_THRESH}dB:d=${MIN_SILENCE}" -f null - 2>&1 | \
    grep "silence_end" | \
    sed 's/.*silence_end: \([0-9.]*\).*/\1/')

  while IFS= read -r line; do
    [ -n "$line" ] && silence_points+=("$line")
  done <<< "$raw"

  echo "[audio-splitter] Found ${#silence_points[@]} silence points"

  if [ ${#silence_points[@]} -eq 0 ]; then
    echo "[audio-splitter] No silence detected. Try lowering --silence-thresh (e.g., -50)"
    return 1
  fi

  if $DRY_RUN; then
    echo "[audio-splitter] Silence points detected:"
    local i=1
    for sp in "${silence_points[@]}"; do
      echo "  $i. $(seconds_to_ts "$sp")"
      ((i++))
    done
    echo "Would split into $((${#silence_points[@]} + 1)) segments. Use without --dry-run to execute."
    return 0
  fi

  mkdir -p "$OUTPUT_DIR"

  # Build split points, filtering by min segment
  local split_times=(0)
  local last=0
  for sp in "${silence_points[@]}"; do
    local gap=$(echo "$sp - $last" | bc)
    local cmp=$(echo "$gap >= $MIN_SEGMENT" | bc)
    if [ "$cmp" -eq 1 ]; then
      split_times+=("$sp")
      last="$sp"
    fi
  done

  local total_duration=$(get_duration "$input")
  local count=${#split_times[@]}
  local i=0

  for ((i=0; i<count; i++)); do
    local start="${split_times[$i]}"
    local end
    if [ $((i+1)) -lt $count ]; then
      end="${split_times[$((i+1))]}"
    else
      end="end"
    fi

    local seg_num=$(printf "%03d" $((i+1)))
    local outfile="$OUTPUT_DIR/${prefix_name}_${seg_num}.${FORMAT}"

    split_segment "$input" "$start" "$end" "$outfile"

    local seg_dur
    if [ "$end" = "end" ]; then
      seg_dur=$(echo "$total_duration - $start" | bc)
    else
      seg_dur=$(echo "$end - $start" | bc)
    fi
    local minutes=$(echo "$seg_dur / 60" | bc)
    local secs=$(echo "$seg_dur % 60" | bc | xargs printf "%02.0f")
    echo "[audio-splitter] ✅ $(basename "$outfile") (${minutes}:${secs})"
  done

  echo "[audio-splitter] Done! $count segments created in $OUTPUT_DIR/"
}

# ── TIME MODE ──
split_by_time() {
  local input="$1"
  local basename=$(basename "$input" | sed 's/\.[^.]*$//')
  local prefix_name="${PREFIX:-$basename}"

  if [ -z "$INTERVAL" ]; then
    echo "[audio-splitter] ❌ --interval required for time mode"
    exit 1
  fi

  local total_duration=$(get_duration "$input")
  local num_segments=$(echo "($total_duration + $INTERVAL - 1) / $INTERVAL" | bc)

  echo "[audio-splitter] Splitting $(basename "$input") into ~${INTERVAL}s segments..."

  if $DRY_RUN; then
    echo "[audio-splitter] Would create $num_segments segments of ${INTERVAL}s each"
    return 0
  fi

  mkdir -p "$OUTPUT_DIR"

  local start=0
  local seg=1

  while (( $(echo "$start < $total_duration" | bc -l) )); do
    local seg_num=$(printf "%03d" $seg)
    local outfile="$OUTPUT_DIR/${prefix_name}_${seg_num}.${FORMAT}"
    local remaining=$(echo "$total_duration - $start" | bc)
    local dur=$INTERVAL

    if (( $(echo "$remaining < $INTERVAL" | bc -l) )); then
      dur=$remaining
    fi

    local opts=$(get_output_opts "$FORMAT")
    eval ffmpeg -y -v error -i "\"$input\"" -ss "$start" -t "$dur" $opts "\"$outfile\""

    local minutes=$(echo "$dur / 60" | bc)
    local secs=$(echo "$dur % 60" | bc | xargs printf "%02.0f")
    echo "[audio-splitter] ✅ $(basename "$outfile") (${minutes}:${secs})"

    start=$(echo "$start + $INTERVAL" | bc)
    ((seg++))
  done

  echo "[audio-splitter] Done! $((seg-1)) segments created in $OUTPUT_DIR/"
}

# ── CHAPTERS MODE ──
split_by_chapters() {
  local input="$1"
  local basename=$(basename "$input" | sed 's/\.[^.]*$//')
  local prefix_name="${PREFIX:-$basename}"

  echo "[audio-splitter] Extracting chapters from $(basename "$input")..."

  # Get chapter info from ffprobe
  local chapters_json
  chapters_json=$(ffprobe -v error -print_format json -show_chapters "$input" 2>/dev/null)

  local num_chapters
  num_chapters=$(echo "$chapters_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
chapters = data.get('chapters', [])
print(len(chapters))
" 2>/dev/null || echo "0")

  if [ "$num_chapters" = "0" ]; then
    echo "[audio-splitter] ❌ No chapters found in file. Use 'silence' or 'time' mode instead."
    return 1
  fi

  echo "[audio-splitter] Found $num_chapters chapters"

  if $DRY_RUN; then
    echo "$chapters_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for i, ch in enumerate(data.get('chapters', []), 1):
    title = ch.get('tags', {}).get('title', f'Chapter {i}')
    start = float(ch['start_time'])
    end = float(ch['end_time'])
    dur = end - start
    m, s = divmod(int(dur), 60)
    print(f'  {i}. {title} ({m}:{s:02d})')
"
    return 0
  fi

  mkdir -p "$OUTPUT_DIR"

  echo "$chapters_json" | python3 -c "
import sys, json, subprocess, os

data = json.load(sys.stdin)
fmt = '$FORMAT'
bitrate = '$BITRATE'
output_dir = '$OUTPUT_DIR'
prefix = '$prefix_name'

codec_map = {
    'mp3': ['-codec:a', 'libmp3lame', '-b:a', bitrate],
    'wav': ['-codec:a', 'pcm_s16le'],
    'flac': ['-codec:a', 'flac'],
    'ogg': ['-codec:a', 'libvorbis', '-b:a', bitrate],
    'm4a': ['-codec:a', 'aac', '-b:a', bitrate],
}
codec = codec_map.get(fmt, codec_map['mp3'])

for i, ch in enumerate(data.get('chapters', []), 1):
    title = ch.get('tags', {}).get('title', f'chapter_{i:03d}')
    safe_title = ''.join(c if c.isalnum() or c in ' -_' else '_' for c in title).strip()
    start = ch['start_time']
    end = ch['end_time']
    dur = float(end) - float(start)
    outfile = os.path.join(output_dir, f'{prefix}_{i:03d}_{safe_title}.{fmt}')

    cmd = ['ffmpeg', '-y', '-v', 'error', '-i', '$input', '-ss', start, '-t', str(dur)] + codec + [outfile]
    subprocess.run(cmd, check=True)

    m, s = divmod(int(dur), 60)
    print(f'[audio-splitter] ✅ {os.path.basename(outfile)} ({m}:{s:02d})')

print(f'[audio-splitter] Done! {len(data[\"chapters\"])} chapters extracted to {output_dir}/')
"
}

# ── TIMESTAMPS MODE ──
split_by_timestamps() {
  local input="$1"
  local basename=$(basename "$input" | sed 's/\.[^.]*$//')
  local prefix_name="${PREFIX:-$basename}"

  if [ -z "$TIMESTAMPS" ]; then
    echo "[audio-splitter] ❌ --timestamps required (comma-separated, e.g., '0:00,5:30,12:45')"
    exit 1
  fi

  IFS=',' read -ra ts_list <<< "$TIMESTAMPS"
  local seconds_list=()
  for ts in "${ts_list[@]}"; do
    seconds_list+=("$(ts_to_seconds "$(echo "$ts" | xargs)")")
  done

  local total_duration=$(get_duration "$input")
  local count=${#seconds_list[@]}

  echo "[audio-splitter] Splitting $(basename "$input") at $count timestamp(s)..."

  if $DRY_RUN; then
    for ((i=0; i<count; i++)); do
      local start="${seconds_list[$i]}"
      local end
      if [ $((i+1)) -lt $count ]; then
        end="${seconds_list[$((i+1))]}"
      else
        end="$total_duration"
      fi
      local dur=$(echo "$end - $start" | bc)
      local m=$(echo "$dur / 60" | bc)
      local s=$(echo "$dur % 60" | bc | xargs printf "%02.0f")
      echo "  $((i+1)). $(seconds_to_ts "$start") → $(seconds_to_ts "$end") (${m}:${s})"
    done
    return 0
  fi

  mkdir -p "$OUTPUT_DIR"

  for ((i=0; i<count; i++)); do
    local start="${seconds_list[$i]}"
    local end
    if [ $((i+1)) -lt $count ]; then
      end="${seconds_list[$((i+1))]}"
    else
      end="end"
    fi

    local seg_num=$(printf "%03d" $((i+1)))
    local outfile="$OUTPUT_DIR/${prefix_name}_${seg_num}.${FORMAT}"

    split_segment "$input" "$start" "$end" "$outfile"

    local seg_dur
    if [ "$end" = "end" ]; then
      seg_dur=$(echo "$total_duration - $start" | bc)
    else
      seg_dur=$(echo "$end - $start" | bc)
    fi
    local m=$(echo "$seg_dur / 60" | bc)
    local s=$(echo "$seg_dur % 60" | bc | xargs printf "%02.0f")
    echo "[audio-splitter] ✅ $(basename "$outfile") (${m}:${s})"
  done

  echo "[audio-splitter] Done! $count segments created in $OUTPUT_DIR/"
}

# ── MAIN ──

# Handle batch mode
if [ -n "$INPUT_DIR" ]; then
  echo "[audio-splitter] Batch processing files in $INPUT_DIR..."
  find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.m4a" -o -iname "*.m4b" -o -iname "*.aac" -o -iname "*.opus" \) | sort | while read -r file; do
    echo ""
    echo "[audio-splitter] ── Processing: $(basename "$file") ──"
    INPUT="$file"
    case "$MODE" in
      silence)    split_by_silence "$file" ;;
      time)       split_by_time "$file" ;;
      chapters)   split_by_chapters "$file" ;;
      timestamps) split_by_timestamps "$file" ;;
    esac
  done
  exit 0
fi

# Single file mode
if [ -z "$INPUT" ]; then
  echo "[audio-splitter] ❌ No input specified. Use --input <file> or --input-dir <dir>"
  echo "Run with --help for usage."
  exit 1
fi

if [ ! -f "$INPUT" ]; then
  echo "[audio-splitter] ❌ File not found: $INPUT"
  exit 1
fi

case "$MODE" in
  silence)    split_by_silence "$INPUT" ;;
  time)       split_by_time "$INPUT" ;;
  chapters)   split_by_chapters "$INPUT" ;;
  timestamps) split_by_timestamps "$INPUT" ;;
  *)
    echo "[audio-splitter] ❌ Unknown mode: $MODE"
    echo "Valid modes: silence, time, chapters, timestamps"
    exit 1
    ;;
esac
