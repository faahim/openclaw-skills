#!/bin/bash
# Configure Monit alerting (email or webhook)
set -e

EMAIL=""
SMTP_HOST=""
SMTP_PORT="587"
SMTP_USER=""
SMTP_PASS=""
WEBHOOK=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --email) EMAIL="$2"; shift 2 ;;
    --smtp) SMTP_HOST="$2"; shift 2 ;;
    --smtp-port) SMTP_PORT="$2"; shift 2 ;;
    --smtp-user) SMTP_USER="$2"; shift 2 ;;
    --smtp-pass) SMTP_PASS="$2"; shift 2 ;;
    --webhook) WEBHOOK="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

MONITRC="/etc/monit/monitrc"
ALERT_CONF="/etc/monit/conf.d/alerts.conf"

CONFIG=""

# Email alerts
if [ -n "$EMAIL" ]; then
  if [ -z "$SMTP_HOST" ]; then
    echo "❌ --smtp is required with --email"
    exit 1
  fi

  # Add mail server config to monitrc
  MAIL_CONFIG="set mailserver $SMTP_HOST port $SMTP_PORT"
  if [ -n "$SMTP_USER" ]; then
    MAIL_CONFIG="$MAIL_CONFIG username \"$SMTP_USER\" password \"$SMTP_PASS\" using tls"
  fi

  # Remove existing mail server config
  sudo sed -i '/^set mailserver/d' "$MONITRC" 2>/dev/null || true
  sudo sed -i '/^set alert/d' "$MONITRC" 2>/dev/null || true

  echo "$MAIL_CONFIG" | sudo tee -a "$MONITRC" >/dev/null
  echo "set alert $EMAIL" | sudo tee -a "$MONITRC" >/dev/null

  echo "✅ Email alerts configured: $EMAIL via $SMTP_HOST:$SMTP_PORT"
fi

# Webhook alerts
if [ -n "$WEBHOOK" ]; then
  # Create a webhook alert script
  WEBHOOK_SCRIPT="/etc/monit/webhook-alert.sh"
  cat <<'SCRIPT' | sudo tee "$WEBHOOK_SCRIPT" >/dev/null
#!/bin/bash
# Monit webhook alert script
# Called with: $MONIT_SERVICE $MONIT_EVENT $MONIT_DESCRIPTION
SERVICE="$MONIT_SERVICE"
EVENT="$MONIT_EVENT"
DESC="$MONIT_DESCRIPTION"
HOST=$(hostname)
DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SCRIPT

  echo "WEBHOOK_URL=\"$WEBHOOK\"" | sudo tee -a "$WEBHOOK_SCRIPT" >/dev/null

  cat <<'SCRIPT' | sudo tee -a "$WEBHOOK_SCRIPT" >/dev/null

PAYLOAD=$(cat <<EOF
{
  "text": "🚨 Monit Alert on $HOST",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "🚨 *Monit Alert*\n*Host:* $HOST\n*Service:* $SERVICE\n*Event:* $EVENT\n*Details:* $DESC\n*Time:* $DATE"
      }
    }
  ]
}
EOF
)

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" >/dev/null 2>&1
SCRIPT

  sudo chmod +x "$WEBHOOK_SCRIPT"

  # Add webhook exec to alerts config
  CONFIG="check program webhook-test with path \"/bin/true\"
  if status != 0 then exec \"$WEBHOOK_SCRIPT\""

  echo "$CONFIG" | sudo tee "$ALERT_CONF" >/dev/null
  echo "✅ Webhook alerts configured: $WEBHOOK"
fi

# Validate and reload
if sudo monit -t 2>/dev/null; then
  sudo monit reload 2>/dev/null
  echo "🔄 Monit reloaded"
else
  echo "❌ Config validation failed — check syntax"
  exit 1
fi
