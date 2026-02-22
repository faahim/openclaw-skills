#!/bin/bash
# Webhook Tester — Replay captured webhooks
set -e

WEBHOOK_DIR="${WEBHOOK_TESTER_DIR:-./webhooks}"

TARGET="$1"
DEST_URL="$2"

if [[ -z "$TARGET" || -z "$DEST_URL" ]]; then
  echo "Usage: replay.sh <webhook-num> <destination-url>"
  echo ""
  echo "Example: replay.sh 1 http://localhost:3000/api/webhooks/stripe"
  exit 1
fi

FILE=$(ls "$WEBHOOK_DIR"/*.json 2>/dev/null | sort | sed -n "${TARGET}p")

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "❌ Webhook #$TARGET not found"
  exit 1
fi

METHOD=$(jq -r '.method' "$FILE")
BODY=$(jq -r '.body_raw' "$FILE")

# Build header args
HEADER_ARGS=""
while IFS= read -r line; do
  key=$(echo "$line" | jq -r '.key')
  val=$(echo "$line" | jq -r '.value')
  # Skip hop-by-hop headers
  case "$key" in
    Host|Content-Length|Transfer-Encoding|Connection) continue ;;
  esac
  HEADER_ARGS="$HEADER_ARGS -H \"$key: $val\""
done < <(jq -c '.headers | to_entries[]' "$FILE")

echo "🔄 Replaying webhook #$TARGET → $DEST_URL"
echo "   Method: $METHOD"
echo "   Body: ${#BODY} bytes"
echo ""

# Execute replay
START=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")

RESP=$(eval curl -s -o /dev/null -w "%{http_code}" \
  -X "$METHOD" \
  "$DEST_URL" \
  $HEADER_ARGS \
  -d "'$(echo "$BODY" | sed "s/'/'\\\\''/g")'")

END=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
ELAPSED=$((END - START))

echo "Response: $RESP ($ELAPSED ms)"
