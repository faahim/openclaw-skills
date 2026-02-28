#!/bin/bash
# Install a Piper voice model by name
set -euo pipefail

PIPER_HOME="${PIPER_HOME:-$HOME/.local/share/piper}"
VOICE_NAME="${1:-}"

if [ -z "$VOICE_NAME" ]; then
  echo "Usage: bash install-voice.sh <voice-name>"
  echo ""
  echo "Examples:"
  echo "  bash install-voice.sh en_US-lessac-medium"
  echo "  bash install-voice.sh en_US-lessac-high"
  echo "  bash install-voice.sh de_DE-thorsten-medium"
  echo "  bash install-voice.sh fr_FR-siwis-medium"
  echo "  bash install-voice.sh es_ES-davefx-medium"
  echo ""
  echo "Full list: https://github.com/rhasspy/piper/blob/master/VOICES.md"
  exit 1
fi

# Parse voice name: lang_COUNTRY-name-quality
# e.g., en_US-lessac-medium -> en/en_US/lessac/medium
IFS='-' read -r LANG_CODE NAME QUALITY <<< "$VOICE_NAME"
LANG_SHORT="${LANG_CODE%%_*}"

VOICE_DIR="$PIPER_HOME/voices/$VOICE_NAME"

if [ -d "$VOICE_DIR" ] && [ -f "$VOICE_DIR/$VOICE_NAME.onnx" ]; then
  echo "✅ Voice already installed: $VOICE_NAME"
  echo "   Location: $VOICE_DIR"
  exit 0
fi

echo "⬇️  Installing voice: $VOICE_NAME..."
mkdir -p "$VOICE_DIR"

BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0"
MODEL_URL="$BASE_URL/$LANG_SHORT/$LANG_CODE/$NAME/$QUALITY/$VOICE_NAME.onnx"
CONFIG_URL="$BASE_URL/$LANG_SHORT/$LANG_CODE/$NAME/$QUALITY/$VOICE_NAME.onnx.json"

echo "   Model:  $MODEL_URL"
echo "   Config: $CONFIG_URL"

if ! curl -fSL "$MODEL_URL" -o "$VOICE_DIR/$VOICE_NAME.onnx"; then
  echo "❌ Failed to download model. Check voice name."
  echo "   Full list: https://github.com/rhasspy/piper/blob/master/VOICES.md"
  rm -rf "$VOICE_DIR"
  exit 1
fi

curl -fSL "$CONFIG_URL" -o "$VOICE_DIR/$VOICE_NAME.onnx.json"

SIZE=$(du -sh "$VOICE_DIR/$VOICE_NAME.onnx" | cut -f1)
echo ""
echo "✅ Voice installed: $VOICE_NAME ($SIZE)"
echo "   Location: $VOICE_DIR"
echo ""
echo "   Use it:"
echo "   bash scripts/tts.sh --voice $VOICE_NAME --input text.txt --output speech.wav"
