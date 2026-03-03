#!/bin/bash
# Install file-watcher as a systemd service
set -euo pipefail

CONFIG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --config) CONFIG="$2"; shift 2 ;;
        *) echo "Usage: bash install-service.sh --config /path/to/config.yaml"; exit 1 ;;
    esac
done

if [[ -z "$CONFIG" ]]; then
    echo "Error: --config required"
    exit 1
fi

CONFIG=$(realpath "$CONFIG")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_SCRIPT=$(realpath "$SCRIPT_DIR/watch.sh")

cat > /tmp/file-watcher.service <<EOF
[Unit]
Description=File Watcher & Trigger
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash ${WATCH_SCRIPT} --config ${CONFIG}
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
