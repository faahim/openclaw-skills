#!/bin/bash
# Transmission Torrent Manager — Main CLI
set -e

HOST="${TRANSMISSION_HOST:-127.0.0.1}"
PORT="${TRANSMISSION_PORT:-9091}"
USER="${TRANSMISSION_USER:-}"
PASS="${TRANSMISSION_PASS:-}"
CONFIG_DIR="${TRANSMISSION_CONFIG_DIR:-$HOME/.config/transmission-daemon}"

# Build auth args for transmission-remote
TR_CMD="transmission-remote ${HOST}:${PORT}"
if [ -n "$USER" ] && [ -n "$PASS" ]; then
  TR_CMD="$TR_CMD --auth $USER:$PASS"
fi

# RPC helper for direct API calls
rpc_call() {
  local method="$1"
  local args="$2"
  local session_id

  # Get session ID
  session_id=$(curl -s -o /dev/null -D - "http://${HOST}:${PORT}/transmission/rpc" 2>/dev/null \
    | grep -i 'X-Transmission-Session-Id' | tr -d '\r' | awk '{print $2}')

  local auth_header=""
  if [ -n "$USER" ] && [ -n "$PASS" ]; then
    auth_header="-u ${USER}:${PASS}"
  fi

  if [ -n "$args" ]; then
    curl -s $auth_header \
      -H "X-Transmission-Session-Id: $session_id" \
      -H "Content-Type: application/json" \
      -d "{\"method\":\"$method\",\"arguments\":$args}" \
      "http://${HOST}:${PORT}/transmission/rpc"
  else
    curl -s $auth_header \
      -H "X-Transmission-Session-Id: $session_id" \
      -H "Content-Type: application/json" \
      -d "{\"method\":\"$method\"}" \
      "http://${HOST}:${PORT}/transmission/rpc"
  fi
}

cmd_add() {
  local target="$1"
  if [ -z "$target" ]; then
    echo "Usage: run.sh add <magnet-link|torrent-url|torrent-file>"
    exit 1
  fi

  if [ -f "$target" ]; then
    # Local .torrent file
    echo "📥 Adding torrent file: $(basename "$target")"
    $TR_CMD --add "$target"
  else
    # URL or magnet
    echo "📥 Adding: ${target:0:80}..."
    $TR_CMD --add "$target"
  fi
}

cmd_status() {
  echo "📊 Torrent Status"
  echo "─────────────────────────────────────────────────────"
  $TR_CMD --list
}

cmd_list() {
  local filter="${1:-}"

  case "$filter" in
    --filter)
      local type="${2:-all}"
      case "$type" in
        downloading)
          $TR_CMD --list | head -1
          $TR_CMD --list | grep -i "downloading\|up & down" || echo "No downloading torrents."
          ;;
        seeding)
          $TR_CMD --list | head -1
          $TR_CMD --list | grep -i "seeding" || echo "No seeding torrents."
          ;;
        paused|stopped)
          $TR_CMD --list | head -1
          $TR_CMD --list | grep -i "stopped" || echo "No paused torrents."
          ;;
        *)
          $TR_CMD --list
          ;;
      esac
      ;;
    *)
      $TR_CMD --list
      ;;
  esac
}

cmd_info() {
  local id="$1"
  if [ -z "$id" ]; then
    echo "Usage: run.sh info <torrent-id>"
    exit 1
  fi
  $TR_CMD --torrent "$id" --info
}

cmd_watch() {
  local id="$1"
  local interval="${2:-5}"

  if [ -z "$id" ]; then
    echo "Usage: run.sh watch <torrent-id> [interval-seconds]"
    exit 1
  fi

  echo "👀 Watching torrent $id (Ctrl+C to stop)"
  while true; do
    local info
    info=$($TR_CMD --torrent "$id" --info 2>/dev/null)
    local name percent down_speed up_speed eta
    name=$(echo "$info" | grep "^  Name:" | sed 's/^  Name: //')
    percent=$(echo "$info" | grep "^  Percent Done:" | sed 's/^  Percent Done: //')
    down_speed=$(echo "$info" | grep "^  Download Speed:" | sed 's/^  Download Speed: //')
    up_speed=$(echo "$info" | grep "^  Upload Speed:" | sed 's/^  Upload Speed: //')
    eta=$(echo "$info" | grep "^  ETA:" | sed 's/^  ETA: //')

    printf "\r[%s] %s — %s ↓ %s ↑ %s ETA: %s    " \
      "$(date '+%H:%M:%S')" "$name" "$percent" "$down_speed" "$up_speed" "$eta"

    sleep "$interval"
  done
}

cmd_pause() {
  local id="$1"
  if [ -z "$id" ]; then
    echo "Usage: run.sh pause <torrent-id>"
    exit 1
  fi
  $TR_CMD --torrent "$id" --stop
  echo "⏸️  Paused torrent $id"
}

cmd_resume() {
  local id="$1"
  if [ -z "$id" ]; then
    echo "Usage: run.sh resume <torrent-id>"
    exit 1
  fi
  $TR_CMD --torrent "$id" --start
  echo "▶️  Resumed torrent $id"
}

cmd_pause_all() {
  $TR_CMD --torrent all --stop
  echo "⏸️  Paused all torrents."
}

cmd_resume_all() {
  $TR_CMD --torrent all --start
  echo "▶️  Resumed all torrents."
}

cmd_remove() {
  local id="$1"
  local delete_flag="$2"

  if [ -z "$id" ]; then
    echo "Usage: run.sh remove <torrent-id> [--delete]"
    exit 1
  fi

  if [ "$delete_flag" = "--delete" ]; then
    $TR_CMD --torrent "$id" --remove-and-delete
    echo "🗑️  Removed torrent $id and deleted files."
  else
    $TR_CMD --torrent "$id" --remove
    echo "🗑️  Removed torrent $id (files kept)."
  fi
}

cmd_speed_limit() {
  local direction="$1"
  local value="$2"

  case "$direction" in
    down)
      if [ -z "$value" ]; then
        echo "Usage: run.sh speed-limit down <KB/s>"
        exit 1
      fi
      $TR_CMD --downlimit "$value" --downlimit-enable
      echo "⬇️  Download limit set to ${value} KB/s"
      ;;
    up)
      if [ -z "$value" ]; then
        echo "Usage: run.sh speed-limit up <KB/s>"
        exit 1
      fi
      $TR_CMD --uplimit "$value" --uplimit-enable
      echo "⬆️  Upload limit set to ${value} KB/s"
      ;;
    show)
      echo "📊 Speed Limits:"
      $TR_CMD --session-info | grep -i "speed limit\|alt speed"
      ;;
    off)
      $TR_CMD --no-downlimit --no-uplimit
      echo "🚀 Speed limits disabled."
      ;;
    *)
      echo "Usage: run.sh speed-limit <down|up|show|off> [KB/s]"
      exit 1
      ;;
  esac
}

cmd_alt_speed() {
  local state="$1"
  case "$state" in
    on)
      $TR_CMD --alt-speed
      echo "🐢 Turtle mode (alt-speed) enabled."
      ;;
    off)
      $TR_CMD --no-alt-speed
      echo "🐇 Turtle mode (alt-speed) disabled."
      ;;
    *)
      echo "Usage: run.sh alt-speed <on|off>"
      exit 1
      ;;
  esac
}

cmd_config() {
  local action="$1"
  local key="$2"
  local value="$3"

  case "$action" in
    show)
      if [ -f "$CONFIG_DIR/settings.json" ]; then
        cat "$CONFIG_DIR/settings.json" | jq .
      else
        echo "❌ No config found at $CONFIG_DIR/settings.json"
        echo "   Run: bash scripts/install.sh"
      fi
      ;;
    set)
      if [ -z "$key" ] || [ -z "$value" ]; then
        echo "Usage: run.sh config set <key> <value>"
        exit 1
      fi

      if [ ! -f "$CONFIG_DIR/settings.json" ]; then
        echo "❌ No config found. Run install first."
        exit 1
      fi

      # Stop daemon before editing (it overwrites on exit)
      local was_running=false
      if pgrep -x transmission-da &>/dev/null; then
        was_running=true
        pkill -x transmission-da
        sleep 2
      fi

      # Determine value type
      if [[ "$value" =~ ^[0-9]+$ ]]; then
        jq ".\"$key\" = $value" "$CONFIG_DIR/settings.json" > "$CONFIG_DIR/settings.json.tmp"
      elif [[ "$value" =~ ^[0-9]+\.[0-9]+$ ]]; then
        jq ".\"$key\" = $value" "$CONFIG_DIR/settings.json" > "$CONFIG_DIR/settings.json.tmp"
      elif [ "$value" = "true" ] || [ "$value" = "false" ]; then
        jq ".\"$key\" = $value" "$CONFIG_DIR/settings.json" > "$CONFIG_DIR/settings.json.tmp"
      else
        jq ".\"$key\" = \"$value\"" "$CONFIG_DIR/settings.json" > "$CONFIG_DIR/settings.json.tmp"
      fi

      mv "$CONFIG_DIR/settings.json.tmp" "$CONFIG_DIR/settings.json"
      echo "✅ Set $key = $value"

      if [ "$was_running" = true ]; then
        echo "🔄 Restarting daemon..."
        bash "$(dirname "$0")/install.sh" start
      fi
      ;;
    *)
      echo "Usage: run.sh config <show|set> [key] [value]"
      exit 1
      ;;
  esac
}

cmd_clean() {
  echo "🧹 Cleaning completed/seeding torrents (keeping files)..."
  local ids
  ids=$($TR_CMD --list | grep -i "100%" | awk '{print $1}' | grep -o '[0-9]*' || true)

  if [ -z "$ids" ]; then
    echo "ℹ️  No completed torrents to clean."
    return
  fi

  local count=0
  for id in $ids; do
    $TR_CMD --torrent "$id" --remove 2>/dev/null && count=$((count + 1))
  done
  echo "✅ Removed $count completed torrent(s). Files preserved."
}

cmd_auto_clean() {
  local days=7
  while [[ $# -gt 0 ]]; do
    case $1 in
      --days) days="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auto-clean: removing torrents done for $days+ days"

  local result
  result=$(rpc_call "torrent-get" '{"fields":["id","name","percentDone","doneDate"]}')
  local now
  now=$(date +%s)
  local threshold=$((days * 86400))

  echo "$result" | jq -r ".arguments.torrents[] | select(.percentDone == 1) | select(.doneDate > 0) | select(($now - .doneDate) > $threshold) | .id" 2>/dev/null | while read -r id; do
    local name
    name=$(echo "$result" | jq -r ".arguments.torrents[] | select(.id == $id) | .name")
    $TR_CMD --torrent "$id" --remove 2>/dev/null
    echo "  Removed: $name (ID: $id)"
  done

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auto-clean complete."
}

cmd_port_test() {
  echo "🔍 Testing peer port..."
  $TR_CMD --port-test
}

cmd_blocklist_update() {
  echo "🔄 Updating blocklist..."
  $TR_CMD --blocklist-update
}

cmd_session_stats() {
  echo "📈 Session Statistics:"
  $TR_CMD --session-stats
}

# Main dispatcher
case "${1:-help}" in
  add)        shift; cmd_add "$@" ;;
  status)     cmd_status ;;
  list)       shift; cmd_list "$@" ;;
  info)       shift; cmd_info "$@" ;;
  watch)      shift; cmd_watch "$@" ;;
  pause)      shift; cmd_pause "$@" ;;
  resume)     shift; cmd_resume "$@" ;;
  pause-all)  cmd_pause_all ;;
  resume-all) cmd_resume_all ;;
  remove)     shift; cmd_remove "$@" ;;
  speed-limit) shift; cmd_speed_limit "$@" ;;
  alt-speed)  shift; cmd_alt_speed "$@" ;;
  config)     shift; cmd_config "$@" ;;
  clean)      cmd_clean ;;
  auto-clean) shift; cmd_auto_clean "$@" ;;
  port-test)  cmd_port_test ;;
  blocklist-update) cmd_blocklist_update ;;
  stats)      cmd_session_stats ;;
  help|--help|-h)
    echo "Transmission Torrent Manager"
    echo ""
    echo "Usage: run.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  add <link|url|file>     Add a torrent"
    echo "  status                  Show all torrent status"
    echo "  list [--filter type]    List torrents (filter: downloading|seeding|paused)"
    echo "  info <id>               Detailed torrent info"
    echo "  watch <id> [interval]   Live progress monitor"
    echo "  pause <id>              Pause a torrent"
    echo "  resume <id>             Resume a torrent"
    echo "  pause-all               Pause all torrents"
    echo "  resume-all              Resume all torrents"
    echo "  remove <id> [--delete]  Remove torrent (--delete to also remove files)"
    echo "  speed-limit <dir> <val> Set speed limit (down|up|show|off)"
    echo "  alt-speed <on|off>      Toggle turtle mode"
    echo "  config <show|set>       View/edit configuration"
    echo "  clean                   Remove all completed torrents (keep files)"
    echo "  auto-clean [--days N]   Remove torrents done for N+ days"
    echo "  port-test               Test if peer port is reachable"
    echo "  blocklist-update        Update IP blocklist"
    echo "  stats                   Show session statistics"
    echo ""
    echo "Environment:"
    echo "  TRANSMISSION_HOST       Daemon host (default: 127.0.0.1)"
    echo "  TRANSMISSION_PORT       RPC port (default: 9091)"
    echo "  TRANSMISSION_USER       RPC username"
    echo "  TRANSMISSION_PASS       RPC password"
    ;;
  *)
    echo "Unknown command: $1"
    echo "Run: bash scripts/run.sh help"
    exit 1
    ;;
esac
