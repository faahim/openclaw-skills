#!/bin/bash
# Dagu Workflow Engine — Management Script
# Usage: bash manage.sh <command> [options]

set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/dagu}"
CONFIG_FILE="$CONFIG_DIR/admin.yaml"
DAGS_DIR="${DAGS_DIR:-$CONFIG_DIR/dags}"
DAGU_BIN="${DAGU_BIN:-$(command -v dagu 2>/dev/null || echo "$HOME/.local/bin/dagu")}"
DAGU_PID_FILE="$CONFIG_DIR/.dagu.pid"

if [ ! -x "$DAGU_BIN" ]; then
  echo "❌ Dagu not found. Run: bash scripts/install.sh"
  exit 1
fi

usage() {
  cat << 'EOF'
Dagu Workflow Engine Manager

Usage: bash manage.sh <command> [options]

Commands:
  start              Start the Dagu server (dashboard + scheduler)
  stop               Stop the Dagu server
  restart            Restart the Dagu server
  status [dag-name]  Show server status or DAG status
  list               List all DAGs
  run <dag-name>     Run a specific DAG
  dry-run <dag-name> Validate a DAG without executing
  history <dag-name> Show execution history
  export <dir>       Export all DAGs to a directory
  import <dir>       Import DAGs from a directory
  logs [dag-name]    View logs (server or specific DAG)

Examples:
  bash manage.sh start
  bash manage.sh run backup-pipeline
  bash manage.sh history my-workflow
  bash manage.sh export /tmp/dags-backup
EOF
}

cmd_start() {
  if [ -f "$DAGU_PID_FILE" ] && kill -0 "$(cat "$DAGU_PID_FILE")" 2>/dev/null; then
    echo "⚠️  Dagu is already running (PID: $(cat "$DAGU_PID_FILE"))"
    echo "   Dashboard: http://localhost:$(grep -oP 'port:\s*\K\d+' "$CONFIG_FILE" 2>/dev/null || echo 8080)"
    return 0
  fi

  echo "🚀 Starting Dagu server..."
  nohup "$DAGU_BIN" server --config="$CONFIG_FILE" > "$CONFIG_DIR/logs/server.log" 2>&1 &
  echo $! > "$DAGU_PID_FILE"
  
  sleep 2
  
  if kill -0 "$(cat "$DAGU_PID_FILE")" 2>/dev/null; then
    PORT=$(grep -oP 'port:\s*\K\d+' "$CONFIG_FILE" 2>/dev/null || echo 8080)
    echo "✅ Dagu started (PID: $(cat "$DAGU_PID_FILE"))"
    echo "   Dashboard: http://localhost:$PORT"
  else
    echo "❌ Dagu failed to start. Check: $CONFIG_DIR/logs/server.log"
    rm -f "$DAGU_PID_FILE"
    exit 1
  fi
}

cmd_stop() {
  if [ -f "$DAGU_PID_FILE" ] && kill -0 "$(cat "$DAGU_PID_FILE")" 2>/dev/null; then
    kill "$(cat "$DAGU_PID_FILE")"
    rm -f "$DAGU_PID_FILE"
    echo "✅ Dagu stopped"
  else
    echo "⚠️  Dagu is not running"
    rm -f "$DAGU_PID_FILE"
  fi
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start
}

cmd_status() {
  local dag_name="${1:-}"
  
  if [ -z "$dag_name" ]; then
    # Server status
    if [ -f "$DAGU_PID_FILE" ] && kill -0 "$(cat "$DAGU_PID_FILE")" 2>/dev/null; then
      echo "✅ Dagu is running (PID: $(cat "$DAGU_PID_FILE"))"
      PORT=$(grep -oP 'port:\s*\K\d+' "$CONFIG_FILE" 2>/dev/null || echo 8080)
      echo "   Dashboard: http://localhost:$PORT"
      echo "   DAGs directory: $DAGS_DIR"
      echo "   Total DAGs: $(find "$DAGS_DIR" -name '*.yaml' -o -name '*.yml' 2>/dev/null | wc -l)"
    else
      echo "❌ Dagu is not running"
    fi
  else
    # DAG status
    local dag_file="$DAGS_DIR/$dag_name.yaml"
    [ ! -f "$dag_file" ] && dag_file="$DAGS_DIR/$dag_name.yml"
    
    if [ -f "$dag_file" ]; then
      echo "📋 DAG: $dag_name"
      echo "   File: $dag_file"
      "$DAGU_BIN" status "$dag_file" 2>/dev/null || echo "   Status: Unknown (server may not be running)"
    else
      echo "❌ DAG not found: $dag_name"
      echo "   Available: $(ls "$DAGS_DIR"/*.yaml "$DAGS_DIR"/*.yml 2>/dev/null | xargs -I{} basename {} .yaml | xargs -I{} basename {} .yml)"
    fi
  fi
}

cmd_list() {
  echo "📋 Available DAGs:"
  echo ""
  
  for f in "$DAGS_DIR"/*.yaml "$DAGS_DIR"/*.yml; do
    [ ! -f "$f" ] && continue
    local name=$(basename "$f" .yaml)
    name=$(basename "$name" .yml)
    local schedule=$(grep -oP 'schedule:\s*"\K[^"]+' "$f" 2>/dev/null || echo "manual")
    local steps=$(grep -c '^\s*- name:' "$f" 2>/dev/null || echo "?")
    printf "  %-30s  ⏰ %-20s  📊 %s steps\n" "$name" "$schedule" "$steps"
  done
}

cmd_run() {
  local dag_name="${1:?Usage: manage.sh run <dag-name>}"
  local dag_file="$DAGS_DIR/$dag_name.yaml"
  [ ! -f "$dag_file" ] && dag_file="$DAGS_DIR/$dag_name.yml"
  
  if [ ! -f "$dag_file" ]; then
    echo "❌ DAG not found: $dag_name"
    exit 1
  fi
  
  echo "🚀 Running DAG: $dag_name"
  "$DAGU_BIN" start "$dag_file"
}

cmd_dry_run() {
  local dag_name="${1:?Usage: manage.sh dry-run <dag-name>}"
  local dag_file="$DAGS_DIR/$dag_name.yaml"
  [ ! -f "$dag_file" ] && dag_file="$DAGS_DIR/$dag_name.yml"
  
  if [ ! -f "$dag_file" ]; then
    echo "❌ DAG not found: $dag_name"
    exit 1
  fi
  
  echo "🔍 Dry run: $dag_name"
  "$DAGU_BIN" dry-run "$dag_file"
}

cmd_history() {
  local dag_name="${1:?Usage: manage.sh history <dag-name>}"
  local dag_file="$DAGS_DIR/$dag_name.yaml"
  [ ! -f "$dag_file" ] && dag_file="$DAGS_DIR/$dag_name.yml"
  
  if [ ! -f "$dag_file" ]; then
    echo "❌ DAG not found: $dag_name"
    exit 1
  fi
  
  "$DAGU_BIN" status "$dag_file"
}

cmd_export() {
  local dest="${1:?Usage: manage.sh export <directory>}"
  mkdir -p "$dest"
  cp "$DAGS_DIR"/*.yaml "$DAGS_DIR"/*.yml "$dest/" 2>/dev/null || true
  cp "$CONFIG_FILE" "$dest/_admin.yaml" 2>/dev/null || true
  echo "✅ Exported $(ls "$dest"/*.yaml "$dest"/*.yml 2>/dev/null | wc -l) DAGs to $dest"
}

cmd_import() {
  local src="${1:?Usage: manage.sh import <directory>}"
  
  if [ ! -d "$src" ]; then
    echo "❌ Directory not found: $src"
    exit 1
  fi
  
  local count=0
  for f in "$src"/*.yaml "$src"/*.yml; do
    [ ! -f "$f" ] && continue
    local basename=$(basename "$f")
    [ "$basename" = "_admin.yaml" ] && continue
    cp "$f" "$DAGS_DIR/"
    count=$((count + 1))
  done
  
  echo "✅ Imported $count DAGs to $DAGS_DIR"
}

cmd_logs() {
  local dag_name="${1:-}"
  
  if [ -z "$dag_name" ]; then
    tail -50 "$CONFIG_DIR/logs/server.log" 2>/dev/null || echo "No server logs found"
  else
    local log_dir="$CONFIG_DIR/logs/$dag_name"
    if [ -d "$log_dir" ]; then
      ls -t "$log_dir"/*.log 2>/dev/null | head -1 | xargs cat 2>/dev/null || echo "No logs found for $dag_name"
    else
      echo "No logs found for DAG: $dag_name"
    fi
  fi
}

# Main dispatch
case "${1:-help}" in
  start)    cmd_start ;;
  stop)     cmd_stop ;;
  restart)  cmd_restart ;;
  status)   cmd_status "${2:-}" ;;
  list)     cmd_list ;;
  run)      cmd_run "${2:-}" ;;
  dry-run)  cmd_dry_run "${2:-}" ;;
  history)  cmd_history "${2:-}" ;;
  export)   cmd_export "${2:-}" ;;
  import)   cmd_import "${2:-}" ;;
  logs)     cmd_logs "${2:-}" ;;
  help|*)   usage ;;
esac
