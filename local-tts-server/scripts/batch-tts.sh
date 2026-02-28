#!/bin/bash
# Batch convert text files to audio
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_DIR=""
OUTPUT_DIR=""
FORMAT="${PIPER_FORMAT:-wav}"
VOICE="${PIPER_VOICE:-en_US-lessac-medium}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --input-dir) INPUT_DIR="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --voice) VOICE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: batch-tts.sh --input-dir DIR --output-dir DIR [--format wav|mp3] [--voice NAME]"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "❌ Both --input-dir and --output-dir are required"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

COUNT=0
TOTAL_START=$(date +%s)

for txt_file in "$INPUT_DIR"/*.txt "$INPUT_DIR"/*.md; do
  [ -f "$txt_file" ] || continue
  
  basename=$(basename "$txt_file" | sed 's/\.[^.]*$//')
  output_file="$OUTPUT_DIR/$basename.$FORMAT"
  
  echo "🔊 Converting: $(basename "$txt_file") → $basename.$FORMAT"
  bash "$SCRIPT_DIR/tts.sh" --voice "$VOICE" --input "$txt_file" --output "$output_file"
  COUNT=$((COUNT + 1))
done

TOTAL_END=$(date +%s)
ELAPSED=$((TOTAL_END - TOTAL_START))

echo ""
echo "[✓] Converted $COUNT files in ${ELAPSED}s"
echo "[✓] Output: $OUTPUT_DIR/"
