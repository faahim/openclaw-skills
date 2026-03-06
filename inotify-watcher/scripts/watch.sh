#!/bin/bash
# Inotify Watcher — Monitor directories and trigger actions on filesystem events
# Requires: inotify-tools (inotifywait)

set -euo pipefail

# Defaults
DIR=""
RECURSIVE=false
EVENTS="create,modify,delete"
FILTER=""
EXCLUDE=""
ACTION='echo "[$TIMESTAMP] $EVENT $FILE"'
DEBOUNCE=0
LOG_FILE=""
DAEMON=false
PIDFILE="/tmp/inotify-watcher.pid"
MAX_EVENTS=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Monitor a directory for filesystem events and trigger actions.

Options:
  --dir <path>        Directory to watch (required)
  --recursive         Watch subdirectories
  --events <list>     Events: create,modify,delete,moved_to,moved_from,attrib
  --filter <regex>    Only trigger on filenames matching regex
  --exclude <regex>   Skip filenames matching regex
  --action <cmd>      Command to run. Vars: \$FILE, \$EVENT, \$DIR, \$TIMESTAMP
  --debounce <secs>   Coalesce events within N seconds
  --log <file>        Log events to file
  --daemon            Run in background
  --pidfile <file>    PID file (default: /tmp/inotify-watcher.pid)
  --max-events <n>    Stop after N events (0 = unlimited)
  -h, --help          Show this help

Examples:
  $(basename "$0") --dir ~/uploads --events create --action 'echo "New: \$FILE"'
  $(basename "$0") --dir /etc --recursive --events modify --action 'alert.sh "\$FILE changed"'
  $(basename "$0") --dir ./src --recursive --events modify,create --filter '\.ts$' --debounce 2 --action 'npm run build'
EOF
  exit 0
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --dir) DIR="$2"; shift 2 ;;
    --recursive) RECURSIVE=true; shift ;;
    --events) EVENTS="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --debounce) DEBOUNCE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --daemon) DAEMON=true; shift ;;
    --pidfile) PIDFILE="$2"; shift 2 ;;
    --max-events) MAX_EVENTS="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate
if [[ -z "$DIR" ]]; then
  echo "Error: --dir is required"
  exit 1
fi

if [[ ! -d "$DIR" ]]; then
  echo "Error: Directory '$DIR' does not exist"
  exit 1
fi

if ! command -v inotifywait &>/dev/null; then
  echo "Error: inotifywait not found. Install: sudo apt-get install -y inotify-tools"
  exit 1
fi

# Build inotifywait args
INOTIFY_ARGS=(-m --format '%e %w%f' -e "${EVENTS//,/ -e }")
if [[ "$RECURSIVE" == true ]]; then
  INOTIFY_ARGS+=(-r)
fi
if [[ -n "$EXCLUDE" ]]; then
  INOTIFY_ARGS+=(--exclude "$EXCLUDE")
fi

# Debounce state
LAST_ACTION_TIME=0
PENDING_FILE=""
PENDING_EVENT=""

log_msg() {
  local msg="$1"
  if [[ -n "$LOG_FILE" ]]; then
    echo "$msg" >> "$LOG_FILE"
  fi
}

run_action() {
  local file="$1"
  local event="$2"
  local dir="$DIR"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Export vars for action command
  export FILE="$file"
  export EVENT="$event"
  export DIR="$dir"
  export TIMESTAMP="$timestamp"

  log_msg "[$timestamp] $event $file"

  # Run action
  eval "$ACTION" 2>&1 || true
}

# Daemon mode
if [[ "$DAEMON" == true ]]; then
  nohup "$0" \
    --dir "$DIR" \
    $([ "$RECURSIVE" == true ] && echo "--recursive") \
    --events "$EVENTS" \
    $([ -n "$FILTER" ] && echo "--filter '$FILTER'") \
    $([ -n "$EXCLUDE" ] && echo "--exclude '$EXCLUDE'") \
    --action "$ACTION" \
    --debounce "$DEBOUNCE" \
    $([ -n "$LOG_FILE" ] && echo "--log '$LOG_FILE'") \
    --max-events "$MAX_EVENTS" \
    --pidfile "$PIDFILE" \
    > /dev/null 2>&1 &

  echo $! > "$PIDFILE"
  echo "Started in background (PID: $!)"
  echo "PID file: $PIDFILE"
  echo "Stop with: kill \$(cat $PIDFILE)"
  exit 0
fi

# Write own PID
echo $$ > "$PIDFILE"

# Cleanup on exit
cleanup() {
  rm -f "$PIDFILE" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "👁️ Watching: $DIR"
echo "   Events: $EVENTS"
[[ -n "$FILTER" ]] && echo "   Filter: $FILTER"
[[ "$RECURSIVE" == true ]] && echo "   Recursive: yes"
[[ "$DEBOUNCE" -gt 0 ]] && echo "   Debounce: ${DEBOUNCE}s"
echo "   Action: $ACTION"
echo "---"

EVENT_COUNT=0

# Main watch loop
inotifywait "${INOTIFY_ARGS[@]}" "$DIR" 2>/dev/null | while read -r line; do
  # Parse event and file
  EVENT_TYPE=$(echo "$line" | awk '{print $1}')
  FILE_PATH=$(echo "$line" | awk '{$1=""; print substr($0,2)}')

  # Apply filter
  if [[ -n "$FILTER" ]]; then
    if ! echo "$FILE_PATH" | grep -qE "$FILTER"; then
      continue
    fi
  fi

  # Debounce
  if [[ "$DEBOUNCE" -gt 0 ]]; then
    NOW=$(date +%s)
    if (( NOW - LAST_ACTION_TIME < DEBOUNCE )); then
      PENDING_FILE="$FILE_PATH"
      PENDING_EVENT="$EVENT_TYPE"
      continue
    fi
    LAST_ACTION_TIME=$NOW
  fi

  run_action "$FILE_PATH" "$EVENT_TYPE"

  # Count events
  EVENT_COUNT=$((EVENT_COUNT + 1))
  if [[ "$MAX_EVENTS" -gt 0 && "$EVENT_COUNT" -ge "$MAX_EVENTS" ]]; then
    echo "Reached max events ($MAX_EVENTS). Stopping."
    break
  fi
done
