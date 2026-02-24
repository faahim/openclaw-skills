#!/bin/bash
# Configure Netdata alert destinations
set -e

CONF="/etc/netdata/health_alarm_notify.conf"
METHOD="${1:-}"

usage() {
    echo "Usage: bash scripts/configure-alerts.sh <method> [options]"
    echo ""
    echo "Methods:"
    echo "  telegram  --bot-token TOKEN --chat-id CHAT_ID"
    echo "  slack     --webhook-url URL"
    echo "  email     --to EMAIL [--smtp-host HOST] [--smtp-port PORT] [--smtp-user USER] [--smtp-pass PASS]"
    echo "  webhook   --url URL"
    echo "  discord   --webhook-url URL"
    exit 1
}

[ -z "$METHOD" ] && usage

# Parse args
shift
BOT_TOKEN="" CHAT_ID="" WEBHOOK_URL="" EMAIL_TO="" SMTP_HOST="" SMTP_PORT="" SMTP_USER="" SMTP_PASS="" HOOK_URL=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --bot-token) BOT_TOKEN="$2"; shift 2 ;;
        --chat-id) CHAT_ID="$2"; shift 2 ;;
        --webhook-url) WEBHOOK_URL="$2"; shift 2 ;;
        --url) HOOK_URL="$2"; shift 2 ;;
        --to) EMAIL_TO="$2"; shift 2 ;;
        --smtp-host) SMTP_HOST="$2"; shift 2 ;;
        --smtp-port) SMTP_PORT="$2"; shift 2 ;;
        --smtp-user) SMTP_USER="$2"; shift 2 ;;
        --smtp-pass) SMTP_PASS="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Ensure config exists
if [ ! -f "$CONF" ]; then
    sudo cp /etc/netdata/health_alarm_notify.conf.orig "$CONF" 2>/dev/null || \
    sudo cp /usr/lib/netdata/conf.d/health_alarm_notify.conf "$CONF" 2>/dev/null || {
        echo "Creating fresh config..."
        sudo touch "$CONF"
    }
fi

case "$METHOD" in
    telegram)
        [ -z "$BOT_TOKEN" ] && { echo "❌ --bot-token required"; exit 1; }
        [ -z "$CHAT_ID" ] && { echo "❌ --chat-id required"; exit 1; }
        sudo sed -i "s|^SEND_TELEGRAM=.*|SEND_TELEGRAM=\"YES\"|" "$CONF" 2>/dev/null || \
            echo 'SEND_TELEGRAM="YES"' | sudo tee -a "$CONF" >/dev/null
        sudo sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=\"$BOT_TOKEN\"|" "$CONF" 2>/dev/null || \
            echo "TELEGRAM_BOT_TOKEN=\"$BOT_TOKEN\"" | sudo tee -a "$CONF" >/dev/null
        sudo sed -i "s|^DEFAULT_RECIPIENT_TELEGRAM=.*|DEFAULT_RECIPIENT_TELEGRAM=\"$CHAT_ID\"|" "$CONF" 2>/dev/null || \
            echo "DEFAULT_RECIPIENT_TELEGRAM=\"$CHAT_ID\"" | sudo tee -a "$CONF" >/dev/null
        echo "✅ Telegram alerts configured"
        echo "   Bot: $BOT_TOKEN"
        echo "   Chat: $CHAT_ID"
        ;;
    slack)
        [ -z "$WEBHOOK_URL" ] && { echo "❌ --webhook-url required"; exit 1; }
        sudo sed -i "s|^SEND_SLACK=.*|SEND_SLACK=\"YES\"|" "$CONF" 2>/dev/null || \
            echo 'SEND_SLACK="YES"' | sudo tee -a "$CONF" >/dev/null
        sudo sed -i "s|^SLACK_WEBHOOK_URL=.*|SLACK_WEBHOOK_URL=\"$WEBHOOK_URL\"|" "$CONF" 2>/dev/null || \
            echo "SLACK_WEBHOOK_URL=\"$WEBHOOK_URL\"" | sudo tee -a "$CONF" >/dev/null
        sudo sed -i "s|^DEFAULT_RECIPIENT_SLACK=.*|DEFAULT_RECIPIENT_SLACK=\"#monitoring\"|" "$CONF" 2>/dev/null || \
            echo 'DEFAULT_RECIPIENT_SLACK="#monitoring"' | sudo tee -a "$CONF" >/dev/null
        echo "✅ Slack alerts configured"
        echo "   Channel: #monitoring (edit $CONF to change)"
        ;;
    email)
        [ -z "$EMAIL_TO" ] && { echo "❌ --to required"; exit 1; }
        sudo sed -i "s|^SEND_EMAIL=.*|SEND_EMAIL=\"YES\"|" "$CONF" 2>/dev/null || \
            echo 'SEND_EMAIL="YES"' | sudo tee -a "$CONF" >/dev/null
        sudo sed -i "s|^DEFAULT_RECIPIENT_EMAIL=.*|DEFAULT_RECIPIENT_EMAIL=\"$EMAIL_TO\"|" "$CONF" 2>/dev/null || \
            echo "DEFAULT_RECIPIENT_EMAIL=\"$EMAIL_TO\"" | sudo tee -a "$CONF" >/dev/null
        [ -n "$SMTP_HOST" ] && echo "EMAIL_SENDER=\"$SMTP_USER\"" | sudo tee -a "$CONF" >/dev/null
        echo "✅ Email alerts configured → $EMAIL_TO"
        [ -n "$SMTP_HOST" ] && echo "   Note: Configure sendmail/msmtp for SMTP relay"
        ;;
    webhook)
        [ -z "$HOOK_URL" ] && { echo "❌ --url required"; exit 1; }
        sudo sed -i "s|^SEND_CUSTOM=.*|SEND_CUSTOM=\"YES\"|" "$CONF" 2>/dev/null || \
            echo 'SEND_CUSTOM="YES"' | sudo tee -a "$CONF" >/dev/null
        echo "DEFAULT_RECIPIENT_CUSTOM=\"$HOOK_URL\"" | sudo tee -a "$CONF" >/dev/null
        echo "✅ Webhook alerts configured → $HOOK_URL"
        ;;
    discord)
        [ -z "$WEBHOOK_URL" ] && { echo "❌ --webhook-url required"; exit 1; }
        sudo sed -i "s|^SEND_DISCORD=.*|SEND_DISCORD=\"YES\"|" "$CONF" 2>/dev/null || \
            echo 'SEND_DISCORD="YES"' | sudo tee -a "$CONF" >/dev/null
        sudo sed -i "s|^DISCORD_WEBHOOK_URL=.*|DISCORD_WEBHOOK_URL=\"$WEBHOOK_URL\"|" "$CONF" 2>/dev/null || \
            echo "DISCORD_WEBHOOK_URL=\"$WEBHOOK_URL\"" | sudo tee -a "$CONF" >/dev/null
        echo "✅ Discord alerts configured"
        ;;
    *)
        echo "❌ Unknown method: $METHOD"
        usage
        ;;
esac

echo ""
echo "Test with: bash scripts/test-alert.sh $METHOD"
echo "Reload:    sudo netdatacli reload-health"
