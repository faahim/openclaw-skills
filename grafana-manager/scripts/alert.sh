#!/bin/bash
# Grafana Dashboard Manager — Alert & Notification Management
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY:-}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"

auth_header() {
  if [[ -n "$GRAFANA_API_KEY" ]]; then
    echo "Authorization: Bearer $GRAFANA_API_KEY"
  else
    echo "BASIC_AUTH"
  fi
}

api_call() {
  local method="$1" endpoint="$2" data="${3:-}"
  local auth
  auth=$(auth_header)
  local args=(-s -w "\n%{http_code}" -H "Content-Type: application/json")
  if [[ "$auth" == "BASIC_AUTH" ]]; then
    args+=(-u "${GRAFANA_USER}:${GRAFANA_PASS}")
  else
    args+=(-H "$auth")
  fi
  args+=(-X "$method" "${GRAFANA_URL}${endpoint}")
  [[ -n "$data" ]] && args+=(-d "$data")
  curl "${args[@]}"
}

cmd_create_contact() {
  local name="" type="" url="" chat_id="" bot_token=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --url) url="$2"; shift 2 ;;
      --chat-id) chat_id="$2"; shift 2 ;;
      --bot-token) bot_token="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [[ -z "$name" || -z "$type" ]] && {
    echo "Usage: $0 contact --name NAME --type telegram|slack|webhook [options]"
    exit 1
  }

  local settings
  case "$type" in
    telegram)
      settings=$(jq -n --arg chat "$chat_id" --arg token "$bot_token" '{chatid: $chat, bottoken: $token}')
      ;;
    slack|webhook)
      settings=$(jq -n --arg url "$url" '{url: $url}')
      ;;
    *)
      echo "❌ Unsupported type: $type (use telegram, slack, or webhook)"
      exit 1
      ;;
  esac

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg type "$type" \
    --argjson settings "$settings" \
    '{name: $name, type: $type, settings: $settings}')

  local response
  response=$(api_call POST "/api/alert-notifications" "$payload")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    local id
    id=$(echo "$body" | jq -r '.id')
    echo "✅ Notification channel '$name' created (id: $id)"
  else
    echo "❌ Failed: $body"
    exit 1
  fi
}

cmd_list_contacts() {
  local response
  response=$(api_call GET "/api/alert-notifications")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "$body" | jq -r '.[] | "[\(.id)] \(.name) (\(.type))"'
  else
    echo "❌ Failed: $body"
    exit 1
  fi
}

cmd_list_alerts() {
  local response
  response=$(api_call GET "/api/alerts")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "$body" | jq -r '.[] | "[\(.id)] \(.name) — state: \(.state)"'
    local count
    count=$(echo "$body" | jq '. | length')
    echo "---"
    echo "Total: $count alert(s)"
  else
    echo "❌ Failed: $body"
    exit 1
  fi
}

cmd_test() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id) id="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [[ -z "$id" ]] && { echo "Usage: $0 test --id NOTIFICATION_CHANNEL_ID"; exit 1; }

  local response
  response=$(api_call POST "/api/alert-notifications/${id}/test" '{}')
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "✅ Test notification sent"
  else
    echo "❌ Test failed: $body"
    exit 1
  fi
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  contact) cmd_create_contact "$@" ;;
  contacts) cmd_list_contacts ;;
  list) cmd_list_alerts ;;
  test) cmd_test "$@" ;;
  *)
    echo "Usage: $0 {contact|contacts|list|test} [options]"
    echo ""
    echo "Commands:"
    echo "  contact   Create notification channel (--name, --type telegram|slack|webhook)"
    echo "  contacts  List notification channels"
    echo "  list      List all alerts"
    echo "  test      Test a notification channel (--id)"
    exit 1
    ;;
esac
