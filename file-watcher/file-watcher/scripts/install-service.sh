#!/bin/bash
# Install File Watcher as a systemd service
set -euo pipefail

NAME=""
DIR=""
EVENTS="modify,create,delete,move"
ON_CHANGE=""
DEBOUNCE=1
EXT=""
EXCLUDE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --events) EVENTS="$2"; shift 2 ;;
    --on-change) ON_CHANGE="$2"; shift 2 ;;
    --debounce) DEBOUNCE="$2"; shift 2 ;;
    --ext) EXT="$2"; shift 2 ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$NAME" || -z "$DIR" || -z "$ON_CHANGE" ]]; then
  echo "Usage: $0 --name <service-name> --dir <path> --on-change <command>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="file-watcher-${NAME}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

WATCH_CMD="$SCRIPT_DIR/watch.sh --dir $DIR --events $EVENTS --on-change '$ON_CHANGE' --debounce $DEBOUNCE"
[[ -n "$EXT" ]] && WATCH_CMD+=" --ext $EXT"
[[ -n "$EXCLUDE" ]] && WATCH_CMD+=" --exclude '$EXCLUDE'"

cat > /tmp/${SERVICE_NAME}.service <<EOF
[Unit]
Description=File Watcher: $NAME
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c '$WATCH_CMD'
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/${SERVICE_NAME}.service "$SERVICE_FILE"
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

echo "✅ Service '$SERVICE_NAME' installed and started"
echo "   Status: sudo systemctl status $SERVICE_NAME"
echo "   Logs:   sudo journalctl -u $SERVICE_NAME -f"
echo "   Stop:   sudo systemctl stop $SERVICE_NAME"
echo "   Remove: sudo systemctl disable $SERVICE_NAME && sudo rm $SERVICE_FILE"
