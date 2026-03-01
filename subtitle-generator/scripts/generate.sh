#!/bin/bash
# Subtitle Generator — Generate SRT/VTT subtitles from video/audio using Whisper
# Usage: bash generate.sh --input <file> [options]

set -euo pipefail

# Defaults
INPUT=""
INPUT_DIR=""
OUTPUT=""
FORMAT="${WHISPER_FORMAT:-srt}"
MODEL="${WHISPER_MODEL:-base}"
LANGUAGE=""
TASK="transcribe"
AUDIO_ONLY=false
OUTPUT_DIR="${WHISPER_OUTPUT_DIR:-}"

PREFIX="[subtitle-gen]"

usage() {
  cat <<EOF
Usage: bash generate.sh [OPTIONS]

Options:
  --input <file>       Input video/audio file
  --input-dir <dir>    Process all media files in directory
  --output <file>      Custom output path (single file mode)
  --format <srt|vtt>   Output format (default: srt)
  --model <name>       Whisper model: tiny|base|small|medium|large-v3 (default: base)
  --language <code>    Language code (e.g., en, es, fr). Auto-detect if omitted.
  --task <transcribe|translate>  transcribe (default) or translate to English
  --audio-only         Extract audio only, skip transcription
  --output-dir <dir>   Output directory (default: same as input)
  -h, --help           Show this help
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT="$2"; shift 2 ;;
    --input-dir) INPUT_DIR="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --language) LANGUAGE="$2"; shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --audio-only) AUDIO_ONLY=true; shift ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "$PREFIX Unknown option: $1"; exit 1 ;;
  esac
done

# Validate
if [[ -z "$INPUT" && -z "$INPUT_DIR" ]]; then
  echo "$PREFIX Error: --input <file> or --input-dir <dir> required"
  exit 1
fi

# Check dependencies
check_deps() {
  if ! command -v ffmpeg &>/dev/null; then
    echo "$PREFIX Error: ffmpeg not found. Install: sudo apt-get install ffmpeg"
    exit 1
  fi
  if ! command -v whisper &>/dev/null; then
    echo "$PREFIX Error: whisper not found. Install: pip install openai-whisper"
    exit 1
  fi
}

# Extract audio to 16kHz mono WAV (optimal for Whisper)
extract_audio() {
  local input_file="$1"
  local audio_file="$2"
  
  echo "$PREFIX Extracting audio from $(basename "$input_file")..."
  ffmpeg -y -i "$input_file" -ar 16000 -ac 1 -c:a pcm_s16le "$audio_file" -loglevel warning
}

# Generate subtitles for a single file
process_file() {
  local input_file="$1"
  local basename_no_ext="${input_file%.*}"
  
  # Determine output directory
  local out_dir
  if [[ -n "$OUTPUT_DIR" ]]; then
    out_dir="$OUTPUT_DIR"
    mkdir -p "$out_dir"
    basename_no_ext="$out_dir/$(basename "${input_file%.*}")"
  fi
  
  local audio_file="${basename_no_ext}.wav"
  
  # Check if input is already audio
  local mime
  mime=$(file --mime-type -b "$input_file" 2>/dev/null || echo "unknown")
  
  if [[ "$mime" == audio/* ]]; then
    # Already audio — convert to WAV if needed
    if [[ "$input_file" == *.wav ]]; then
      audio_file="$input_file"
    else
      extract_audio "$input_file" "$audio_file"
    fi
  else
    # Video — extract audio
    extract_audio "$input_file" "$audio_file"
  fi
  
  if $AUDIO_ONLY; then
    echo "$PREFIX ✅ Audio extracted to $audio_file"
    return 0
  fi
  
  # Build whisper command
  local whisper_args=(
    "$audio_file"
    --model "$MODEL"
    --output_format "$FORMAT"
    --task "$TASK"
  )
  
  if [[ -n "$LANGUAGE" ]]; then
    whisper_args+=(--language "$LANGUAGE")
  fi
  
  # Output directory for whisper
  local whisper_out_dir
  whisper_out_dir="$(dirname "$basename_no_ext")"
  whisper_args+=(--output_dir "$whisper_out_dir")
  
  echo "$PREFIX Running Whisper (model: $MODEL, task: $TASK)..."
  whisper "${whisper_args[@]}" 2>&1 | grep -v "^$" | while IFS= read -r line; do
    echo "$PREFIX   $line"
  done
  
  # Determine output file path
  local output_file="${basename_no_ext}.${FORMAT}"
  
  # Custom output path
  if [[ -n "$OUTPUT" ]]; then
    if [[ -f "$output_file" ]]; then
      mv "$output_file" "$OUTPUT"
      output_file="$OUTPUT"
    fi
  fi
  
  # Cleanup temp audio (only if we created it)
  if [[ "$audio_file" != "$input_file" && -f "$audio_file" ]]; then
    rm -f "$audio_file"
  fi
  
  if [[ -f "$output_file" ]] || [[ -n "$OUTPUT" && -f "$OUTPUT" ]]; then
    local final="${OUTPUT:-$output_file}"
    echo "$PREFIX ✅ Subtitles saved to $final"
  else
    echo "$PREFIX ❌ Failed to generate subtitles"
    return 1
  fi
}

# Main
check_deps

MEDIA_EXTENSIONS="mp4|mkv|avi|mov|webm|mp3|wav|flac|ogg|m4a|aac|wma|opus"

if [[ -n "$INPUT_DIR" ]]; then
  # Batch mode
  echo "$PREFIX Processing all media files in $INPUT_DIR..."
  count=0
  while IFS= read -r -d '' file; do
    echo ""
    echo "$PREFIX --- Processing: $(basename "$file") ---"
    process_file "$file" && ((count++)) || true
  done < <(find "$INPUT_DIR" -maxdepth 1 -type f -regextype posix-extended -iregex ".*\\.($MEDIA_EXTENSIONS)" -print0 | sort -z)
  
  echo ""
  echo "$PREFIX ✅ Batch complete: $count files processed"
else
  # Single file mode
  if [[ ! -f "$INPUT" ]]; then
    echo "$PREFIX Error: File not found: $INPUT"
    exit 1
  fi
  process_file "$INPUT"
fi
