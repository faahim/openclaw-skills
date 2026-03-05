#!/bin/bash
# Manage step-ca server (start/stop/status/install-service)
set -euo pipefail

STEPPATH="${STEPPATH:-$HOME/.step}"
CA_CONFIG="$STEPPATH/config/ca.json"
PID_FILE="$STEPPATH/step-ca.pid"
LOG_FILE="$STEPPATH/step-ca.log"
PASSWORD_FILE="${STEP_CA_PASSWORD_FILE:-}"

ACTION="${1:-help}"

get_pid() {
  if [ -f "$PID_FILE" ]; then
    local pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
    rm -f "$PID_FILE"
  fi
  # Try pgrep as fallback
  pgrep -f "step-ca.*ca.json" 2>/dev/null || true
}

cmd_start() {
  local pid=$(get_pid)
  if [ -n "$pid" ]; then
    echo "✅ step-ca already running (PID $pid)"
    return 0
  fi

  if [ ! -f "$CA_CONFIG" ]; then
    echo "❌ CA not initialized. Run: bash scripts/setup-ca.sh"
    exit 1
  fi

  echo "🚀 Starting step-ca..."

  local password_arg=""
  if [ -n "$PASSWORD_FILE" ] && [ -f "$PASSWORD_FILE" ]; then
    password_arg="--password-file $PASSWORD_FILE"
  fi

  nohup step-ca "$CA_CONFIG" $password_arg >> "$LOG_FILE" 2>&1 &
  local new_pid=$!
  echo "$new_pid" > "$PID_FILE"

  # Wait for startup
  sleep 2
  if kill -0 "$new_pid" 2>/dev/null; then
    local address=$(jq -r '.address' "$CA_CONFIG")
    echo "✅ step-ca running on $address (PID $new_pid)"
    echo "   Log: $LOG_FILE"
  else
    echo "❌ step-ca failed to start. Check $LOG_FILE"
    tail -5 "$LOG_FILE"
    exit 1
  fi
}

cmd_stop() {
  local pid=$(get_pid)
  if [ -z "$pid" ]; then
    echo "⚠️  step-ca is not running"
    return 0
  fi

  echo "🛑 Stopping step-ca (PID $pid)..."
  kill "$pid" 2>/dev/null || true
  sleep 1

  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
  fi

  rm -f "$PID_FILE"
  echo "✅ step-ca stopped"
}

cmd_status() {
  local pid=$(get_pid)
  if [ -n "$pid" ]; then
    local address=$(jq -r '.address' "$CA_CONFIG" 2>/dev/null || echo "unknown")
    echo "✅ step-ca running on $address (PID $pid)"

    # Health check
    local port=$(echo "$address" | sed 's/.*://')
    if curl -sk "https://localhost:${port}/health" >/dev/null 2>&1; then
      echo "   Health: OK"
    fi

    # Show root cert info
    if [ -f "$STEPPATH/certs/root_ca.crt" ]; then
      local expiry=$(step certificate inspect "$STEPPATH/certs/root_ca.crt" --format json 2>/dev/null | jq -r '.validity.end' 2>/dev/null || echo "unknown")
      echo "   Root CA expires: $expiry"
    fi
  else
    echo "❌ step-ca is not running"
    return 1
  fi
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start
}

cmd_logs() {
  if [ -f "$LOG_FILE" ]; then
    tail -${2:-50} "$LOG_FILE"
  else
    echo "No log file found at $LOG_FILE"
  fi
}

cmd_install_service() {
  if ! command -v systemctl &>/dev/null; then
    echo "❌ systemd not available"
    exit 1
  fi

  local user=$(whoami)
  local step_ca_bin=$(which step-ca)

  cat > /tmp/step-ca.service << EOF
[Unit]
Description=Smallstep Certificate Authority
After=network.target

[Service]
Type=simple
User=$user
Environment=STEPPATH=$STEPPATH
ExecStart=$step_ca_bin $CA_CONFIG ${PASSWORD_FILE:+--password-file $PASSWORD_FILE}
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  sudo mv /tmp/step-ca.service /etc/systemd/system/step-ca.service
  sudo systemctl daemon-reload
  sudo systemctl enable step-ca

  echo "✅ Systemd service installed"
  echo "   Start:  sudo systemctl start step-ca"
  echo "   Status: sudo systemctl status step-ca"
  echo "   Logs:   journalctl -u step-ca -f"
}

case "$ACTION" in
  start)           cmd_start ;;
  stop)            cmd_stop ;;
  status)          cmd_status ;;
  restart)         cmd_restart ;;
  logs)            cmd_logs "$@" ;;
  install-service) cmd_install_service ;;
  *)
    echo "Usage: bash scripts/manage.sh {start|stop|status|restart|logs|install-service}"
    exit 1
    ;;
esac
