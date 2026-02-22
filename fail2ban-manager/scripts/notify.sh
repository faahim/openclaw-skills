#!/bin/bash
# Send notification via Telegram (pipe stdin as message body)
set -e

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "❌ Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID"
    exit 1
fi

MESSAGE=$(cat)

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" \
    -d "text=$MESSAGE" \
    -d "parse_mode=Markdown" > /dev/null

echo "✅ Notification sent"
