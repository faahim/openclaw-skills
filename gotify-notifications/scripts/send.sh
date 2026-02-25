#!/bin/bash
# Send push notifications via Gotify
set -euo pipefail

GOTIFY_URL="${GOTIFY_URL:-http://localhost:8080}"
TOKEN="${GOTIFY_TOKEN:-}"
TITLE=""
MESSAGE=""
PRIORITY=5
CONTENT_TYPE=""
EXTRAS=""
STDIN=false

usage() {
  cat <<EOF
Usage: bash send.sh [OPTIONS]

Options:
  --url URL                Gotify server URL (default: \$GOTIFY_URL or http://localhost:8080)
  --token TOKEN            App token (default: \$GOTIFY_TOKEN)
  --title TITLE            Notification title
  --message MESSAGE        Notification body
  --priority 0-10          Priority level (default: 5)
  --content-type TYPE      Content type (e.g., "text/markdown")
  --extras JSON            Extra client data as JSON string
  --stdin                  Read message from stdin
  -h, --help               Show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) GOTIFY_URL="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --message) MESSAGE="$2"; shift 2 ;;
    --priority) PRIORITY="$2"; shift 2 ;;
    --content-type) CONTENT_TYPE="$2"; shift 2 ;;
    --extras) EXTRAS="$2"; shift 2 ;;
    --stdin) STDIN=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$TOKEN" ]; then
  echo "❌ No token provided. Set GOTIFY_TOKEN or use --token"
  exit 1
fi

if [ "$STDIN" = true ]; then
  MESSAGE=$(cat)
fi

if [ -z "$TITLE" ] && [ -z "$MESSAGE" ]; then
  echo "❌ Provide --title and/or --message (or --stdin)"
  exit 1
fi

# Build JSON payload
PAYLOAD=$(jq -n \
  --arg title "$TITLE" \
  --arg message "$MESSAGE" \
  --argjson priority "$PRIORITY" \
  '{title: $title, message: $message, priority: $priority}')

# Add extras if provided
if [ -n "$EXTRAS" ]; then
  PAYLOAD=$(echo "$PAYLOAD" | jq --argjson extras "$EXTRAS" '. + {extras: $extras}')
fi

# Add content type as extra
if [ -n "$CONTENT_TYPE" ]; then
  PAYLOAD=$(echo "$PAYLOAD" | jq --arg ct "$CONTENT_TYPE" '.extras["client::display"] = {"contentType": $ct}')
fi

# Send
RESPONSE=$(curl -s -w "\n%{http_code}" \
  "${GOTIFY_URL}/message" \
  -H "X-Gotify-Key: ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  MSG_ID=$(echo "$BODY" | jq -r '.id // "unknown"')
  echo "✅ Message sent (id: ${MSG_ID}) — priority ${PRIORITY}"
else
  echo "❌ Failed to send (HTTP ${HTTP_CODE})"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi
