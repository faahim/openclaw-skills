#!/bin/bash
# Configure Scrutiny alert notifications
set -euo pipefail

CONFIG="/opt/scrutiny/config/scrutiny.yaml"
MODE=""
TELEGRAM_TOKEN=""
TELEGRAM_CHAT=""
SMTP_HOST="" SMTP_PORT="" SMTP_USER="" SMTP_PASS="" EMAIL_TO=""
WEBHOOK_URL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --telegram) MODE="telegram"; shift ;;
    --email) MODE="email"; shift ;;
    --webhook) MODE="webhook"; shift ;;
    --token) TELEGRAM_TOKEN="$2"; shift 2 ;;
    --chat) TELEGRAM_CHAT="$2"; shift 2 ;;
    --smtp-host) SMTP_HOST="$2"; shift 2 ;;
    --smtp-port) SMTP_PORT="$2"; shift 2 ;;
    --smtp-user) SMTP_USER="$2"; shift 2 ;;
    --smtp-pass) SMTP_PASS="$2"; shift 2 ;;
    --to) EMAIL_TO="$2"; shift 2 ;;
    --url) WEBHOOK_URL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: configure-alerts.sh --telegram|--email|--webhook [OPTIONS]"
      echo ""
      echo "Telegram: --token BOT_TOKEN --chat CHAT_ID"
      echo "Email:    --smtp-host HOST --smtp-port PORT --smtp-user USER --smtp-pass PASS --to EMAIL"
      echo "Webhook:  --url WEBHOOK_URL"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Specify alert type: --telegram, --email, or --webhook"
  exit 1
fi

# Build notification URL (Scrutiny uses shoutrrr format)
NOTIFY_URL=""
case $MODE in
  telegram)
    [ -z "$TELEGRAM_TOKEN" ] && TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
    [ -z "$TELEGRAM_CHAT" ] && TELEGRAM_CHAT="${TELEGRAM_CHAT_ID:-}"
    [ -z "$TELEGRAM_TOKEN" ] && { echo "❌ Provide --token or set TELEGRAM_BOT_TOKEN"; exit 1; }
    [ -z "$TELEGRAM_CHAT" ] && { echo "❌ Provide --chat or set TELEGRAM_CHAT_ID"; exit 1; }
    NOTIFY_URL="telegram://${TELEGRAM_TOKEN}@telegram?channels=${TELEGRAM_CHAT}"
    ;;
  email)
    [ -z "$SMTP_HOST" ] && { echo "❌ Provide --smtp-host"; exit 1; }
    SMTP_PORT="${SMTP_PORT:-587}"
    NOTIFY_URL="smtp://${SMTP_USER}:${SMTP_PASS}@${SMTP_HOST}:${SMTP_PORT}/?to=${EMAIL_TO}"
    ;;
  webhook)
    [ -z "$WEBHOOK_URL" ] && { echo "❌ Provide --url"; exit 1; }
    NOTIFY_URL="generic+${WEBHOOK_URL}"
    ;;
esac

# Update config
if [ ! -f "$CONFIG" ]; then
  echo "❌ Config not found at $CONFIG — deploy Scrutiny first"
  exit 1
fi

# Check if notify section exists, add or append
if grep -q "notify:" "$CONFIG"; then
  # Append URL to existing notify section
  if ! grep -qF "$NOTIFY_URL" "$CONFIG"; then
    sed -i "/urls:/a\\    - \"${NOTIFY_URL}\"" "$CONFIG"
  fi
else
  # Add notify section
  cat >> "$CONFIG" << EOF

notify:
  urls:
    - "${NOTIFY_URL}"
EOF
fi

# Restart Scrutiny to pick up config
docker restart scrutiny &>/dev/null || true

echo "✅ ${MODE^} alerts configured"
echo "   Test with: bash scripts/test-alert.sh"
