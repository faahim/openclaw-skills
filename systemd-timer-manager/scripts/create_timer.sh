#!/usr/bin/env bash
set -euo pipefail

NAME=""
COMMAND=""
ON_CALENDAR=""
ON_BOOT_SEC=""
UNIT_DIR="/etc/systemd/system"

usage() {
  cat <<USAGE
Usage:
  $0 --name <name> --command '<shell command>' [--on-calendar '<expr>' | --on-boot-sec '<duration>']

Examples:
  $0 --name backup-db --command '/usr/local/bin/backup.sh' --on-calendar 'daily'
  $0 --name warm-cache --command '/usr/local/bin/warm.sh' --on-calendar '*/10 * * * *'
  $0 --name startup-sync --command '/usr/local/bin/sync.sh' --on-boot-sec '5min'
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2;;
    --command) COMMAND="$2"; shift 2;;
    --on-calendar) ON_CALENDAR="$2"; shift 2;;
    --on-boot-sec) ON_BOOT_SEC="$2"; shift 2;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

[[ -n "$NAME" && -n "$COMMAND" ]] || { usage; exit 1; }
[[ -n "$ON_CALENDAR" || -n "$ON_BOOT_SEC" ]] || { echo "Set either --on-calendar or --on-boot-sec"; exit 1; }

SERVICE_FILE="$UNIT_DIR/${NAME}.service"
TIMER_FILE="$UNIT_DIR/${NAME}.timer"

SERVICE_CONTENT="[Unit]
Description=${NAME} service managed by Systemd Timer Manager

[Service]
Type=oneshot
ExecStart=/bin/bash -lc ${COMMAND@Q}
"

TIMER_CONTENT="[Unit]
Description=${NAME} timer managed by Systemd Timer Manager

[Timer]
Persistent=true
"

if [[ -n "$ON_CALENDAR" ]]; then
  TIMER_CONTENT+="OnCalendar=$ON_CALENDAR
"
fi
if [[ -n "$ON_BOOT_SEC" ]]; then
  TIMER_CONTENT+="OnBootSec=$ON_BOOT_SEC
"
fi

TIMER_CONTENT+="Unit=${NAME}.service

[Install]
WantedBy=timers.target
"

echo "Creating $SERVICE_FILE and $TIMER_FILE"
echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" >/dev/null
echo "$TIMER_CONTENT" | sudo tee "$TIMER_FILE" >/dev/null

sudo systemctl daemon-reload
sudo systemctl enable --now "${NAME}.timer"

echo "✅ Timer created: ${NAME}.timer"
systemctl status "${NAME}.timer" --no-pager --lines=0 || true
systemctl list-timers --all | grep "$NAME" || true
