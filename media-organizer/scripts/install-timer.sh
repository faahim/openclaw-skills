#!/usr/bin/env bash
# Install systemd user timer for Media Organizer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE=""
DEST=""
INTERVAL=30
CONFIG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)   SOURCE="$2"; shift 2 ;;
    --dest)     DEST="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --config)   CONFIG="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$SOURCE" || -z "$DEST" ]]; then
  echo "Usage: $0 --source DIR --dest DIR [--interval MINUTES] [--config FILE]"
  exit 1
fi

ORGANIZE_SCRIPT="${SCRIPT_DIR}/organize.sh"
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"

EXTRA_ARGS=""
[[ -n "$CONFIG" ]] && EXTRA_ARGS="--config $CONFIG"

# Service unit
cat > "$UNIT_DIR/media-organizer.service" <<EOF
[Unit]
Description=Media Organizer — Automatic file sorting

[Service]
Type=oneshot
ExecStart=/bin/bash ${ORGANIZE_SCRIPT} --source ${SOURCE} --dest ${DEST} --incremental ${EXTRA_ARGS}
StandardOutput=journal
StandardError=journal
EOF

# Timer unit
cat > "$UNIT_DIR/media-organizer.timer" <<EOF
[Unit]
Description=Run Media Organizer every ${INTERVAL} minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=${INTERVAL}min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start
systemctl --user daemon-reload
systemctl --user enable media-organizer.timer
systemctl --user start media-organizer.timer

echo "✅ Media Organizer timer installed"
echo "   Interval: every ${INTERVAL} minutes"
echo "   Source:   ${SOURCE}"
echo "   Dest:     ${DEST}"
echo ""
echo "Commands:"
echo "  Status:  systemctl --user status media-organizer.timer"
echo "  Logs:    journalctl --user -u media-organizer.service -f"
echo "  Stop:    systemctl --user stop media-organizer.timer"
echo "  Remove:  systemctl --user disable media-organizer.timer && rm ${UNIT_DIR}/media-organizer.*"
