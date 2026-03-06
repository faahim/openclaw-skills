#!/bin/bash
# Install file-watcher as a systemd service
set -e

CONFIG_PATH="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$CONFIG_PATH" ]; then
  echo "Usage: bash install-service.sh /path/to/config.yaml"
  exit 1
fi

CONFIG_PATH=$(realpath "$CONFIG_PATH")

cat > /tmp/file-watcher.service <<EOF
[Unit]
Description=File Watcher Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash ${SCRIPT_DIR}/watch.sh --config ${CONFIG_PATH}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/file-watcher.service /etc/systemd/system/file-watcher.service
sudo systemctl daemon-reload
sudo systemctl enable file-watcher

echo "✅ Service installed. Run: sudo systemctl start file-watcher"
