#!/bin/bash
# Install Process Watchdog as a systemd service
set -euo pipefail

CONFIG_PATH=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
    case $1 in
        --config) CONFIG_PATH="$(realpath "$2")"; shift 2 ;;
        *) echo "Usage: install-service.sh --config /path/to/watchdog.yaml"; exit 1 ;;
    esac
done

if [[ -z "$CONFIG_PATH" ]]; then
    echo "Error: --config is required"
    exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "Error: Config file not found: $CONFIG_PATH"
    exit 1
fi

WATCHDOG_SCRIPT="${SCRIPT_DIR}/watchdog.sh"

cat > /tmp/process-watchdog.service << EOF
[Unit]
Description=Process Watchdog — Auto-restart crashed processes
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash ${WATCHDOG_SCRIPT} --config ${CONFIG_PATH}
Restart=always
RestartSec=10
StandardOutput=append:/var/log/process-watchdog.log
StandardError=append:/var/log/process-watchdog.log

# Environment (override in /etc/default/process-watchdog)
EnvironmentFile=-/etc/default/process-watchdog

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/process-watchdog.service /etc/systemd/system/process-watchdog.service
sudo systemctl daemon-reload
sudo systemctl enable process-watchdog
sudo systemctl start process-watchdog

echo "✅ Process Watchdog installed as systemd service"
echo "   Config: ${CONFIG_PATH}"
echo "   Status: systemctl status process-watchdog"
echo "   Logs:   journalctl -u process-watchdog -f"
echo ""
echo "To set Telegram alerts, create /etc/default/process-watchdog:"
echo '   WATCHDOG_TELEGRAM_TOKEN="your-token"'
echo '   WATCHDOG_TELEGRAM_CHAT="your-chat-id"'
