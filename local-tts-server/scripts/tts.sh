#!/bin/bash
# Convert text to speech using Piper TTS
set -euo pipefail

PIPER_HOME="${PIPER_HOME:-$HOME/.local/share/piper}"
PIPER_BIN="$PIPER_HOME/piper"
VOICE="${PIPER_VOICE:-en_US-lessac-medium}"
FORMAT="${PIPER_FORMAT:-wav}"
INPUT=""
OUTPUT=""
SPEED="1.0"
LIST_VOICES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --voice|-v) VOICE="$2"; shift 2 ;;
    --input|-i) INPUT="$2"; shift 2 ;;
    --output|-o) OUTPUT="$2"; shift 2 ;;
    --speed|-s) SPEED="$2"; shift 2 ;;
    --format|-f) FORMAT="$2"; shift 2 ;;
    --list-voices) LIST_VOICES=true; shift ;;
    --help|-h)
      echo "Usage: tts.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --input, -i FILE     Input text file (or pipe via stdin)"
      echo "  --output, -o FILE    Output audio file (default: stdout WAV)"
      echo "  --voice, -v NAME     Voice model name (default: en_US-lessac-medium)"
      echo "  --speed, -s FLOAT    Speech speed 0.5-2.0 (default: 1.0)"
      echo "  --format, -f FMT     Output format: wav or mp3 (default: wav)"
      echo "  --list-voices        List installed voice models"
      echo "  --help, -h           Show this help"
      echo ""
      echo "Examples:"
      echo "  echo 'Hello!' | bash tts.sh > hello.wav"
      echo "  bash tts.sh -i article.txt -o article.mp3"
      echo "  bash tts.sh --voice de_DE-thorsten-medium -i text.txt -o german.wav"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# List voices
if $LIST_VOICES; then
  echo "Installed voices:"
  echo ""
  if [ -d "$PIPER_HOME/voices" ]; then
    for voice_dir in "$PIPER_HOME/voices"/*/; do
      voice=$(basename "$voice_dir")
      size=$(du -sh "$voice_dir" 2>/dev/null | cut -f1)
      echo "  📢 $voice ($size)"
    done
  else
    echo "  (none — run install-voice.sh to add voices)"
  fi
  echo ""
  echo "Download more: https://github.com/rhasspy/piper/blob/master/VOICES.md"
  exit 0
fi

# Check Piper is installed
if [ ! -f "$PIPER_BIN" ]; then
  echo "❌ Piper not found at $PIPER_BIN" >&2
  echo "   Run: bash scripts/install.sh" >&2
  exit 1
fi

# Find voice model
MODEL_PATH="$PIPER_HOME/voices/$VOICE/$VOICE.onnx"
if [ ! -f "$MODEL_PATH" ]; then
  echo "❌ Voice model not found: $VOICE" >&2
  echo "   Run: bash scripts/install-voice.sh $VOICE" >&2
  exit 1
fi

# Determine output path
TEMP_WAV=""
if [ -z "$OUTPUT" ]; then
  # Output to stdout
  OUTPUT="/dev/stdout"
elif [[ "$OUTPUT" == *.mp3 ]]; then
  FORMAT="mp3"
  TEMP_WAV=$(mktemp /tmp/piper-XXXXXX.wav)
fi

# Build Piper command
PIPER_ARGS=(
  --model "$MODEL_PATH"
  --length_scale "$(echo "1.0 / $SPEED" | bc -l 2>/dev/null || echo "1.0")"
)

# Run TTS
START_TIME=$(date +%s%3N 2>/dev/null || date +%s)

if [ -n "$INPUT" ] && [ -f "$INPUT" ]; then
  # From file
  TEXT_INPUT="$INPUT"
  CHAR_COUNT=$(wc -c < "$INPUT")
else
  # From stdin
  TEMP_INPUT=$(mktemp /tmp/piper-input-XXXXXX.txt)
  cat > "$TEMP_INPUT"
  TEXT_INPUT="$TEMP_INPUT"
  CHAR_COUNT=$(wc -c < "$TEMP_INPUT")
fi

if [ "$FORMAT" = "mp3" ] && [ -n "$TEMP_WAV" ]; then
  # Generate WAV first, then convert to MP3
  cat "$TEXT_INPUT" | "$PIPER_BIN" "${PIPER_ARGS[@]}" --output_file "$TEMP_WAV" 2>/dev/null
  
  if ! command -v ffmpeg &>/dev/null; then
    echo "❌ ffmpeg required for MP3 output. Install: sudo apt-get install ffmpeg" >&2
    rm -f "$TEMP_WAV"
    exit 1
  fi
  
  ffmpeg -y -i "$TEMP_WAV" -codec:a libmp3lame -qscale:a 2 "$OUTPUT" -loglevel error 2>/dev/null
  rm -f "$TEMP_WAV"
elif [ "$OUTPUT" = "/dev/stdout" ]; then
  cat "$TEXT_INPUT" | "$PIPER_BIN" "${PIPER_ARGS[@]}" --output-raw 2>/dev/null
else
  cat "$TEXT_INPUT" | "$PIPER_BIN" "${PIPER_ARGS[@]}" --output_file "$OUTPUT" 2>/dev/null
fi

END_TIME=$(date +%s%3N 2>/dev/null || date +%s)
ELAPSED=$(( (END_TIME - START_TIME) ))

# Report (to stderr so it doesn't interfere with piped output)
if [ "$OUTPUT" != "/dev/stdout" ] && [ -f "$OUTPUT" ]; then
  FILE_SIZE=$(du -sh "$OUTPUT" 2>/dev/null | cut -f1)
  DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT" 2>/dev/null || echo "?")
  echo "[✓] Generated $OUTPUT (${DURATION}s, $FILE_SIZE) in ${ELAPSED}ms — $CHAR_COUNT chars, voice: $VOICE" >&2
fi

# Cleanup temp files
[ -n "${TEMP_INPUT:-}" ] && rm -f "$TEMP_INPUT"
