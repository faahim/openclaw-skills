#!/bin/bash
# CrowdSec Alert Notifications Setup
# Usage: bash setup-alerts.sh telegram --bot-token <token> --chat-id <id>
set -euo pipefail

ALERT_TYPE="${1:-}"
BOT_TOKEN=""
CHAT_ID=""
WEBHOOK_URL=""

shift || true

while [[ $# -gt 0 ]]; do
    case $1 in
        --bot-token) BOT_TOKEN="$2"; shift 2 ;;
        --chat-id) CHAT_ID="$2"; shift 2 ;;
        --webhook-url) WEBHOOK_URL="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

setup_telegram() {
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        echo "❌ Required: --bot-token <token> --chat-id <id>"
        exit 1
    fi
    
    echo "📱 Setting up Telegram notifications..."
    
    # Install notification plugin
    sudo cscli notifications install crowdsecurity/http-plugin 2>/dev/null || true
    
    # Create notification config
    sudo mkdir -p /etc/crowdsec/notifications
    sudo tee /etc/crowdsec/notifications/telegram.yaml > /dev/null <<EOF
type: http
name: telegram_alert
log_level: info
format: |
  🚨 *CrowdSec Alert*
  IP: \`{{.Alert.Source.IP}}\`
  Scenario: {{.Alert.Scenario}}
  Country: {{.Alert.Source.Cn}}
  Action: {{range .Alert.Decisions}}{{.Type}} {{.Duration}}{{end}}

url: https://api.telegram.org/bot${BOT_TOKEN}/sendMessage
method: POST
headers:
  Content-Type: application/json
body: |
  {
    "chat_id": "${CHAT_ID}",
    "text": "🚨 CrowdSec Alert\nIP: {{.Alert.Source.IP}}\nScenario: {{.Alert.Scenario}}\nCountry: {{.Alert.Source.Cn}}\nAction: {{range .Alert.Decisions}}{{.Type}} {{.Duration}}{{end}}",
    "parse_mode": "Markdown"
  }
EOF
    
    # Add to profiles
    if ! grep -q "telegram_alert" /etc/crowdsec/profiles.yaml 2>/dev/null; then
        # Append notification to default profile
        sudo sed -i '/^name: default_ip_remediation/a\  notifications:\n    - telegram_alert' /etc/crowdsec/profiles.yaml 2>/dev/null || \
        echo "⚠️  Add 'notifications: [telegram_alert]' to your profile in /etc/crowdsec/profiles.yaml"
    fi
    
    sudo systemctl reload crowdsec
    
    # Test notification
    echo "📤 Sending test notification..."
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"${CHAT_ID}\", \"text\": \"✅ CrowdSec Telegram alerts configured successfully!\"}" > /dev/null
    
    echo "✅ Telegram alerts configured — you'll get notified on every ban"
}

setup_slack() {
    if [ -z "$WEBHOOK_URL" ]; then
        echo "❌ Required: --webhook-url <slack-webhook-url>"
        exit 1
    fi
    
    echo "💬 Setting up Slack notifications..."
    
    sudo mkdir -p /etc/crowdsec/notifications
    sudo tee /etc/crowdsec/notifications/slack.yaml > /dev/null <<EOF
type: http
name: slack_alert
log_level: info
format: |
  :shield: *CrowdSec Alert*
  IP: \`{{.Alert.Source.IP}}\` ({{.Alert.Source.Cn}})
  Scenario: {{.Alert.Scenario}}
  Action: {{range .Alert.Decisions}}{{.Type}} {{.Duration}}{{end}}

url: ${WEBHOOK_URL}
method: POST
headers:
  Content-Type: application/json
body: |
  {
    "text": ":shield: CrowdSec Alert\nIP: {{.Alert.Source.IP}} ({{.Alert.Source.Cn}})\nScenario: {{.Alert.Scenario}}\nAction: {{range .Alert.Decisions}}{{.Type}} {{.Duration}}{{end}}"
  }
EOF
    
    sudo systemctl reload crowdsec
    echo "✅ Slack alerts configured"
}

case "$ALERT_TYPE" in
    telegram)
        setup_telegram
        ;;
    slack)
        setup_slack
        ;;
    *)
        echo "Usage: bash setup-alerts.sh <telegram|slack> [options]"
        echo ""
        echo "Telegram: bash setup-alerts.sh telegram --bot-token <token> --chat-id <id>"
        echo "Slack:    bash setup-alerts.sh slack --webhook-url <url>"
        exit 1
        ;;
esac
