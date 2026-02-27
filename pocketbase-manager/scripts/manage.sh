#!/bin/bash
# PocketBase Instance Manager — init, start, stop, service, upgrade, list
set -euo pipefail

DATA_BASE="/opt/pocketbase"
PB_BIN="/usr/local/bin/pocketbase"
COMMAND=""
NAME=""
PORT="8090"
HOST="0.0.0.0"
LINES=50
FOLLOW=false

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  init      Create a new PocketBase instance
  start     Start an instance (foreground)
  stop      Stop a running instance
  service   Install/manage systemd service
  upgrade   Upgrade PocketBase binary with safety backup
  list      List all managed instances
  logs      View instance logs
  version   Show current vs latest version

Options:
  --name NAME    Instance name (required for most commands)
  --port PORT    Port number (default: 8090)
  --host HOST    Bind address (default: 0.0.0.0)
  --enable       Enable and start systemd service
  --disable      Disable systemd service
  --lines N      Number of log lines (default: 50)
  --follow       Follow logs in real-time
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage
COMMAND="$1"; shift

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --enable) ENABLE=true; shift ;;
    --disable) DISABLE=true; shift ;;
    --lines) LINES="$2"; shift 2 ;;
    --follow) FOLLOW=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

instance_dir() {
  echo "${DATA_BASE}/${NAME}"
}

require_name() {
  if [[ -z "$NAME" ]]; then
    echo "❌ --name is required"; exit 1
  fi
}

cmd_init() {
  require_name
  local dir
  dir=$(instance_dir)

  if [[ -d "$dir/pb_data" ]]; then
    echo "⚠️  Instance '$NAME' already exists at $dir"
    exit 1
  fi

  echo "📦 Initializing PocketBase instance: $NAME"

  sudo mkdir -p "$dir"/{pb_data,pb_migrations,pb_hooks}

  # Create config
  cat > /tmp/pb-config-${NAME}.yaml <<YAML
name: ${NAME}
port: ${PORT}
host: ${HOST}
data_dir: ${dir}/pb_data
backup:
  enabled: false
  schedule: "0 2 * * *"
  dest: /backups/pocketbase
  retention: 30
  s3:
    bucket: ""
    prefix: ""
    endpoint: ""
YAML
  sudo mv /tmp/pb-config-${NAME}.yaml "$dir/config.yaml"

  echo ""
  echo "✅ Instance '$NAME' created at $dir"
  echo "   Port: $PORT"
  echo ""
  echo "Next steps:"
  echo "  bash scripts/manage.sh start --name $NAME"
  echo "  bash scripts/manage.sh service --name $NAME --enable"
}

cmd_start() {
  require_name
  local dir
  dir=$(instance_dir)

  if [[ ! -d "$dir" ]]; then
    echo "❌ Instance '$NAME' not found. Run: manage.sh init --name $NAME"; exit 1
  fi

  echo "🚀 Starting PocketBase '$NAME' on ${HOST}:${PORT}..."
  exec "$PB_BIN" serve --dir "$dir/pb_data" --migrationsDir "$dir/pb_migrations" --hooksDir "$dir/pb_hooks" --http "${HOST}:${PORT}"
}

cmd_stop() {
  require_name
  local service="pocketbase-${NAME}"

  if systemctl is-active --quiet "$service" 2>/dev/null; then
    sudo systemctl stop "$service"
    echo "✅ Stopped $service"
  else
    # Try killing by port
    local pid
    pid=$(lsof -ti :${PORT} 2>/dev/null || true)
    if [[ -n "$pid" ]]; then
      kill "$pid"
      echo "✅ Killed PocketBase process (PID: $pid)"
    else
      echo "⚠️  No running instance found for '$NAME'"
    fi
  fi
}

cmd_service() {
  require_name
  local dir service_name unit_file
  dir=$(instance_dir)
  service_name="pocketbase-${NAME}"
  unit_file="/etc/systemd/system/${service_name}.service"

  if [[ "${DISABLE:-false}" == "true" ]]; then
    sudo systemctl disable --now "$service_name" 2>/dev/null || true
    echo "✅ Service $service_name disabled"
    return
  fi

  # Create systemd unit
  cat > /tmp/${service_name}.service <<UNIT
[Unit]
Description=PocketBase ($NAME)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=${PB_BIN} serve --dir ${dir}/pb_data --migrationsDir ${dir}/pb_migrations --hooksDir ${dir}/pb_hooks --http ${HOST}:${PORT}
Restart=on-failure
RestartSec=5s
LimitNOFILE=4096
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

  sudo mv /tmp/${service_name}.service "$unit_file"
  sudo systemctl daemon-reload

  if [[ "${ENABLE:-false}" == "true" ]]; then
    sudo systemctl enable --now "$service_name"
    echo "✅ Service $service_name enabled and started"
    echo "   Status: $(systemctl is-active $service_name)"
    echo "   Logs:   sudo journalctl -u $service_name -f"
  else
    echo "✅ Service $service_name created"
    echo "   Enable: sudo systemctl enable --now $service_name"
  fi
}

cmd_upgrade() {
  require_name
  local dir
  dir=$(instance_dir)

  echo "⬆️  Upgrading PocketBase for instance '$NAME'..."

  # 1. Backup current data
  echo "📦 Creating safety backup..."
  local backup_file="/tmp/pocketbase-${NAME}-pre-upgrade-$(date +%Y%m%d%H%M%S).zip"
  cd "$dir" && zip -qr "$backup_file" pb_data/ 2>/dev/null || true
  echo "   Backup: $backup_file"

  # 2. Download latest
  echo "⬇️  Downloading latest version..."
  bash "$(dirname "$0")/install.sh"

  # 3. Restart service
  local service="pocketbase-${NAME}"
  if systemctl is-active --quiet "$service" 2>/dev/null; then
    sudo systemctl restart "$service"
    sleep 2
    if systemctl is-active --quiet "$service"; then
      echo "✅ Upgrade complete. Service is running."
    else
      echo "❌ Service failed to start after upgrade!"
      echo "   Restore backup: $backup_file"
      exit 1
    fi
  else
    echo "✅ Binary upgraded. Restart manually."
  fi
}

cmd_list() {
  echo "PocketBase Instances"
  echo "─────────────────────────────────────────────────────"
  printf "%-15s %-6s %-10s %-10s %-15s\n" "NAME" "PORT" "STATUS" "DB_SIZE" "UPTIME"
  echo "─────────────────────────────────────────────────────"

  for dir in "$DATA_BASE"/*/; do
    [[ -d "$dir" ]] || continue
    local name
    name=$(basename "$dir")
    local port="?"
    local status="stopped"
    local db_size="-"
    local uptime="-"

    # Read config
    if [[ -f "$dir/config.yaml" ]]; then
      port=$(grep -oP 'port:\s*\K\d+' "$dir/config.yaml" 2>/dev/null || echo "?")
    fi

    # Check systemd service
    local service="pocketbase-${name}"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
      status="running"
      uptime=$(systemctl show "$service" --property=ActiveEnterTimestamp --value 2>/dev/null | xargs -I{} date -d "{}" +%s 2>/dev/null || echo "")
      if [[ -n "$uptime" ]]; then
        local now
        now=$(date +%s)
        local diff=$((now - uptime))
        if [[ $diff -gt 86400 ]]; then
          uptime="$((diff / 86400))d $((diff % 86400 / 3600))h"
        elif [[ $diff -gt 3600 ]]; then
          uptime="$((diff / 3600))h $((diff % 3600 / 60))m"
        else
          uptime="$((diff / 60))m"
        fi
      fi
    fi

    # DB size
    if [[ -f "$dir/pb_data/data.db" ]]; then
      db_size=$(du -sh "$dir/pb_data/data.db" 2>/dev/null | cut -f1 || echo "-")
    fi

    printf "%-15s %-6s %-10s %-10s %-15s\n" "$name" "$port" "$status" "$db_size" "$uptime"
  done
}

cmd_logs() {
  require_name
  local service="pocketbase-${NAME}"

  if [[ "$FOLLOW" == "true" ]]; then
    sudo journalctl -u "$service" -f
  else
    sudo journalctl -u "$service" -n "$LINES" --no-pager
  fi
}

cmd_version() {
  local current latest
  current=$("$PB_BIN" --version 2>/dev/null | grep -oP '[\d.]+' || echo "not installed")
  latest=$(curl -s https://api.github.com/repos/pocketbase/pocketbase/releases/latest | jq -r '.tag_name' | sed 's/^v//')

  echo "Current: v${current}"
  echo "Latest:  v${latest}"

  if [[ "$current" == "$latest" ]]; then
    echo "✅ Up to date"
  else
    echo "⬆️  Upgrade available: bash scripts/manage.sh upgrade --name <name>"
  fi
}

case "$COMMAND" in
  init) cmd_init ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  service) cmd_service ;;
  upgrade) cmd_upgrade ;;
  list) cmd_list ;;
  logs) cmd_logs ;;
  version) cmd_version ;;
  *) echo "Unknown command: $COMMAND"; usage ;;
esac
