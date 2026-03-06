#!/bin/bash
# Install Folder Watcher as a systemd service
set -e

CONFIG=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
  case $1 in
    --config) CONFIG="$(realpath "$2")"; shift 2 ;;
    *) echo "Usage: install-service.sh --config /path/to/config.yaml"; exit 1 ;;
  esac
done

if [[ -z "$CONFIG" ]]; then
  echo "❌ --config required"
  exit 1
fi

WATCH_SCRIPT="$SCRIPT_DIR/watch.sh"
SERVICE_NAME="folder-watcher"

cat > /tmp/${SERVICE_NAME}.service << EOF
[Unit]
Description=Folder Watcher — File system event monitor
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $WATCH_SCRIPT --config $CONFIG
Restart=on-failure
RestartSec=5
User=$USER
Environment=HOME=$HOME

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/${SERVICE_NAME}.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl start ${SERVICE_NAME}

echo "✅ Folder Watcher service installed and started"
echo "   Status: sudo systemctl status ${SERVICE_NAME}"
echo "   Logs:   sudo journalctl -u ${SERVICE_NAME} -f"
