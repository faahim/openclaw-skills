#!/usr/bin/env bash
# Generate a systemd service unit for a file watcher
set -euo pipefail

NAME=""
WATCH_PATH=""
EVENTS="create,modify,delete"
RUN_CMD=""
RECURSIVE=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --path) WATCH_PATH="$2"; shift 2 ;;
    --events) EVENTS="$2"; shift 2 ;;
    --run) RUN_CMD="$2"; shift 2 ;;
    --recursive) RECURSIVE=true; shift ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$NAME" || -z "$WATCH_PATH" || -z "$RUN_CMD" ]]; then
  echo "Usage: bash install-service.sh --name <name> --path <path> --run '<cmd>' [--events <events>] [--recursive]"
  exit 1
fi

SERVICE_NAME="file-watcher-${NAME}"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

EXEC_ARGS="--path '$WATCH_PATH' --events '$EVENTS' --run '$RUN_CMD'"
[[ "$RECURSIVE" == "true" ]] && EXEC_ARGS+=" --recursive"

cat > "/tmp/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=File Watcher: ${NAME}
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env bash ${SCRIPT_DIR}/watch.sh ${EXEC_ARGS}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

echo "Generated: /tmp/${SERVICE_NAME}.service"
echo ""
echo "To install:"
echo "  sudo cp /tmp/${SERVICE_NAME}.service ${UNIT_FILE}"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable --now ${SERVICE_NAME}"
echo ""
echo "To check:"
echo "  sudo systemctl status ${SERVICE_NAME}"
echo "  journalctl -u ${SERVICE_NAME} -f"
