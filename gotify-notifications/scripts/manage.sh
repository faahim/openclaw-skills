#!/bin/bash
# Manage Gotify server: apps, clients, messages, health
set -euo pipefail

GOTIFY_URL="${GOTIFY_URL:-http://localhost:8080}"
ADMIN_USER="${GOTIFY_ADMIN_USER:-admin}"
ADMIN_PASS="${GOTIFY_ADMIN_PASS:-}"

AUTH=""
if [ -n "$ADMIN_PASS" ]; then
  AUTH="-u ${ADMIN_USER}:${ADMIN_PASS}"
fi

ACTION=""
NAME=""
DESCRIPTION=""
ID=""
APP_ID=""
LIMIT=20

usage() {
  cat <<EOF
Usage: bash manage.sh ACTION [OPTIONS]

Actions:
  health              Check server health
  create-app          Create a new application
  list-apps           List all applications
  delete-app          Delete an application
  create-client       Create a new client
  list-clients        List all clients
  delete-client       Delete a client
  list-messages       List recent messages
  delete-messages     Delete all messages
  server-info         Show server version info

Options:
  --name NAME            App/client name
  --description DESC     App/client description
  --id ID                App/client ID (for delete)
  --app-id ID            Filter messages by app ID
  --limit N              Number of messages (default: 20)
  -h, --help             Show this help
EOF
  exit 0
}

ACTION="${1:-}"; shift 2>/dev/null || true

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --app-id) APP_ID="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

api() {
  local method=$1 endpoint=$2
  shift 2
  curl -s $AUTH -X "$method" "${GOTIFY_URL}${endpoint}" \
    -H "Content-Type: application/json" "$@"
}

case "$ACTION" in
  health)
    VERSION=$(api GET /version | jq -r '.version // "unknown"')
    APPS=$(api GET /application | jq 'length')
    CLIENTS=$(api GET /client | jq 'length')
    if [ "$VERSION" != "null" ] && [ "$VERSION" != "unknown" ]; then
      echo "✅ Gotify server is healthy"
      echo "   Version: ${VERSION}"
      echo "   Apps: ${APPS} | Clients: ${CLIENTS}"
    else
      echo "❌ Cannot reach Gotify at ${GOTIFY_URL}"
      exit 1
    fi
    ;;

  create-app)
    if [ -z "$NAME" ]; then echo "❌ --name required"; exit 1; fi
    RESULT=$(api POST /application -d "$(jq -n --arg n "$NAME" --arg d "$DESCRIPTION" '{name:$n,description:$d}')")
    TOKEN=$(echo "$RESULT" | jq -r '.token')
    echo "✅ App created: \"${NAME}\""
    echo "📌 App Token: ${TOKEN}"
    echo "Save this token — you'll use it to send messages."
    ;;

  list-apps)
    api GET /application | jq -r '.[] | "[\(.id)] \(.name) — token: \(.token)"'
    ;;

  delete-app)
    if [ -z "$ID" ]; then echo "❌ --id required"; exit 1; fi
    api DELETE "/application/${ID}"
    echo "✅ App ${ID} deleted"
    ;;

  create-client)
    if [ -z "$NAME" ]; then echo "❌ --name required"; exit 1; fi
    RESULT=$(api POST /client -d "$(jq -n --arg n "$NAME" '{name:$n}')")
    TOKEN=$(echo "$RESULT" | jq -r '.token')
    echo "✅ Client created: \"${NAME}\""
    echo "📌 Client Token: ${TOKEN}"
    ;;

  list-clients)
    api GET /client | jq -r '.[] | "[\(.id)] \(.name) — token: \(.token)"'
    ;;

  delete-client)
    if [ -z "$ID" ]; then echo "❌ --id required"; exit 1; fi
    api DELETE "/client/${ID}"
    echo "✅ Client ${ID} deleted"
    ;;

  list-messages)
    if [ -n "$APP_ID" ]; then
      api GET "/application/${APP_ID}/message?limit=${LIMIT}" | jq -r '.messages[]? | "[\(.date)] [\(.priority)] \(.title): \(.message)"'
    else
      api GET "/message?limit=${LIMIT}" | jq -r '.messages[]? | "[\(.date)] [\(.priority)] \(.title): \(.message)"'
    fi
    ;;

  delete-messages)
    api DELETE /message
    echo "✅ All messages deleted"
    ;;

  server-info)
    api GET /version | jq .
    ;;

  *)
    echo "❌ Unknown action: ${ACTION}"
    usage
    ;;
esac
