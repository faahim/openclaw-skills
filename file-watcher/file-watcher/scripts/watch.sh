#!/bin/bash
# File Watcher — monitor directories and trigger actions on file changes
set -euo pipefail

VERSION="1.0.0"
WATCH_DIR=""
RECURSIVE=""
EVENTS="create,modify,delete,moved_to,moved_from"
FILTER=""
EXCLUDE=""
ON_CHANGE=""
TELEGRAM=false
LOG_FILE=""
DEBOUNCE=1
DAEMON=false
QUIET=false
CONFIG=""
PID_DIR="/tmp"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
File Watcher v${VERSION} — Watch files, trigger actions

USAGE:
  bash watch.sh --dir PATH [OPTIONS]

OPTIONS:
  --dir PATH          Directory to watch (required)
  --recursive         Watch subdirectories
  --events EVENTS     Events: create,modify,delete,move,attrib (default: create,modify,delete,move)
  --filter PATTERNS   Include only: '*.js,*.ts'
  --exclude PATTERNS  Exclude: 'node_modules,.git,.tmp'
  --on-change CMD     Command to run (\$WATCH_FILE, \$WATCH_EVENT, \$WATCH_DIR available)
  --telegram          Send Telegram notification
  --log FILE          Log events to file
  --debounce SECS     Debounce delay (default: 1)
  --daemon            Run in background
  --quiet             Suppress console output
  --config FILE       Use YAML config file
  --list              List running watchers
  --stop-all          Stop all running watchers
  --help              Show this help

EXAMPLES:
  bash watch.sh --dir ./src --on-change "npm run build" --debounce 2
  bash watch.sh --dir /var/uploads --events create --telegram --recursive
  bash watch.sh --config config.yaml --daemon
EOF
  exit 0
}

log_event() {
  local timestamp event file
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  event="$1"
  file="$2"

  local icon
  case "$event" in
    CREATE|MOVED_TO) icon="✨" ;;
    MODIFY)          icon="✏️" ;;
    DELETE|MOVED_FROM) icon="🗑️" ;;
    ATTRIB)          icon="🏷️" ;;
    *)               icon="📋" ;;
  esac

  local msg="[$timestamp] $icon $event: $file"

  if [ "$QUIET" = false ]; then
    echo -e "$msg"
  fi

  if [ -n "$LOG_FILE" ]; then
    echo "$msg" >> "$LOG_FILE"
  fi
}

send_telegram() {
  local event="$1" file="$2"
  if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
    echo -e "${RED}⚠️ TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set${NC}" >&2
    return 1
  fi
  local msg="📁 File Watcher Alert%0A%0AEvent: $event%0AFile: $file%0ATime: $(date '+%Y-%m-%d %H:%M:%S')"
  curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT_ID}&text=${msg}" >/dev/null 2>&1 &
}

run_action() {
  local event="$1" file="$2" dir="$3"
  if [ -n "$ON_CHANGE" ]; then
    export WATCH_FILE="$file"
    export WATCH_EVENT="$event"
    export WATCH_DIR="$dir"
    eval "$ON_CHANGE" &
  fi
}

list_watchers() {
  echo "Running file watchers:"
  local found=false
  for pidfile in ${PID_DIR}/file-watcher-*.pid; do
    [ -f "$pidfile" ] || continue
    local pid
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
      echo "  PID $pid — $(basename "$pidfile" .pid)"
      found=true
    else
      rm -f "$pidfile"
    fi
  done
  if [ "$found" = false ]; then
    echo "  (none)"
  fi
}

stop_all() {
  echo "Stopping all file watchers..."
  local stopped=0
  for pidfile in ${PID_DIR}/file-watcher-*.pid; do
    [ -f "$pidfile" ] || continue
    local pid
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      echo "  Stopped PID $pid"
      ((stopped++))
    fi
    rm -f "$pidfile"
  done
  echo "Stopped $stopped watcher(s)"
}

watch_directory() {
  local dir="$1"

  # Validate directory
  if [ ! -d "$dir" ]; then
    echo -e "${RED}❌ Directory not found: $dir${NC}" >&2
    exit 1
  fi

  # Check inotifywait
  if ! command -v inotifywait &>/dev/null; then
    echo -e "${RED}❌ inotifywait not found. Run: bash scripts/install.sh${NC}" >&2
    exit 1
  fi

  # Build inotifywait args
  local args=(-m -q --format '%e %w%f')
  
  if [ -n "$RECURSIVE" ]; then
    args+=(-r)
  fi

  # Map event names
  local mapped_events
  mapped_events=$(echo "$EVENTS" | sed 's/\bmove\b/moved_to,moved_from/g' | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
  args+=(-e "$mapped_events")

  # Exclude patterns
  if [ -n "$EXCLUDE" ]; then
    IFS=',' read -ra EXCL <<< "$EXCLUDE"
    for pattern in "${EXCL[@]}"; do
      args+=(--exclude "$pattern")
    done
  fi

  args+=("$dir")

  echo -e "${GREEN}👁️ Watching ${BLUE}$dir${NC} (${mapped_events})${NC}"
  if [ -n "$FILTER" ]; then
    echo -e "   Filter: $FILTER"
  fi
  if [ -n "$ON_CHANGE" ]; then
    echo -e "   Action: $ON_CHANGE"
  fi
  if [ "$TELEGRAM" = true ]; then
    echo -e "   Telegram alerts: enabled"
  fi
  echo ""

  # Debounce tracking
  local last_file="" last_time=0

  inotifywait "${args[@]}" | while read -r line; do
    local event file
    event=$(echo "$line" | awk '{print $1}')
    file=$(echo "$line" | awk '{$1=""; print substr($0,2)}')

    # Apply filter
    if [ -n "$FILTER" ]; then
      local matched=false
      IFS=',' read -ra FILT <<< "$FILTER"
      for pattern in "${FILT[@]}"; do
        pattern=$(echo "$pattern" | xargs)  # trim whitespace
        case "$(basename "$file")" in
          $pattern) matched=true; break ;;
        esac
      done
      if [ "$matched" = false ]; then
        continue
      fi
    fi

    # Debounce: skip if same file within debounce window
    local now
    now=$(date +%s)
    if [ "$file" = "$last_file" ] && [ $((now - last_time)) -lt "$DEBOUNCE" ]; then
      continue
    fi
    last_file="$file"
    last_time=$now

    # Log event
    log_event "$event" "$file"

    # Telegram alert
    if [ "$TELEGRAM" = true ]; then
      send_telegram "$event" "$file"
    fi

    # Run action
    run_action "$event" "$file" "$dir"
  done
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dir)       WATCH_DIR="$2"; shift 2 ;;
    --recursive) RECURSIVE=true; shift ;;
    --events)    EVENTS="$2"; shift 2 ;;
    --filter)    FILTER="$2"; shift 2 ;;
    --exclude)   EXCLUDE="$2"; shift 2 ;;
    --on-change) ON_CHANGE="$2"; shift 2 ;;
    --telegram)  TELEGRAM=true; shift ;;
    --log)       LOG_FILE="$2"; shift 2 ;;
    --debounce)  DEBOUNCE="$2"; shift 2 ;;
    --daemon)    DAEMON=true; shift ;;
    --quiet)     QUIET=true; shift ;;
    --config)    CONFIG="$2"; shift 2 ;;
    --list)      list_watchers; exit 0 ;;
    --stop-all)  stop_all; exit 0 ;;
    --help|-h)   usage ;;
    *)           echo "Unknown option: $1"; usage ;;
  esac
done

# Config file mode
if [ -n "$CONFIG" ]; then
  if ! command -v python3 &>/dev/null; then
    echo "❌ python3 required for YAML config parsing" >&2
    exit 1
  fi

  # Parse YAML config and launch watchers
  python3 -c "
import yaml, json, sys
with open('$CONFIG') as f:
    cfg = yaml.safe_load(f)
for w in cfg.get('watchers', []):
    print(json.dumps(w))
" | while read -r watcher; do
    local_dir=$(echo "$watcher" | python3 -c "import json,sys; w=json.load(sys.stdin); print(w.get('dir',''))")
    local_events=$(echo "$watcher" | python3 -c "import json,sys; w=json.load(sys.stdin); print(','.join(w.get('events',['create','modify','delete','move'])))")
    local_filter=$(echo "$watcher" | python3 -c "import json,sys; w=json.load(sys.stdin); print(','.join(w.get('filter',[])))")
    local_exclude=$(echo "$watcher" | python3 -c "import json,sys; w=json.load(sys.stdin); print(','.join(w.get('exclude',[])))")
    local_action=$(echo "$watcher" | python3 -c "import json,sys; w=json.load(sys.stdin); print(w.get('on_change',''))")
    local_debounce=$(echo "$watcher" | python3 -c "import json,sys; w=json.load(sys.stdin); print(w.get('debounce',1))")
    local_recursive=$(echo "$watcher" | python3 -c "import json,sys; w=json.load(sys.stdin); print('--recursive' if w.get('recursive',False) else '')")
    local_telegram=$(echo "$watcher" | python3 -c "import json,sys; w=json.load(sys.stdin); print('--telegram' if w.get('telegram',False) else '')")

    bash "$0" --dir "$local_dir" --events "$local_events" \
      ${local_filter:+--filter "$local_filter"} \
      ${local_exclude:+--exclude "$local_exclude"} \
      ${local_action:+--on-change "$local_action"} \
      --debounce "$local_debounce" \
      $local_recursive $local_telegram --daemon &
  done
  echo "All watchers started from config"
  exit 0
fi

# Validate
if [ -z "$WATCH_DIR" ]; then
  echo -e "${RED}❌ --dir is required${NC}" >&2
  usage
fi

# Daemon mode
if [ "$DAEMON" = true ]; then
  HASH=$(echo "$WATCH_DIR" | md5sum | cut -c1-8)
  PID_FILE="${PID_DIR}/file-watcher-${HASH}.pid"
  
  nohup bash "$0" --dir "$WATCH_DIR" \
    ${RECURSIVE:+--recursive} \
    --events "$EVENTS" \
    ${FILTER:+--filter "$FILTER"} \
    ${EXCLUDE:+--exclude "$EXCLUDE"} \
    ${ON_CHANGE:+--on-change "$ON_CHANGE"} \
    ${TELEGRAM:+--telegram} \
    ${LOG_FILE:+--log "$LOG_FILE"} \
    --debounce "$DEBOUNCE" \
    --quiet \
    > /dev/null 2>&1 &
  
  echo $! > "$PID_FILE"
  echo "Started watcher (PID $!) — $PID_FILE"
  exit 0
fi

# Trap for cleanup
trap 'echo -e "\n${YELLOW}👋 Watcher stopped${NC}"; exit 0' INT TERM

# Start watching
watch_directory "$WATCH_DIR"
