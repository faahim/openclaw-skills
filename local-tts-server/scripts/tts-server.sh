#!/bin/bash
# Simple HTTP TTS server using netcat/socat
set -euo pipefail

PIPER_HOME="${PIPER_HOME:-$HOME/.local/share/piper}"
PORT="${1:-5000}"
VOICE="${PIPER_VOICE:-en_US-lessac-medium}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔊 Starting TTS server on port $PORT..."
echo "   Voice: $VOICE"
echo "   Endpoint: POST http://localhost:$PORT/tts"
echo "   Press Ctrl+C to stop"
echo ""

# Check for socat
if ! command -v socat &>/dev/null; then
  echo "❌ socat is required for the HTTP server"
  echo "   Install: sudo apt-get install socat"
  exit 1
fi

handle_request() {
  read -r REQUEST_LINE
  
  # Read headers
  CONTENT_LENGTH=0
  while IFS= read -r header; do
    header=$(echo "$header" | tr -d '\r')
    [ -z "$header" ] && break
    if echo "$header" | grep -qi "content-length:"; then
      CONTENT_LENGTH=$(echo "$header" | grep -oi '[0-9]*')
    fi
  done
  
  # Read body
  BODY=""
  if [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
    BODY=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)
  fi
  
  # Extract text from JSON body (simple parsing)
  TEXT=$(echo "$BODY" | grep -oP '"text"\s*:\s*"\K[^"]*' 2>/dev/null || echo "$BODY")
  REQ_VOICE=$(echo "$BODY" | grep -oP '"voice"\s*:\s*"\K[^"]*' 2>/dev/null || echo "$VOICE")
  
  if [ -z "$TEXT" ]; then
    echo -e "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\n\r\n{\"error\":\"No text provided\"}"
    return
  fi
  
  # Generate audio
  TEMP_WAV=$(mktemp /tmp/piper-server-XXXXXX.wav)
  echo "$TEXT" | bash "$SCRIPT_DIR/tts.sh" --voice "$REQ_VOICE" --output "$TEMP_WAV" 2>/dev/null
  
  FILE_SIZE=$(stat -c%s "$TEMP_WAV" 2>/dev/null || stat -f%z "$TEMP_WAV")
  
  echo -ne "HTTP/1.1 200 OK\r\nContent-Type: audio/wav\r\nContent-Length: $FILE_SIZE\r\n\r\n"
  cat "$TEMP_WAV"
  rm -f "$TEMP_WAV"
}

export -f handle_request
export PIPER_HOME VOICE SCRIPT_DIR

socat TCP-LISTEN:$PORT,reuseaddr,fork SYSTEM:"bash -c handle_request"
