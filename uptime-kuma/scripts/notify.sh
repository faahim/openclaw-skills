#!/bin/bash
# Uptime Kuma Notification Management
set -euo pipefail

KUMA_URL="${KUMA_URL:-http://localhost:3001}"
KUMA_USERNAME="${KUMA_USERNAME:-admin}"
KUMA_PASSWORD="${KUMA_PASSWORD:-}"

get_token() {
  if [ -z "$KUMA_PASSWORD" ]; then echo "❌ KUMA_PASSWORD not set" >&2; exit 1; fi
  curl -s "${KUMA_URL}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${KUMA_USERNAME}\",\"password\":\"${KUMA_PASSWORD}\"}" | jq -r '.token'
}

do_add() {
  local name="" type="" token_val="" chat_id="" webhook=""
  local smtp_host="" smtp_port="" smtp_user="" smtp_pass="" smtp_to=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --token) token_val="$2"; shift 2 ;;
      --chat-id) chat_id="$2"; shift 2 ;;
      --webhook) webhook="$2"; shift 2 ;;
      --smtp-host) smtp_host="$2"; shift 2 ;;
      --smtp-port) smtp_port="$2"; shift 2 ;;
      --smtp-user) smtp_user="$2"; shift 2 ;;
      --smtp-pass) smtp_pass="$2"; shift 2 ;;
      --smtp-to) smtp_to="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$name" ] || [ -z "$type" ] && { echo "❌ --name and --type required"; exit 1; }

  TOKEN=$(get_token)
  local payload

  case "$type" in
    telegram)
      payload=$(jq -n --arg name "$name" --arg token "$token_val" --arg chatid "$chat_id" '{
        name: $name, type: "telegram", isDefault: true, active: true,
        telegramBotToken: $token, telegramChatID: $chatid
      }')
      ;;
    slack)
      payload=$(jq -n --arg name "$name" --arg wh "$webhook" '{
        name: $name, type: "slack", isDefault: true, active: true,
        slackwebhookURL: $wh
      }')
      ;;
    discord)
      payload=$(jq -n --arg name "$name" --arg wh "$webhook" '{
        name: $name, type: "discord", isDefault: true, active: true,
        discordWebhookUrl: $wh
      }')
      ;;
    smtp)
      payload=$(jq -n --arg name "$name" --arg h "$smtp_host" --argjson p "${smtp_port:-587}" \
        --arg u "$smtp_user" --arg pw "$smtp_pass" --arg to "$smtp_to" '{
        name: $name, type: "smtp", isDefault: true, active: true,
        smtpHost: $h, smtpPort: $p, smtpUsername: $u, smtpPassword: $pw,
        smtpTo: $to, smtpSecure: true
      }')
      ;;
    webhook)
      payload=$(jq -n --arg name "$name" --arg wh "$webhook" '{
        name: $name, type: "webhook", isDefault: true, active: true,
        webhookURL: $wh, webhookContentType: "application/json"
      }')
      ;;
    *)
      echo "❌ Unsupported type: $type (use: telegram, slack, discord, smtp, webhook)"
      exit 1
      ;;
  esac

  RESULT=$(curl -s "${KUMA_URL}/api/notifications" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$payload")

  if echo "$RESULT" | jq -e '.id' &>/dev/null; then
    echo "✅ Notification added: ${name} (${type})"
  else
    echo "❌ Failed: $(echo "$RESULT" | jq -r '.msg // .error // "Unknown error"')"
  fi
}

do_list() {
  TOKEN=$(get_token)
  curl -s "${KUMA_URL}/api/notifications" \
    -H "Authorization: Bearer $TOKEN" | jq -r '
    if type == "array" then
      ["ID", "Name", "Type", "Active"],
      (.[] | [(.id|tostring), .name, .type, (if .active then "✅" else "❌" end)]) | @tsv
    else "No notifications configured"
    end
  ' 2>/dev/null | column -t -s$'\t' || echo "No notifications found"
}

CMD="${1:-list}"
shift 2>/dev/null || true

case "$CMD" in
  add) do_add "$@" ;;
  list) do_list ;;
  *) echo "Usage: $0 <add|list> [options]" ;;
esac
