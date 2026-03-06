#!/bin/bash
# File Watcher — Main Script
# Watches files/directories and triggers actions on changes
set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="/tmp"

# Defaults
WATCH_PATH=""
EVENTS="modify,create,delete,move"
FILTER=""
EXCLUDE=""
RECURSIVE=false
RUN_CMD=""
DEBOUNCE=0
LOG_FILE=""
DAEMON=false
QUIET=false
CONFIG=""
POLL_INTERVAL=0
GENERATE_SERVICE=false
STOP=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
📂 File Watcher v${VERSION}
Watch files/directories and trigger actions on changes.

USAGE:
  bash watch.sh --path <dir> [options]
  bash watch.sh --config <file.yaml> [options]

OPTIONS:
  --path PATH        Directory or file to watch
  --config FILE      YAML config for multi-watcher setup
  --events EVENTS    Comma-separated: modify,create,delete,move,access,attrib
  --filter REGEX     Only trigger on filenames matching regex
  --exclude REGEX    Ignore filenames matching regex
  --recursive        Watch subdirectories
  --run COMMAND      Command to run on event (\$WATCH_FILE, \$WATCH_EVENT available)
  --debounce SECS    Seconds to wait after last event before triggering
  --log FILE         Log events to file
  --daemon           Run in background
  --quiet            Suppress event output
  --poll SECS        Use polling instead of inotify (for NFS/CIFS)
  --generate-service Print systemd unit file
  --stop             Stop all background watchers
  --help             Show this help

EXAMPLES:
  # Watch src/ for changes, rebuild
  bash watch.sh --path ./src --events modify,create --run "npm run build" --debounce 2

  # Watch config, restart service
  bash watch.sh --path /etc/myapp/config.yaml --events modify --run "systemctl restart myapp"

  # Multi-watcher from config
  bash watch.sh --config config.yaml --daemon
EOF
  exit 0
}

log_event() {
  local timestamp event file
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  event="$1"
  file="$2"

  if [ "$QUIET" = false ]; then
    case "$event" in
      *CREATE*) echo -e "${GREEN}[$timestamp] CREATE${NC} $file" ;;
      *DELETE*) echo -e "${RED}[$timestamp] DELETE${NC} $file" ;;
      *MODIFY*) echo -e "${BLUE}[$timestamp] MODIFY${NC} $file" ;;
      *MOVED*) echo -e "${YELLOW}[$timestamp] MOVE${NC} $file" ;;
      *) echo "[$timestamp] $event $file" ;;
    esac
  fi

  if [ -n "$LOG_FILE" ]; then
    echo "[$timestamp] $event $file" >> "$LOG_FILE"
  fi
}

run_action() {
  local file="$1" event="$2" dir="$3" name="$4"

  if [ -n "$RUN_CMD" ]; then
    export WATCH_FILE="$file"
    export WATCH_EVENT="$event"
    export WATCH_DIR="$dir"
    export WATCH_NAME="$name"
    
    if [ "$QUIET" = false ]; then
      echo -e "${YELLOW}  → Running: ${RUN_CMD}${NC}"
    fi
    
    eval "$RUN_CMD" 2>&1 || true
  fi
}

watch_inotify() {
  local path="$1"
  local inotify_events=""
  local inotify_opts=()
  local last_trigger=0

  # Map events to inotify format
  IFS=',' read -ra EVENT_ARRAY <<< "$EVENTS"
  for evt in "${EVENT_ARRAY[@]}"; do
    case "$evt" in
      modify) inotify_events="${inotify_events:+$inotify_events,}modify,close_write" ;;
      create) inotify_events="${inotify_events:+$inotify_events,}create" ;;
      delete) inotify_events="${inotify_events:+$inotify_events,}delete" ;;
      move)   inotify_events="${inotify_events:+$inotify_events,}moved_to,moved_from" ;;
      access) inotify_events="${inotify_events:+$inotify_events,}access" ;;
      attrib) inotify_events="${inotify_events:+$inotify_events,}attrib" ;;
      *)      inotify_events="${inotify_events:+$inotify_events,}$evt" ;;
    esac
  done

  inotify_opts+=(-e "$inotify_events")
  
  if [ "$RECURSIVE" = true ]; then
    inotify_opts+=(-r)
  fi

  if [ -n "$EXCLUDE" ]; then
    inotify_opts+=(--exclude "$EXCLUDE")
  fi

  inotify_opts+=(-m --format '%e %w%f')

  echo -e "${GREEN}👁️  Watching: ${path}${NC}"
  echo -e "   Events: ${EVENTS}"
  [ -n "$FILTER" ] && echo -e "   Filter: ${FILTER}"
  [ -n "$EXCLUDE" ] && echo -e "   Exclude: ${EXCLUDE}"
  [ "$DEBOUNCE" -gt 0 ] && echo -e "   Debounce: ${DEBOUNCE}s"
  [ -n "$RUN_CMD" ] && echo -e "   Action: ${RUN_CMD}"
  echo ""

  inotifywait "${inotify_opts[@]}" "$path" 2>/dev/null | while read -r event file; do
    # Apply filter
    if [ -n "$FILTER" ]; then
      basename_file="$(basename "$file")"
      if ! echo "$basename_file" | grep -qE "$FILTER"; then
        continue
      fi
    fi

    log_event "$event" "$file"

    # Debounce
    if [ "$DEBOUNCE" -gt 0 ]; then
      current=$(date +%s)
      if [ $((current - last_trigger)) -lt "$DEBOUNCE" ]; then
        continue
      fi
      last_trigger=$current
    fi

    dir="$(dirname "$file")"
    name="$(basename "$file")"
    run_action "$file" "$event" "$dir" "$name"
  done
}

watch_poll() {
  local path="$1"
  local interval="$POLL_INTERVAL"
  
  echo -e "${GREEN}👁️  Watching (poll mode): ${path}${NC}"
  echo -e "   Interval: ${interval}s"
  echo ""

  declare -A prev_state

  # Initial snapshot
  while IFS= read -r -d '' file; do
    prev_state["$file"]="$(stat -c '%Y' "$file" 2>/dev/null || echo 0)"
  done < <(find "$path" -type f -print0 2>/dev/null)

  while true; do
    sleep "$interval"
    declare -A curr_state

    while IFS= read -r -d '' file; do
      curr_state["$file"]="$(stat -c '%Y' "$file" 2>/dev/null || echo 0)"
    done < <(find "$path" -type f -print0 2>/dev/null)

    # Check for new/modified files
    for file in "${!curr_state[@]}"; do
      if [ -n "$FILTER" ] && ! basename "$file" | grep -qE "$FILTER"; then
        continue
      fi
      if [ -z "${prev_state[$file]+x}" ]; then
        log_event "CREATE" "$file"
        run_action "$file" "CREATE" "$(dirname "$file")" "$(basename "$file")"
      elif [ "${curr_state[$file]}" != "${prev_state[$file]}" ]; then
        log_event "MODIFY" "$file"
        run_action "$file" "MODIFY" "$(dirname "$file")" "$(basename "$file")"
      fi
    done

    # Check for deleted files
    for file in "${!prev_state[@]}"; do
      if [ -z "${curr_state[$file]+x}" ]; then
        log_event "DELETE" "$file"
        run_action "$file" "DELETE" "$(dirname "$file")" "$(basename "$file")"
      fi
    done

    # Update state
    unset prev_state
    declare -A prev_state
    for file in "${!curr_state[@]}"; do
      prev_state["$file"]="${curr_state[$file]}"
    done
    unset curr_state
  done
}

parse_config() {
  local config_file="$1"
  
  if ! [ -f "$config_file" ]; then
    echo "❌ Config file not found: $config_file"
    exit 1
  fi

  # Simple YAML parser — extract watcher blocks
  local in_watcher=false
  local watcher_name="" watcher_path="" watcher_events="modify,create,delete"
  local watcher_filter="" watcher_exclude="" watcher_recursive=false
  local watcher_run="" watcher_debounce=0

  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"?([^\"]+)\"? ]]; then
      # New watcher block — launch previous if exists
      if [ -n "$watcher_path" ]; then
        (
          WATCH_PATH="$watcher_path"
          EVENTS="$watcher_events"
          FILTER="$watcher_filter"
          EXCLUDE="$watcher_exclude"
          RECURSIVE="$watcher_recursive"
          RUN_CMD="$watcher_run"
          DEBOUNCE="$watcher_debounce"
          echo -e "${BLUE}Starting watcher: ${watcher_name}${NC}"
          watch_inotify "$WATCH_PATH"
        ) &
      fi
      watcher_name="${BASH_REMATCH[1]}"
      watcher_path="" watcher_events="modify,create,delete"
      watcher_filter="" watcher_exclude="" watcher_recursive=false
      watcher_run="" watcher_debounce=0
    elif [[ "$line" =~ path:[[:space:]]*(.+) ]]; then
      watcher_path="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ events:[[:space:]]*\[(.+)\] ]]; then
      watcher_events="$(echo "${BASH_REMATCH[1]}" | tr -d ' "')"
    elif [[ "$line" =~ filter:[[:space:]]*['\"](.+)['\"] ]]; then
      watcher_filter="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ exclude:[[:space:]]*['\"](.+)['\"] ]]; then
      watcher_exclude="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ recursive:[[:space:]]*(true|false) ]]; then
      watcher_recursive="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ run:[[:space:]]*['\"](.+)['\"] ]]; then
      watcher_run="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ debounce:[[:space:]]*([0-9]+) ]]; then
      watcher_debounce="${BASH_REMATCH[1]}"
    fi
  done < "$config_file"

  # Launch last watcher
  if [ -n "$watcher_path" ]; then
    (
      WATCH_PATH="$watcher_path"
      EVENTS="$watcher_events"
      FILTER="$watcher_filter"
      EXCLUDE="$watcher_exclude"
      RECURSIVE="$watcher_recursive"
      RUN_CMD="$watcher_run"
      DEBOUNCE="$watcher_debounce"
      echo -e "${BLUE}Starting watcher: ${watcher_name}${NC}"
      watch_inotify "$WATCH_PATH"
    ) &
  fi

  echo -e "${GREEN}All watchers started. Press Ctrl+C to stop.${NC}"
  wait
}

generate_systemd() {
  cat <<UNIT
[Unit]
Description=File Watcher Service
After=network.target

[Service]
Type=simple
ExecStart=$(readlink -f "$0") --config ${CONFIG:-/etc/file-watcher/config.yaml}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT
}

stop_watchers() {
  local count=0
  for pidfile in "$PID_DIR"/file-watcher-*.pid; do
    [ -f "$pidfile" ] || continue
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      rm "$pidfile"
      ((count++))
    fi
  done
  echo "Stopped $count watcher(s)."
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --path) WATCH_PATH="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --events) EVENTS="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --recursive) RECURSIVE=true; shift ;;
    --run) RUN_CMD="$2"; shift 2 ;;
    --debounce) DEBOUNCE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --daemon) DAEMON=true; shift ;;
    --quiet) QUIET=true; shift ;;
    --poll) POLL_INTERVAL="$2"; shift 2 ;;
    --generate-service) GENERATE_SERVICE=true; shift ;;
    --stop) stop_watchers ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Generate systemd service
if [ "$GENERATE_SERVICE" = true ]; then
  generate_systemd
  exit 0
fi

# Config mode
if [ -n "$CONFIG" ]; then
  if [ "$DAEMON" = true ]; then
    parse_config "$CONFIG" &
    PID=$!
    echo "$PID" > "$PID_DIR/file-watcher-config-$PID.pid"
    echo "Watcher daemonized (PID: $PID)"
    exit 0
  fi
  parse_config "$CONFIG"
  exit 0
fi

# Validate
if [ -z "$WATCH_PATH" ]; then
  echo "❌ --path or --config required"
  usage
fi

if ! [ -e "$WATCH_PATH" ]; then
  echo "❌ Path does not exist: $WATCH_PATH"
  exit 1
fi

# Check for inotifywait
if ! command -v inotifywait &>/dev/null; then
  if [ "$POLL_INTERVAL" -eq 0 ]; then
    echo "❌ inotifywait not found. Install: bash scripts/install.sh"
    echo "   Or use --poll <seconds> for polling mode."
    exit 1
  fi
fi

# Daemon mode
if [ "$DAEMON" = true ]; then
  if [ "$POLL_INTERVAL" -gt 0 ]; then
    watch_poll "$WATCH_PATH" &
  else
    watch_inotify "$WATCH_PATH" &
  fi
  PID=$!
  PIDFILE="$PID_DIR/file-watcher-$PID.pid"
  echo "$PID" > "$PIDFILE"
  echo "Watcher daemonized (PID: $PID, pidfile: $PIDFILE)"
  exit 0
fi

# Foreground mode
if [ "$POLL_INTERVAL" -gt 0 ]; then
  watch_poll "$WATCH_PATH"
else
  watch_inotify "$WATCH_PATH"
fi
