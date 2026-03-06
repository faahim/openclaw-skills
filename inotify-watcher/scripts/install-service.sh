#!/bin/bash
# Install inotify-watcher as a systemd service
set -euo pipefail

CONFIG=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
  case $1 in
    --config) CONFIG="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$CONFIG" ]]; then
  echo "Usage: $(basename "$0") --config /path/to/watcher.yaml"
  exit 1
fi

CONFIG=$(realpath "$CONFIG")
MULTI_WATCH=$(realpath "$SCRIPT_DIR/multi-watch.sh")

cat > /tmp/inotify-watcher.service <<EOF
[Unit]
Description=Inotify Watcher — Filesystem Event Monitor
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash ${MULTI_WATCH} --config ${CONFIG}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/inotify-watcher.service /etc/systemd/system/inotify-watcher.service
sudo systemctl daemon-reload
echo "✅ Service installed: /etc/systemd/system/inotify-watcher.service"
echo ""
echo "Commands:"
echo "  sudo systemctl enable --now inotify-watcher   # Start & enable at boot"
echo "  sudo systemctl status inotify-watcher          # Check status"
echo "  sudo journalctl -u inotify-watcher -f          # View logs"
echo "  sudo systemctl stop inotify-watcher            # Stop"
