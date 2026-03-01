#!/bin/bash
# install-monitor.sh — Install cron-monitor as a cron job
set -euo pipefail

INTERVAL=10  # minutes
ALERT_TYPE=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.cron-monitor"

while [[ $# -gt 0 ]]; do
    case $1 in
        --interval) INTERVAL="$2"; shift 2 ;;
        --alert) ALERT_TYPE="$2"; shift 2 ;;
        --uninstall) UNINSTALL=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

UNINSTALL="${UNINSTALL:-false}"

if [[ "$UNINSTALL" = true ]]; then
    echo "Removing cron-monitor from crontab..."
    crontab -l 2>/dev/null | grep -v "cron-monitor" | crontab -
    echo "✅ Removed. Data preserved at $INSTALL_DIR"
    exit 0
fi

# Create install directory
mkdir -p "$INSTALL_DIR"/{scripts,data,logs}

# Copy scripts
cp "$SCRIPT_DIR"/*.sh "$INSTALL_DIR/scripts/"
chmod +x "$INSTALL_DIR/scripts/"*.sh

# Create default config
if [[ ! -f "$INSTALL_DIR/config.yaml" ]]; then
    cat > "$INSTALL_DIR/config.yaml" << 'EOF'
# Cron Monitor Configuration
alerts:
  telegram:
    enabled: false
    bot_token: "${TELEGRAM_BOT_TOKEN}"
    chat_id: "${TELEGRAM_CHAT_ID}"
  webhook:
    enabled: false
    url: ""

monitoring:
  check_interval: 600
  history_window: 3600

thresholds:
  slow_seconds: 300
  miss_tolerance: 2
EOF
fi

# Initial scan
echo "Scanning current crontab..."
bash "$INSTALL_DIR/scripts/scan-crontab.sh"
echo ""

# Add to crontab
CRON_LINE="*/$INTERVAL * * * * CRON_MONITOR_DATA=$INSTALL_DIR/data $INSTALL_DIR/scripts/monitor.sh --once --config $INSTALL_DIR/config.yaml >> $INSTALL_DIR/logs/monitor.log 2>&1"

# Check if already installed
EXISTING=$(crontab -l 2>/dev/null || echo "")
if echo "$EXISTING" | grep -q "cron-monitor"; then
    echo "⚠️  Cron monitor already installed. Updating..."
    EXISTING=$(echo "$EXISTING" | grep -v "cron-monitor")
fi

# Install
(echo "$EXISTING"; echo "# cron-monitor — automated cron job monitoring"; echo "$CRON_LINE") | crontab -

echo ""
echo "✅ Cron Monitor installed!"
echo "   Check interval: every $INTERVAL minutes"
echo "   Config: $INSTALL_DIR/config.yaml"
echo "   Logs: $INSTALL_DIR/logs/monitor.log"
echo "   Data: $INSTALL_DIR/data/"
echo ""

if [[ "$ALERT_TYPE" == "telegram" ]]; then
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        echo "⚠️  Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID environment variables for alerts."
        echo "   Or edit $INSTALL_DIR/config.yaml"
    else
        echo "✅ Telegram alerts configured"
    fi
fi

echo "To uninstall: bash $INSTALL_DIR/scripts/install-monitor.sh --uninstall"
