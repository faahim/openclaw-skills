#!/bin/bash
# Add a service monitor to Monit
set -e

# Defaults
NAME=""
PIDFILE=""
MATCH=""
START_CMD=""
STOP_CMD=""
CHECK_URL=""
CHECK_STATUS="200"
CHECK_TIMEOUT="10"
CPU_LIMIT="80"
MEM_LIMIT="256"
RESTART_LIMIT="3"
RESTART_CYCLES="5"

usage() {
  cat <<EOF
Usage: $0 --name <name> [options]

Required:
  --name          Service name (alphanumeric, no spaces)
  --start         Start command
  --stop          Stop command

Process detection (one required):
  --pidfile       Path to PID file
  --match         Process name pattern to match

Optional:
  --check-url     HTTP URL to health check
  --check-status  Expected HTTP status (default: 200)
  --check-timeout Timeout in seconds (default: 10)
  --cpu-limit     CPU % alert threshold (default: 80)
  --mem-limit     Memory MB alert threshold (default: 256)
  --restart-limit Max restarts before alerting (default: 3)
  --restart-cycles  Within N cycles (default: 5)

Example:
  $0 --name nginx --pidfile /var/run/nginx.pid \\
     --start "/usr/sbin/nginx" --stop "/usr/sbin/nginx -s stop" \\
     --check-url "http://localhost:80"
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --pidfile) PIDFILE="$2"; shift 2 ;;
    --match) MATCH="$2"; shift 2 ;;
    --start) START_CMD="$2"; shift 2 ;;
    --stop) STOP_CMD="$2"; shift 2 ;;
    --check-url) CHECK_URL="$2"; shift 2 ;;
    --check-status) CHECK_STATUS="$2"; shift 2 ;;
    --check-timeout) CHECK_TIMEOUT="$2"; shift 2 ;;
    --cpu-limit) CPU_LIMIT="$2"; shift 2 ;;
    --mem-limit) MEM_LIMIT="$2"; shift 2 ;;
    --restart-limit) RESTART_LIMIT="$2"; shift 2 ;;
    --restart-cycles) RESTART_CYCLES="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Validate
if [ -z "$NAME" ]; then echo "❌ --name is required"; usage; fi
if [ -z "$START_CMD" ]; then echo "❌ --start is required"; usage; fi
if [ -z "$STOP_CMD" ]; then echo "❌ --stop is required"; usage; fi
if [ -z "$PIDFILE" ] && [ -z "$MATCH" ]; then echo "❌ Either --pidfile or --match is required"; usage; fi

CONF_DIR="/etc/monit/conf.d"
CONF_FILE="$CONF_DIR/$NAME.conf"

if [ -f "$CONF_FILE" ]; then
  echo "⚠️  Service '$NAME' already exists at $CONF_FILE"
  read -p "Overwrite? (y/N): " CONFIRM
  if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
  fi
fi

# Build config
CONFIG=""

if [ -n "$PIDFILE" ]; then
  CONFIG="check process $NAME with pidfile $PIDFILE"
else
  CONFIG="check process $NAME matching \"$MATCH\""
fi

CONFIG="$CONFIG
  start program = \"$START_CMD\"
  stop program  = \"$STOP_CMD\""

# HTTP health check
if [ -n "$CHECK_URL" ]; then
  # Parse URL components
  PROTO=$(echo "$CHECK_URL" | grep -oP '^https?' || echo "http")
  HOST=$(echo "$CHECK_URL" | sed -E 's|https?://||' | cut -d: -f1 | cut -d/ -f1)
  PORT=$(echo "$CHECK_URL" | grep -oP ':\K[0-9]+' | head -1)
  PATH=$(echo "$CHECK_URL" | sed -E 's|https?://[^/]+(/.*)|\1|' || echo "/")

  [ -z "$PORT" ] && { [ "$PROTO" = "https" ] && PORT=443 || PORT=80; }
  [ "$PATH" = "$CHECK_URL" ] && PATH="/"

  CONFIG="$CONFIG
  if failed
    host $HOST port $PORT protocol $PROTO
    request \"$PATH\"
    with timeout $CHECK_TIMEOUT seconds
    then restart"
fi

# Resource limits
CONFIG="$CONFIG
  if $RESTART_LIMIT restarts within $RESTART_CYCLES cycles then alert
  if cpu > ${CPU_LIMIT}% for 5 cycles then alert
  if memory > ${MEM_LIMIT} MB then alert"

# Write config
echo "$CONFIG" | sudo tee "$CONF_FILE" >/dev/null
sudo chmod 644 "$CONF_FILE"

echo "✅ Service monitor '$NAME' created at $CONF_FILE"
echo ""
echo "Configuration:"
echo "---"
cat "$CONF_FILE"
echo "---"

# Validate and reload
if sudo monit -t 2>/dev/null; then
  echo "✅ Config valid"
  sudo monit reload 2>/dev/null
  echo "🔄 Monit reloaded"
else
  echo "❌ Config validation failed — check syntax"
  echo "Review: $CONF_FILE"
  exit 1
fi

echo ""
echo "Check status: sudo monit status $NAME"
