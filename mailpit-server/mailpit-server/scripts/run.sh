#!/bin/bash
# Manage Mailpit server - start, stop, status, test
set -euo pipefail

SMTP_PORT="${MAILPIT_SMTP_PORT:-1025}"
HTTP_PORT="${MAILPIT_HTTP_PORT:-8025}"
MAX_MESSAGES="${MAILPIT_MAX_MESSAGES:-500}"
DB_PATH="${MAILPIT_DB_PATH:-}"
PID_FILE="${HOME}/.local/share/mailpit/mailpit.pid"
LOG_FILE="${HOME}/.local/share/mailpit/mailpit.log"

# Find mailpit binary
MAILPIT_BIN=""
for p in "$HOME/.local/bin/mailpit" "$(which mailpit 2>/dev/null)" "/usr/local/bin/mailpit"; do
  if [ -x "$p" ] 2>/dev/null; then
    MAILPIT_BIN="$p"
    break
  fi
done

if [ -z "$MAILPIT_BIN" ]; then
  echo "❌ Mailpit not found. Run: bash scripts/install.sh"
  exit 1
fi

mkdir -p "$(dirname "$PID_FILE")"

get_pid() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
    rm -f "$PID_FILE"
  fi
  return 1
}

cmd_start() {
  if pid=$(get_pid); then
    echo "✅ Mailpit already running (PID: $pid)"
    echo "   SMTP: localhost:$SMTP_PORT"
    echo "   Web:  http://localhost:$HTTP_PORT"
    return 0
  fi

  local args=(
    "--smtp" "0.0.0.0:$SMTP_PORT"
    "--listen" "0.0.0.0:$HTTP_PORT"
    "--max" "$MAX_MESSAGES"
  )

  if [ -n "$DB_PATH" ]; then
    mkdir -p "$(dirname "$DB_PATH")"
    args+=("--db-file" "$DB_PATH")
  fi

  # Parse extra args
  shift 2>/dev/null || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --smtp-port) SMTP_PORT="$2"; args[1]="0.0.0.0:$2"; shift 2 ;;
      --http-port) HTTP_PORT="$2"; args[3]="0.0.0.0:$2"; shift 2 ;;
      --max) args[5]="$2"; shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done

  echo "🚀 Starting Mailpit..."
  nohup "$MAILPIT_BIN" "${args[@]}" > "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"

  sleep 1
  if pid=$(get_pid); then
    echo "✅ Mailpit started (PID: $pid)"
    echo "   SMTP: localhost:$SMTP_PORT"
    echo "   Web:  http://localhost:$HTTP_PORT"
  else
    echo "❌ Mailpit failed to start. Check $LOG_FILE"
    tail -5 "$LOG_FILE" 2>/dev/null
    exit 1
  fi
}

cmd_stop() {
  if pid=$(get_pid); then
    kill "$pid"
    rm -f "$PID_FILE"
    echo "🛑 Mailpit stopped (PID: $pid)"
  else
    echo "ℹ️  Mailpit is not running"
  fi
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start "$@"
}

cmd_status() {
  if pid=$(get_pid); then
    echo "✅ Mailpit running (PID: $pid)"
    echo "   SMTP: localhost:$SMTP_PORT"
    echo "   Web:  http://localhost:$HTTP_PORT"

    # Check message count
    local count
    count=$(curl -s "http://localhost:$HTTP_PORT/api/v1/messages?limit=0" 2>/dev/null | grep -o '"messages_count":[0-9]*' | cut -d: -f2 || echo "?")
    echo "   Messages: $count"
  else
    echo "❌ Mailpit is not running"
    return 1
  fi
}

cmd_test() {
  echo "📧 Sending test email to Mailpit..."

  local msg="From: test@example.com\r\nTo: user@example.com\r\nSubject: Mailpit Test $(date '+%H:%M:%S')\r\nContent-Type: text/html\r\n\r\n<h1>It works!</h1><p>Mailpit caught this email at $(date).</p>"

  if echo -e "$msg" | curl -s "smtp://localhost:$SMTP_PORT" \
    --mail-from "test@example.com" \
    --mail-rcpt "user@example.com" \
    -T - 2>/dev/null; then
    echo "✅ Test email sent! Check http://localhost:$HTTP_PORT"
  else
    echo "❌ Failed to send. Is Mailpit running? (bash scripts/run.sh start)"
    exit 1
  fi
}

cmd_clear() {
  curl -s -X DELETE "http://localhost:$HTTP_PORT/api/v1/messages" > /dev/null 2>&1
  echo "🗑️  All messages deleted"
}

cmd_install_service() {
  local service_dir="$HOME/.config/systemd/user"
  mkdir -p "$service_dir"

  cat > "$service_dir/mailpit.service" << EOF
[Unit]
Description=Mailpit Email Testing Server
After=network.target

[Service]
Type=simple
ExecStart=$MAILPIT_BIN --smtp 0.0.0.0:$SMTP_PORT --listen 0.0.0.0:$HTTP_PORT --max $MAX_MESSAGES
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable mailpit
  systemctl --user start mailpit

  echo "✅ Mailpit systemd service installed and started"
  echo "   Manage with: systemctl --user {start|stop|status|restart} mailpit"
}

# Route commands
case "${1:-help}" in
  start)   shift; cmd_start "$@" ;;
  stop)    cmd_stop ;;
  restart) shift; cmd_restart "$@" ;;
  status)  cmd_status ;;
  test)    cmd_test ;;
  clear)   cmd_clear ;;
  install-service) cmd_install_service ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|test|clear|install-service}"
    echo ""
    echo "Commands:"
    echo "  start    Start Mailpit in background"
    echo "  stop     Stop Mailpit"
    echo "  restart  Restart Mailpit"
    echo "  status   Check if running + message count"
    echo "  test     Send a test email"
    echo "  clear    Delete all caught messages"
    echo "  install-service  Install as systemd user service"
    echo ""
    echo "Options (for start/restart):"
    echo "  --smtp-port PORT   SMTP port (default: 1025)"
    echo "  --http-port PORT   Web UI port (default: 8025)"
    echo "  --max N            Max stored messages (default: 500)"
    ;;
esac
