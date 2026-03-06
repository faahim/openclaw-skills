#!/bin/bash
# Typesense Server Control Script
set -e

INSTALL_DIR="${TYPESENSE_DIR:-$HOME/.typesense}"
BIN="$INSTALL_DIR/bin/typesense-server"
CONFIG="$INSTALL_DIR/config.ini"
PID_FILE="$INSTALL_DIR/typesense.pid"
LOG_DIR="$INSTALL_DIR/logs"

# Load config
load_config() {
  if [ ! -f "$CONFIG" ]; then
    echo "❌ Config not found: $CONFIG"
    echo "   Run: bash scripts/install.sh first"
    exit 1
  fi
  API_KEY=$(grep "api-key" "$CONFIG" | cut -d'=' -f2 | tr -d ' ')
  API_PORT=$(grep "api-port" "$CONFIG" | cut -d'=' -f2 | tr -d ' ')
  DATA_DIR=$(grep "data-dir" "$CONFIG" | cut -d'=' -f2 | tr -d ' ')
  API_PORT="${API_PORT:-8108}"
  export TYPESENSE_API_KEY="$API_KEY"
  export TYPESENSE_PORT="$API_PORT"
}

is_running() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      return 0
    fi
    rm -f "$PID_FILE"
  fi
  return 1
}

cmd_start() {
  load_config
  if is_running; then
    echo "⚠️  Typesense already running (PID: $(cat "$PID_FILE"))"
    return
  fi
  if [ ! -f "$BIN" ]; then
    echo "❌ Typesense binary not found. Run: bash scripts/install.sh"
    exit 1
  fi
  echo "🚀 Starting Typesense on port $API_PORT..."
  mkdir -p "$LOG_DIR"
  nohup "$BIN" \
    --data-dir "$DATA_DIR" \
    --api-key "$API_KEY" \
    --api-port "$API_PORT" \
    --enable-cors \
    --log-dir "$LOG_DIR" \
    > "$LOG_DIR/stdout.log" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 2
  if is_running; then
    echo "✅ Typesense started (PID: $(cat "$PID_FILE"))"
    echo "   URL: http://localhost:$API_PORT"
    echo "   API Key: $API_KEY"
  else
    echo "❌ Failed to start. Check logs: $LOG_DIR/stdout.log"
    cat "$LOG_DIR/stdout.log" 2>/dev/null | tail -20
    exit 1
  fi
}

cmd_stop() {
  if ! is_running; then
    echo "ℹ️  Typesense is not running"
    return
  fi
  PID=$(cat "$PID_FILE")
  echo "🛑 Stopping Typesense (PID: $PID)..."
  kill "$PID"
  sleep 2
  if kill -0 "$PID" 2>/dev/null; then
    echo "   Forcing stop..."
    kill -9 "$PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
  echo "✅ Typesense stopped"
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start
}

cmd_status() {
  load_config
  if is_running; then
    PID=$(cat "$PID_FILE")
    echo "✅ Typesense is running (PID: $PID, port: $API_PORT)"
    # Check health
    HEALTH=$(curl -s "http://localhost:$API_PORT/health" 2>/dev/null || echo '{"error":"unreachable"}')
    echo "   Health: $HEALTH"
    # Show collections count
    COLLECTIONS=$(curl -s -H "X-TYPESENSE-API-KEY: $API_KEY" "http://localhost:$API_PORT/collections" 2>/dev/null | jq 'length' 2>/dev/null || echo "?")
    echo "   Collections: $COLLECTIONS"
  else
    echo "❌ Typesense is not running"
  fi
}

cmd_health() {
  load_config
  curl -sf "http://localhost:$API_PORT/health" 2>/dev/null && echo "" || echo '{"ok":false,"error":"Server unreachable"}'
}

cmd_logs() {
  LINES="${2:-50}"
  if [ -f "$LOG_DIR/stdout.log" ]; then
    tail -n "$LINES" "$LOG_DIR/stdout.log"
  else
    echo "No logs found at $LOG_DIR/"
  fi
}

cmd_install_service() {
  load_config
  if [ "$(uname -s)" != "Linux" ]; then
    echo "❌ Systemd services only supported on Linux"
    exit 1
  fi
  SERVICE_FILE="/etc/systemd/system/typesense.service"
  echo "📝 Creating systemd service..."
  sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Typesense Search Engine
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=$BIN --data-dir $DATA_DIR --api-key $API_KEY --api-port $API_PORT --enable-cors --log-dir $LOG_DIR
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable typesense
  sudo systemctl start typesense
  echo "✅ Typesense service installed and started"
  echo "   Status: sudo systemctl status typesense"
}

case "${1:-help}" in
  start)           cmd_start ;;
  stop)            cmd_stop ;;
  restart)         cmd_restart ;;
  status)          cmd_status ;;
  health)          cmd_health ;;
  logs)            cmd_logs "$@" ;;
  install-service) cmd_install_service ;;
  *)
    echo "Usage: bash run.sh <command>"
    echo ""
    echo "Commands:"
    echo "  start            Start Typesense server"
    echo "  stop             Stop Typesense server"
    echo "  restart          Restart Typesense server"
    echo "  status           Show server status"
    echo "  health           Quick health check"
    echo "  logs [N]         Show last N log lines (default: 50)"
    echo "  install-service  Install as systemd service"
    ;;
esac
