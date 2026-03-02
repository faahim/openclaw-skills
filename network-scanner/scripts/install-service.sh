#!/bin/bash
# Install Network Scanner as a systemd timer (runs every 30 minutes)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_SCRIPT="$SCRIPT_DIR/scan.sh"
DATA_DIR="${SCAN_DATA_DIR:-$HOME/.network-scanner}"

echo "Installing Network Scanner systemd service..."

# Create service
sudo tee /etc/systemd/system/network-scanner.service > /dev/null <<EOF
[Unit]
Description=Network Scanner — Discover and monitor local network devices
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash $SCAN_SCRIPT --monitor --alert telegram
Environment=SCAN_DATA_DIR=$DATA_DIR
Environment=TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}
Environment=TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID:-}
EOF

# Create timer
sudo tee /etc/systemd/system/network-scanner.timer > /dev/null <<EOF
[Unit]
Description=Run Network Scanner every 30 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now network-scanner.timer

echo "✅ Network Scanner timer installed and started."
echo "   Check status: sudo systemctl status network-scanner.timer"
echo "   View logs:    sudo journalctl -u network-scanner.service"
