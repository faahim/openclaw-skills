#!/bin/bash
# Install Directory Watcher as a systemd service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_DIR="${1:-.}"
ON_CHANGE="${2:-echo 'File changed: \$FILE'}"
CONFIG="${3:-}"
SERVICE_NAME="directory-watcher"

# Resolve paths
WATCH_SCRIPT="$SCRIPT_DIR/watch.sh"
WATCH_DIR=$(realpath "$WATCH_DIR")

if [[ ! -f "$WATCH_SCRIPT" ]]; then
  echo "Error: watch.sh not found at $WATCH_SCRIPT"
  exit 1
fi

cat > "/tmp/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Directory Watcher Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash ${WATCH_SCRIPT} --dir ${WATCH_DIR} --on-change "${ON_CHANGE}" --recursive --quiet --log /var/log/${SERVICE_NAME}.log
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "Service file created at /tmp/${SERVICE_NAME}.service"
echo ""
echo "To install:"
echo "  sudo cp /tmp/${SERVICE_NAME}.service /etc/systemd/system/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable --now ${SERVICE_NAME}"
echo ""
echo "To check status:"
echo "  sudo systemctl status ${SERVICE_NAME}"
echo "  journalctl -u ${SERVICE_NAME} -f"
