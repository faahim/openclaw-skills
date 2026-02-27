#!/bin/bash
set -euo pipefail

# Install Litestream as a systemd service

CONFIG_PATH="${1:-/etc/litestream.yml}"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "❌ Config not found at $CONFIG_PATH"
  echo "Usage: bash install-service.sh [config-path]"
  exit 1
fi

if ! command -v litestream &>/dev/null; then
  echo "❌ Litestream not installed. Run install.sh first."
  exit 1
fi

LITESTREAM_BIN=$(which litestream)

cat > /tmp/litestream.service << EOF
[Unit]
Description=Litestream SQLite Replication
After=network.target
Documentation=https://litestream.io

[Service]
Type=simple
User=root
ExecStart=${LITESTREAM_BIN} replicate -config ${CONFIG_PATH}
Restart=always
RestartSec=5
EnvironmentFile=-/etc/default/litestream

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/litestream.service /etc/systemd/system/litestream.service

# Create env file if it doesn't exist
if [ ! -f /etc/default/litestream ]; then
  sudo bash -c 'cat > /etc/default/litestream << ENVEOF
LITESTREAM_ACCESS_KEY_ID=
LITESTREAM_SECRET_ACCESS_KEY=
ENVEOF'
  echo "⚠️ Edit /etc/default/litestream with your S3 credentials"
fi

sudo systemctl daemon-reload
sudo systemctl enable litestream

echo "✅ Litestream systemd service installed"
echo "   Config: $CONFIG_PATH"
echo "   Env: /etc/default/litestream"
echo ""
echo "Start with: sudo systemctl start litestream"
echo "Status:     sudo systemctl status litestream"
echo "Logs:       sudo journalctl -u litestream -f"
