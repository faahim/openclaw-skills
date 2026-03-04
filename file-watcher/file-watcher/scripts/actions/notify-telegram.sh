#!/bin/bash
# Send Telegram notification about file change
# Requires: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
set -euo pipefail

FILE="${1:-$WATCH_FILE}"
EVENT="${2:-$WATCH_EVENT}"

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    echo "Error: Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID"
    exit 1
fi

MSG="📁 File Watcher Alert%0A%0AEvent: ${EVENT}%0AFile: ${FILE}%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"

curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT_ID}&text=${MSG}" > /dev/null
echo "📨 Telegram notification sent"
