#!/bin/bash
# Notification helper for Directory Watcher
# Sends alerts via Telegram, email (SMTP), webhook, or stdout
set -euo pipefail

MESSAGE="${1:-File change detected}"

# Telegram
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=🔔 Directory Watcher: ${MESSAGE}" \
    -d "parse_mode=HTML" > /dev/null 2>&1 && echo "[notify] Telegram: sent" || echo "[notify] Telegram: failed"
fi

# Webhook
if [[ -n "${WEBHOOK_URL:-}" ]]; then
  curl -s -X POST "${WEBHOOK_URL}" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"${MESSAGE}\",\"source\":\"directory-watcher\",\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
    > /dev/null 2>&1 && echo "[notify] Webhook: sent" || echo "[notify] Webhook: failed"
fi

# Email (SMTP via curl)
if [[ -n "${SMTP_HOST:-}" && -n "${SMTP_TO:-}" ]]; then
  SMTP_PORT="${SMTP_PORT:-587}"
  SMTP_FROM="${SMTP_FROM:-watcher@localhost}"
  curl -s --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
    --ssl-reqd \
    --mail-from "${SMTP_FROM}" \
    --mail-rcpt "${SMTP_TO}" \
    ${SMTP_USER:+--user "${SMTP_USER}:${SMTP_PASS:-}"} \
    -T <(echo -e "From: ${SMTP_FROM}\nTo: ${SMTP_TO}\nSubject: Directory Watcher Alert\n\n${MESSAGE}") \
    > /dev/null 2>&1 && echo "[notify] Email: sent" || echo "[notify] Email: failed"
fi

# Always stdout
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔔 ${MESSAGE}"
