#!/bin/bash
# Manage Meilisearch server lifecycle
set -euo pipefail

MEILI_HOST="${MEILI_HOST:-http://localhost:7700}"
MEILI_MASTER_KEY="${MEILI_MASTER_KEY:-}"
MEILI_DB_PATH="${MEILI_DB_PATH:-/var/lib/meilisearch/data}"
MEILI_DUMP_DIR="${MEILI_DUMP_DIR:-/var/lib/meilisearch/dumps}"
MEILI_PID_FILE="/tmp/meilisearch.pid"

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  start             Start Meilisearch server
  stop              Stop Meilisearch server
  restart           Restart Meilisearch server
  status            Check server status
  logs              Show service logs (systemd)
  install-service   Install as systemd service

Start Options:
  --master-key KEY  Set master API key
  --port PORT       Listen port (default: 7700)
  --env ENV         Environment: development|production (default: production)
  --import-dump F   Import dump file on startup

Service Options:
  --master-key KEY  Master key for service config
  --port PORT       Listen port (default: 7700)
EOF
}

cmd_start() {
  local port=7700 env="production" import_dump="" master_key="$MEILI_MASTER_KEY"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --master-key) master_key="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --env) env="$2"; shift 2 ;;
      --import-dump) import_dump="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  if pgrep -f "meilisearch" >/dev/null 2>&1; then
    echo "⚠️  Meilisearch is already running"
    cmd_status
    return
  fi

  mkdir -p "$MEILI_DB_PATH" "$MEILI_DUMP_DIR" 2>/dev/null || true

  local args=(
    --env "$env"
    --http-addr "0.0.0.0:$port"
    --db-path "$MEILI_DB_PATH"
    --dump-dir "$MEILI_DUMP_DIR"
  )

  [ -n "$master_key" ] && args+=(--master-key "$master_key")
  [ -n "$import_dump" ] && args+=(--import-dump "$import_dump")

  echo "🚀 Starting Meilisearch on port $port (env: $env)..."
  nohup meilisearch "${args[@]}" > /tmp/meilisearch.log 2>&1 &
  echo $! > "$MEILI_PID_FILE"

  sleep 2
  if curl -sf "$MEILI_HOST/health" >/dev/null 2>&1; then
    echo "✅ Meilisearch is running on $MEILI_HOST"
  else
    echo "⏳ Starting up... check logs with: tail -f /tmp/meilisearch.log"
  fi
}

cmd_stop() {
  if [ -f "$MEILI_PID_FILE" ]; then
    kill "$(cat "$MEILI_PID_FILE")" 2>/dev/null && echo "✅ Meilisearch stopped" || echo "⚠️  Process not found"
    rm -f "$MEILI_PID_FILE"
  elif pgrep -f "meilisearch" >/dev/null 2>&1; then
    pkill -f "meilisearch" && echo "✅ Meilisearch stopped"
  else
    echo "ℹ️  Meilisearch is not running"
  fi
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start "$@"
}

cmd_status() {
  if curl -sf "$MEILI_HOST/health" >/dev/null 2>&1; then
    local health
    health=$(curl -sf "$MEILI_HOST/health" | jq -r '.status')
    echo "✅ Meilisearch is running — Status: $health"
    local ver
    ver=$(curl -sf "$MEILI_HOST/version" -H "Authorization: Bearer $MEILI_MASTER_KEY" 2>/dev/null | jq -r '.pkgVersion // "unknown"')
    echo "   Version: $ver"
    echo "   Host: $MEILI_HOST"
  else
    echo "❌ Meilisearch is not running or not reachable at $MEILI_HOST"
  fi
}

cmd_logs() {
  if systemctl is-active meilisearch >/dev/null 2>&1; then
    journalctl -u meilisearch -f --no-pager -n 50
  elif [ -f /tmp/meilisearch.log ]; then
    tail -f /tmp/meilisearch.log
  else
    echo "No logs found"
  fi
}

cmd_install_service() {
  local port=7700 master_key="$MEILI_MASTER_KEY"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --master-key) master_key="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  if [ -z "$master_key" ]; then
    echo "❌ --master-key is required for production service"
    exit 1
  fi

  # Create user
  if ! id meilisearch >/dev/null 2>&1; then
    sudo useradd -r -s /bin/false meilisearch
  fi

  # Create directories
  sudo mkdir -p "$MEILI_DB_PATH" "$MEILI_DUMP_DIR"
  sudo chown -R meilisearch:meilisearch "$(dirname "$MEILI_DB_PATH")"

  # Create systemd service
  sudo tee /etc/systemd/system/meilisearch.service > /dev/null <<UNIT
[Unit]
Description=Meilisearch Search Engine
After=network.target

[Service]
Type=simple
User=meilisearch
Environment=MEILI_MASTER_KEY=$master_key
ExecStart=/usr/local/bin/meilisearch --env production --http-addr 0.0.0.0:$port --db-path $MEILI_DB_PATH --dump-dir $MEILI_DUMP_DIR
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT

  sudo systemctl daemon-reload
  sudo systemctl enable meilisearch
  sudo systemctl start meilisearch

  echo "✅ Meilisearch service installed and started on port $port"
  echo "   Manage with: sudo systemctl {start|stop|restart|status} meilisearch"
}

# Route commands
case "${1:-}" in
  start) shift; cmd_start "$@" ;;
  stop) cmd_stop ;;
  restart) shift; cmd_restart "$@" ;;
  status) cmd_status ;;
  logs) cmd_logs ;;
  install-service) shift; cmd_install_service "$@" ;;
  *) usage; exit 1 ;;
esac
