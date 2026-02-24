#!/bin/bash
# Manage changedetection.io notification channels
set -euo pipefail

BASE_URL="${CHANGEDETECTION_URL:-http://localhost:5000}"
API_KEY="${CHANGEDETECTION_API_KEY:-}"

api() {
  local method="$1" endpoint="$2"
  shift 2
  local headers=(-H "Content-Type: application/json")
  [ -n "$API_KEY" ] && headers+=(-H "x-api-key: $API_KEY")
  curl -s -X "$method" "${BASE_URL}/api/v1${endpoint}" "${headers[@]}" "$@"
}

cmd_setup_telegram() {
  local bot_token="" chat_id=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --bot-token) bot_token="$2"; shift 2 ;;
      --chat-id) chat_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$bot_token" ] && bot_token="${TELEGRAM_BOT_TOKEN:-}"
  [ -z "$chat_id" ] && chat_id="${TELEGRAM_CHAT_ID:-}"
  [ -z "$bot_token" ] && { echo "❌ --bot-token or TELEGRAM_BOT_TOKEN required"; exit 1; }
  [ -z "$chat_id" ] && { echo "❌ --chat-id or TELEGRAM_CHAT_ID required"; exit 1; }

  local apprise_url="tgram://${bot_token}/${chat_id}"
  
  # Update global notification URL via settings
  local settings
  settings=$(api GET "/settings")
  
  local current_urls
  current_urls=$(echo "$settings" | jq -r '.notification_urls // [] | join("\n")')
  
  if echo "$current_urls" | grep -q "tgram://"; then
    echo "⚠️  Telegram already configured. Updating..."
    settings=$(echo "$settings" | jq --arg url "$apprise_url" '
      .notification_urls = [(.notification_urls // [] | map(select(startswith("tgram://") | not))), [$url]] | flatten
    ')
  else
    settings=$(echo "$settings" | jq --arg url "$apprise_url" '
      .notification_urls = ((.notification_urls // []) + [$url])
    ')
  fi

  api PUT "/settings" -d "$settings" >/dev/null
  echo "✅ Telegram notifications configured"
  echo "   Bot: ${bot_token:0:10}..."
  echo "   Chat: $chat_id"
}

cmd_add() {
  local url=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --url) url="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$url" ] && { echo "❌ --url required (apprise URL)"; exit 1; }

  local settings
  settings=$(api GET "/settings")
  settings=$(echo "$settings" | jq --arg url "$url" '
    .notification_urls = ((.notification_urls // []) + [$url])
  ')
  api PUT "/settings" -d "$settings" >/dev/null
  echo "✅ Added notification channel: $url"
}

cmd_list() {
  local settings
  settings=$(api GET "/settings")
  echo "📢 Notification channels:"
  echo "$settings" | jq -r '.notification_urls // [] | .[]' | while read -r url; do
    # Mask tokens
    masked=$(echo "$url" | sed 's/\(.\{15\}\).*/\1.../')
    echo "  - $masked"
  done
}

cmd_test() {
  echo "🔔 Sending test notification..."
  api POST "/settings/notification-test" >/dev/null 2>&1 || true
  echo "✅ Test notification sent (check your channels)"
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  setup-telegram) cmd_setup_telegram "$@" ;;
  add) cmd_add "$@" ;;
  list) cmd_list "$@" ;;
  test) cmd_test "$@" ;;
  *)
    echo "Usage: notify.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup-telegram  Configure Telegram alerts (--bot-token, --chat-id)"
    echo "  add             Add apprise notification URL (--url)"
    echo "  list            List configured channels"
    echo "  test            Send test notification"
    ;;
esac
