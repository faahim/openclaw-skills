#!/bin/bash
# Watchtower Container Updater — Interactive Setup
set -e

echo "🐋 Watchtower Container Updater — Setup"
echo "========================================"
echo ""

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "❌ Docker is not installed. Install it first: https://docs.docker.com/get-docker/"
  exit 1
fi

if ! docker info &>/dev/null 2>&1; then
  echo "❌ Docker daemon is not running. Start it with: sudo systemctl start docker"
  exit 1
fi

echo "✅ Docker is running"
echo ""

# Check if Watchtower already exists
if docker ps -a --format '{{.Names}}' | grep -q "^watchtower$"; then
  echo "⚠️  Watchtower container already exists."
  read -p "Remove and reconfigure? (y/N): " REPLACE
  if [[ "$REPLACE" =~ ^[Yy]$ ]]; then
    docker stop watchtower 2>/dev/null || true
    docker rm watchtower 2>/dev/null || true
    echo "🗑️  Old Watchtower removed"
  else
    echo "Keeping existing Watchtower. Exiting."
    exit 0
  fi
fi

echo ""

# Schedule
echo "📅 Update Schedule"
echo "  1) Every day at 3am (recommended)"
echo "  2) Every 6 hours"
echo "  3) Every hour"
echo "  4) Custom cron expression"
read -p "Choose [1-4] (default: 1): " SCHED_CHOICE

case "${SCHED_CHOICE:-1}" in
  1) SCHEDULE="0 0 3 * * *" ; echo "  → Daily at 3am" ;;
  2) SCHEDULE="0 0 */6 * * *" ; echo "  → Every 6 hours" ;;
  3) SCHEDULE="0 0 * * * *" ; echo "  → Every hour" ;;
  4) read -p "  Enter 6-field cron (sec min hr day mon dow): " SCHEDULE ;;
  *) SCHEDULE="0 0 3 * * *" ; echo "  → Daily at 3am (default)" ;;
esac

echo ""

# Notifications
echo "🔔 Notifications"
echo "  1) Telegram"
echo "  2) Slack"
echo "  3) Discord"
echo "  4) Email (SMTP)"
echo "  5) Gotify"
echo "  6) None"
read -p "Choose [1-6] (default: 6): " NOTIF_CHOICE

NOTIF_ENV=""
case "${NOTIF_CHOICE:-6}" in
  1)
    read -p "  Telegram Bot Token: " TG_TOKEN
    read -p "  Telegram Chat ID: " TG_CHAT
    NOTIF_ENV="-e WATCHTOWER_NOTIFICATIONS=shoutrrr -e WATCHTOWER_NOTIFICATION_URL=telegram://${TG_TOKEN}@telegram?channels=${TG_CHAT}"
    echo "  → Telegram notifications enabled"
    ;;
  2)
    read -p "  Slack Webhook URL: " SLACK_URL
    NOTIF_ENV="-e WATCHTOWER_NOTIFICATIONS=shoutrrr -e WATCHTOWER_NOTIFICATION_URL=slack://${SLACK_URL}"
    echo "  → Slack notifications enabled"
    ;;
  3)
    read -p "  Discord Webhook URL: " DISCORD_URL
    NOTIF_ENV="-e WATCHTOWER_NOTIFICATIONS=shoutrrr -e WATCHTOWER_NOTIFICATION_URL=discord://${DISCORD_URL}"
    echo "  → Discord notifications enabled"
    ;;
  4)
    read -p "  SMTP Host: " SMTP_HOST
    read -p "  SMTP Port: " SMTP_PORT
    read -p "  From Email: " SMTP_FROM
    read -p "  To Email: " SMTP_TO
    read -p "  Username: " SMTP_USER
    read -sp "  Password: " SMTP_PASS
    echo ""
    NOTIF_ENV="-e WATCHTOWER_NOTIFICATIONS=shoutrrr -e WATCHTOWER_NOTIFICATION_URL=smtp://${SMTP_USER}:${SMTP_PASS}@${SMTP_HOST}:${SMTP_PORT}/?from=${SMTP_FROM}&to=${SMTP_TO}"
    echo "  → Email notifications enabled"
    ;;
  5)
    read -p "  Gotify URL: " GOTIFY_URL
    read -p "  Gotify Token: " GOTIFY_TOKEN
    NOTIF_ENV="-e WATCHTOWER_NOTIFICATIONS=shoutrrr -e WATCHTOWER_NOTIFICATION_URL=gotify://${GOTIFY_URL}/${GOTIFY_TOKEN}"
    echo "  → Gotify notifications enabled"
    ;;
  6|*)
    echo "  → No notifications"
    ;;
esac

echo ""

# Options
read -p "🔄 Enable rolling restarts (zero-downtime)? (y/N): " ROLLING
ROLLING_ENV=""
if [[ "$ROLLING" =~ ^[Yy]$ ]]; then
  ROLLING_ENV="-e WATCHTOWER_ROLLING_RESTART=true"
fi

read -p "🏷️  Only update labeled containers? (y/N): " LABEL_ONLY
LABEL_ENV=""
if [[ "$LABEL_ONLY" =~ ^[Yy]$ ]]; then
  LABEL_ENV="-e WATCHTOWER_LABEL_ENABLE=true"
  echo "  → Add label: com.centurylinklabs.watchtower.enable=true to containers you want updated"
fi

echo ""
echo "🚀 Starting Watchtower..."
echo ""

# Build and run command
CMD="docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCHTOWER_CLEANUP=true \
  -e WATCHTOWER_SCHEDULE=\"${SCHEDULE}\" \
  ${NOTIF_ENV} \
  ${ROLLING_ENV} \
  ${LABEL_ENV} \
  containrrr/watchtower"

echo "Command:"
echo "$CMD"
echo ""

eval $CMD

echo ""
echo "✅ Watchtower is running!"
echo ""
echo "Useful commands:"
echo "  docker logs watchtower --tail 50     # View logs"
echo "  docker restart watchtower            # Restart"
echo "  docker stop watchtower               # Stop"
echo "  bash scripts/status.sh               # Check status"
echo ""
echo "Schedule: ${SCHEDULE}"
echo "Cleanup: enabled"
echo "Rolling restart: ${ROLLING:-no}"
echo "Label-only mode: ${LABEL_ONLY:-no}"
