#!/bin/bash
set -euo pipefail

# Install Diun as a systemd service

DIUN_CONFIG="${HOME}/.config/diun/diun.yml"
SERVICE_FILE="/etc/systemd/system/diun.service"
ENV_FILE="/etc/diun/env"

if [ ! -f "$DIUN_CONFIG" ]; then
  echo "❌ Config not found at ${DIUN_CONFIG}. Run setup.sh first."
  exit 1
fi

if ! command -v diun &>/dev/null; then
  echo "❌ Diun not installed. Run setup.sh first."
  exit 1
fi

echo "📦 Installing Diun systemd service..."

# Create system config directory
sudo mkdir -p /etc/diun
sudo cp "$DIUN_CONFIG" /etc/diun/diun.yml

# Create env file for secrets
if [ ! -f "$ENV_FILE" ]; then
  sudo tee "$ENV_FILE" > /dev/null << EOF
# Diun environment variables
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-your-bot-token}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID:-your-chat-id}
EOF
  sudo chmod 600 "$ENV_FILE"
  echo "⚠️  Edit secrets in ${ENV_FILE}"
fi

# Create systemd service
sudo tee "$SERVICE_FILE" > /dev/null << 'EOF'
[Unit]
Description=Diun - Docker Image Update Notifier
Documentation=https://crazymax.dev/diun/
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/diun serve --config /etc/diun/diun.yml
Restart=on-failure
RestartSec=30
EnvironmentFile=-/etc/diun/env
# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/var/lib/diun
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
EOF

# Create data directory
sudo mkdir -p /var/lib/diun

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable diun
sudo systemctl start diun

echo ""
echo "✅ Diun service installed and started!"
echo ""
echo "Commands:"
echo "  sudo systemctl status diun    # Check status"
echo "  sudo journalctl -u diun -f    # View logs"
echo "  sudo systemctl restart diun   # Restart"
echo "  sudo systemctl stop diun      # Stop"
