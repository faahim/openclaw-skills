#!/bin/bash
# Send alert via Telegram or stdout
# Usage: alert.sh "message text"

set -euo pipefail

MSG="${1:-No message provided}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] ALERT: $MSG"

# Telegram alert
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="🔔 Inotify Alert: ${MSG}" \
    -d parse_mode="HTML" \
    > /dev/null 2>&1 && echo "  → Telegram alert sent" || echo "  → Telegram alert failed"
fi

# Email alert (if SMTP configured)
if [[ -n "${SMTP_TO:-}" ]] && command -v mail &>/dev/null; then
  echo "$MSG" | mail -s "Inotify Alert: $MSG" "$SMTP_TO" 2>/dev/null && \
    echo "  → Email alert sent" || echo "  → Email alert failed"
fi
