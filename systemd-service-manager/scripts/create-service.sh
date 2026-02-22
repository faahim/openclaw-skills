#!/bin/bash
# Systemd Service Creator — creates and optionally enables a systemd service
set -euo pipefail

# Defaults
NAME=""
EXEC_CMD=""
USER_NAME="root"
GROUP_NAME=""
WORKDIR=""
RESTART="on-failure"
RESTART_SEC=5
ENVS=()
ENV_FILE=""
TYPE="simple"
AFTER="network.target"
LIMIT_MEM=""
LIMIT_CPU=""
TIMER=""
ENABLE=false
DESCRIPTION=""

usage() {
  cat <<EOF
Usage: sudo bash create-service.sh --name <name> --exec <command> [options]

Options:
  --name NAME          Service name (required)
  --exec CMD           Command to execute (required)
  --user USER          Run as user (default: root)
  --group GROUP        Run as group (default: same as user)
  --workdir DIR        Working directory
  --restart POLICY     no|on-failure|always (default: on-failure)
  --restart-sec SEC    Seconds between restarts (default: 5)
  --env KEY=VAL        Environment variable (repeatable)
  --env-file PATH      Path to environment file
  --type TYPE          simple|forking|oneshot|notify (default: simple)
  --after UNIT         Start after unit (default: network.target)
  --limit-mem SIZE     Memory limit (e.g., 512M)
  --limit-cpu PCT      CPU quota (e.g., 50%)
  --timer SCHEDULE     Create timer (daily|hourly|weekly|cron expression)
  --enable             Enable and start immediately
  --description DESC   Service description
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --exec) EXEC_CMD="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --group) GROUP_NAME="$2"; shift 2 ;;
    --workdir) WORKDIR="$2"; shift 2 ;;
    --restart) RESTART="$2"; shift 2 ;;
    --restart-sec) RESTART_SEC="$2"; shift 2 ;;
    --env) ENVS+=("$2"); shift 2 ;;
    --env-file) ENV_FILE="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    --after) AFTER="$2"; shift 2 ;;
    --limit-mem) LIMIT_MEM="$2"; shift 2 ;;
    --limit-cpu) LIMIT_CPU="$2"; shift 2 ;;
    --timer) TIMER="$2"; shift 2 ;;
    --enable) ENABLE=true; shift ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "❌ Unknown option: $1"; usage ;;
  esac
done

# Validate required
if [[ -z "$NAME" ]]; then echo "❌ --name is required"; usage; fi
if [[ -z "$EXEC_CMD" ]]; then echo "❌ --exec is required"; usage; fi

# Set defaults
[[ -z "$GROUP_NAME" ]] && GROUP_NAME="$USER_NAME"
[[ -z "$DESCRIPTION" ]] && DESCRIPTION="$NAME managed service"

SERVICE_FILE="/etc/systemd/system/${NAME}.service"

# Check if exists
if [[ -f "$SERVICE_FILE" ]]; then
  echo "⚠️  Service '$NAME' already exists at $SERVICE_FILE"
  read -p "Overwrite? (y/N): " confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Aborted."; exit 0; }
  systemctl stop "$NAME" 2>/dev/null || true
fi

# Build unit file
cat > "$SERVICE_FILE" <<UNIT
[Unit]
Description=$DESCRIPTION
After=$AFTER

[Service]
Type=$TYPE
ExecStart=$EXEC_CMD
User=$USER_NAME
Group=$GROUP_NAME
Restart=$RESTART
RestartSec=$RESTART_SEC
UNIT

# Working directory
if [[ -n "$WORKDIR" ]]; then
  echo "WorkingDirectory=$WORKDIR" >> "$SERVICE_FILE"
fi

# Environment variables
for env in "${ENVS[@]}"; do
  echo "Environment=\"$env\"" >> "$SERVICE_FILE"
done

# Environment file
if [[ -n "$ENV_FILE" ]]; then
  echo "EnvironmentFile=$ENV_FILE" >> "$SERVICE_FILE"
fi

# Resource limits
if [[ -n "$LIMIT_MEM" ]]; then
  echo "MemoryMax=$LIMIT_MEM" >> "$SERVICE_FILE"
fi
if [[ -n "$LIMIT_CPU" ]]; then
  echo "CPUQuota=$LIMIT_CPU" >> "$SERVICE_FILE"
fi

# Standard output to journal
cat >> "$SERVICE_FILE" <<UNIT
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$NAME

[Install]
WantedBy=multi-user.target
UNIT

echo "✅ Service '$NAME' created at $SERVICE_FILE"

# Create timer if requested
if [[ -n "$TIMER" ]]; then
  TIMER_FILE="/etc/systemd/system/${NAME}.timer"

  # Resolve shorthand timers
  case "$TIMER" in
    daily)   ON_CAL="*-*-* 00:00:00" ;;
    hourly)  ON_CAL="*-*-* *:00:00" ;;
    weekly)  ON_CAL="Mon *-*-* 00:00:00" ;;
    *)       ON_CAL="$TIMER" ;;
  esac

  cat > "$TIMER_FILE" <<TIMER
[Unit]
Description=Timer for $NAME

[Timer]
OnCalendar=$ON_CAL
Persistent=true

[Install]
WantedBy=timers.target
TIMER

  echo "✅ Timer created at $TIMER_FILE (schedule: $ON_CAL)"
fi

# Reload daemon
systemctl daemon-reload

# Enable and start
if [[ "$ENABLE" == true ]]; then
  if [[ -n "$TIMER" ]]; then
    systemctl enable "${NAME}.timer"
    systemctl start "${NAME}.timer"
    echo "✅ Timer enabled and started"
  else
    systemctl enable "$NAME"
    systemctl start "$NAME"
    echo "✅ Service enabled (starts on boot)"
    echo "✅ Service started"
  fi
  # Show status
  systemctl status "$NAME" --no-pager -l 2>/dev/null || true
fi

echo ""
echo "Manage with:"
echo "  sudo systemctl status $NAME"
echo "  sudo systemctl restart $NAME"
echo "  journalctl -u $NAME -f"
