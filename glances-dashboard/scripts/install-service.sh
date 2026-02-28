#!/bin/bash
# Install Glances as a systemd service
set -e

if [ "$EUID" -ne 0 ]; then
    echo "⚠️  Run with sudo: sudo bash scripts/install-service.sh"
    exit 1
fi

# Find glances binary
GLANCES_BIN=$(command -v glances 2>/dev/null || echo "/home/$SUDO_USER/.local/bin/glances")
if [ ! -f "$GLANCES_BIN" ]; then
    echo "❌ Glances not found. Run: bash scripts/install.sh first"
    exit 1
fi

PORT=${1:-61208}
BIND=${2:-0.0.0.0}

# Create config directory
CONFIG_DIR="/etc/glances"
mkdir -p "$CONFIG_DIR"

# Copy config if exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../config.yaml" ]; then
    cp "$SCRIPT_DIR/../config.yaml" "$CONFIG_DIR/glances.conf"
    echo "📋 Config copied to $CONFIG_DIR/glances.conf"
fi

# Create systemd service
cat > /etc/systemd/system/glances.service << EOF
[Unit]
Description=Glances System Monitor Web Dashboard
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
ExecStart=$GLANCES_BIN -w -p $PORT -B $BIND --enable-plugin docker -C $CONFIG_DIR/glances.conf
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
systemctl daemon-reload
systemctl enable glances.service
systemctl start glances.service

echo ""
echo "✅ Glances service installed and started!"
echo "   Dashboard: http://$BIND:$PORT"
echo ""
echo "Management commands:"
echo "  sudo systemctl status glances"
echo "  sudo systemctl stop glances"
echo "  sudo systemctl restart glances"
echo "  sudo journalctl -u glances -f"
