#!/bin/bash
# Install USB Monitor as a systemd service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="usb-monitor"

# Check root
if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash $0"
  exit 1
fi

# Create service file
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=USB Device Monitor
After=multi-user.target

[Service]
Type=simple
ExecStart=/bin/bash ${SCRIPT_DIR}/usb-monitor.sh --log /var/log/usb-monitor.log
Restart=on-failure
RestartSec=5
Environment=USB_ALERT_TYPE=none
# Uncomment and set for Telegram alerts:
# Environment=USB_ALERT_TYPE=telegram
# Environment=TELEGRAM_BOT_TOKEN=your-token
# Environment=TELEGRAM_CHAT_ID=your-chat-id

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}"

echo "✅ USB Monitor service installed and started"
echo "   Status: sudo systemctl status ${SERVICE_NAME}"
echo "   Logs:   sudo journalctl -u ${SERVICE_NAME} -f"
echo "   Config: /etc/systemd/system/${SERVICE_NAME}.service"
