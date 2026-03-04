#!/bin/bash
# Directory Watcher — Watch directories for file changes and trigger commands
# Requires: inotify-tools (Linux) or fswatch (macOS)
set -euo pipefail

# Defaults
DIR=""
EVENTS="create,modify,delete,move"
FILTER=""
EXCLUDE="node_modules,.git,__pycache__,.DS_Store"
ON_CHANGE=""
ON_CREATE=""
ON_MODIFY=""
ON_DELETE=""
RECURSIVE=false
DEBOUNCE="${WATCHER_DEBOUNCE:-1}"
LOG_FILE="${WATCHER_LOG:-}"
DAEMON=false
PID_FILE=""
MAX_EVENTS=0
QUIET=false
CONFIG=""
FORMAT="text"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  if [[ "$QUIET" != "true" ]]; then
    echo -e "$msg"
  fi
  if [[ -n "$LOG_FILE" ]]; then
    echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
  fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Watch directories for file changes and trigger commands.

Options:
  --dir DIR            Directory to watch (required)
  --events EVENTS      Events: create,modify,delete,move,attrib (default: create,modify,delete,move)
  --filter PATTERN     Glob patterns: "*.js,*.ts" (default: all)
  --exclude PATTERN    Patterns to exclude: "node_modules,.git"
  --on-change CMD      Command on any event (\$FILE, \$EVENT, \$DIR available)
  --on-create CMD      Command on create only
  --on-modify CMD      Command on modify only
  --on-delete CMD      Command on delete only
  --recursive          Watch subdirectories
  --debounce SECS      Debounce interval (default: 1)
  --log FILE           Log to file
  --daemon             Run as daemon
  --pid FILE           PID file (daemon mode)
  --max-events N       Stop after N events (0=unlimited)
  --quiet              Suppress stdout
  --config FILE        YAML config file
  --format FORMAT      Output: text or json (default: text)
  --help               Show this help

Environment:
  WATCHER_DEBOUNCE     Default debounce (seconds)
  WATCHER_LOG          Default log file
  WATCHER_EXCLUDE      Default exclude patterns

Examples:
  $(basename "$0") --dir ./src --on-change "npm run build" --debounce 3
  $(basename "$0") --dir /etc --filter "*.conf" --on-change "echo changed: \\\$FILE"
  $(basename "$0") --config watch-config.yaml
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dir) DIR="$2"; shift 2 ;;
    --events) EVENTS="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --on-change) ON_CHANGE="$2"; shift 2 ;;
    --on-create) ON_CREATE="$2"; shift 2 ;;
    --on-modify) ON_MODIFY="$2"; shift 2 ;;
    --on-delete) ON_DELETE="$2"; shift 2 ;;
    --recursive) RECURSIVE=true; shift ;;
    --debounce) DEBOUNCE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --daemon) DAEMON=true; shift ;;
    --pid) PID_FILE="$2"; shift 2 ;;
    --max-events) MAX_EVENTS="$2"; shift 2 ;;
    --quiet) QUIET=true; shift ;;
    --config) CONFIG="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect platform
detect_backend() {
  if command -v inotifywait &>/dev/null; then
    echo "inotify"
  elif command -v fswatch &>/dev/null; then
    echo "fswatch"
  else
    echo ""
  fi
}

BACKEND=$(detect_backend)

if [[ -z "$BACKEND" ]]; then
  echo -e "${RED}Error: Neither inotifywait nor fswatch found.${NC}"
  echo "Install: sudo apt-get install -y inotify-tools (Linux) or brew install fswatch (macOS)"
  exit 1
fi

# Validate
if [[ -z "$DIR" && -z "$CONFIG" ]]; then
  echo -e "${RED}Error: --dir or --config required${NC}"
  echo "Run with --help for usage"
  exit 1
fi

if [[ -n "$DIR" && ! -d "$DIR" ]]; then
  echo -e "${RED}Error: Directory not found: $DIR${NC}"
  exit 1
fi

# Debounce tracking
LAST_EVENT_TIME=0
DEBOUNCE_PID=""

run_command() {
  local cmd="$1"
  local file="$2"
  local event="$3"
  local dir="$4"

  if [[ -z "$cmd" ]]; then return; fi

  # Export variables for command
  export FILE="$file"
  export EVENT="$event"
  export DIR="$dir"

  local now
  now=$(date +%s)

  if [[ "$DEBOUNCE" -gt 0 ]]; then
    # Kill previous debounced command
    if [[ -n "$DEBOUNCE_PID" ]] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
      kill "$DEBOUNCE_PID" 2>/dev/null || true
      wait "$DEBOUNCE_PID" 2>/dev/null || true
    fi

    # Schedule debounced execution
    (
      sleep "$DEBOUNCE"
      log "${BLUE}⚡ Running:${NC} $cmd"
      local start
      start=$(date +%s%3N)
      if eval "$cmd" 2>&1; then
        local end
        end=$(date +%s%3N)
        local elapsed=$(( (end - start) ))
        log "${GREEN}✅ Command completed (exit: 0, ${elapsed}ms)${NC}"
      else
        local exit_code=$?
        log "${RED}❌ Command failed (exit: $exit_code)${NC}"
      fi
    ) &
    DEBOUNCE_PID=$!
  else
    log "${BLUE}⚡ Running:${NC} $cmd"
    if eval "$cmd" 2>&1; then
      log "${GREEN}✅ Command completed${NC}"
    else
      log "${RED}❌ Command failed (exit: $?)${NC}"
    fi
  fi
}

# Map event name to command
get_event_cmd() {
  local event="$1"
  case "$event" in
    CREATE|create) [[ -n "$ON_CREATE" ]] && echo "$ON_CREATE" || echo "$ON_CHANGE" ;;
    MODIFY|modify) [[ -n "$ON_MODIFY" ]] && echo "$ON_MODIFY" || echo "$ON_CHANGE" ;;
    DELETE|delete) [[ -n "$ON_DELETE" ]] && echo "$ON_DELETE" || echo "$ON_CHANGE" ;;
    *) echo "$ON_CHANGE" ;;
  esac
}

# Check if file matches filter
matches_filter() {
  local file="$1"
  if [[ -z "$FILTER" ]]; then return 0; fi

  local basename
  basename=$(basename "$file")
  IFS=',' read -ra patterns <<< "$FILTER"
  for pattern in "${patterns[@]}"; do
    pattern=$(echo "$pattern" | xargs) # trim
    # shellcheck disable=SC2254
    case "$basename" in
      $pattern) return 0 ;;
    esac
  done
  return 1
}

# Check if file matches exclude
matches_exclude() {
  local file="$1"
  if [[ -z "$EXCLUDE" ]]; then return 1; fi

  IFS=',' read -ra patterns <<< "$EXCLUDE"
  for pattern in "${patterns[@]}"; do
    pattern=$(echo "$pattern" | xargs)
    if [[ "$file" == *"$pattern"* ]]; then
      return 0
    fi
  done
  return 1
}

# Build inotifywait event flags
build_inotify_events() {
  local result=""
  IFS=',' read -ra evts <<< "$EVENTS"
  for evt in "${evts[@]}"; do
    evt=$(echo "$evt" | xargs | tr '[:lower:]' '[:upper:]')
    case "$evt" in
      CREATE) result="${result:+$result,}create" ;;
      MODIFY) result="${result:+$result,}modify,close_write" ;;
      DELETE) result="${result:+$result,}delete" ;;
      MOVE) result="${result:+$result,}moved_from,moved_to" ;;
      ATTRIB) result="${result:+$result,}attrib" ;;
    esac
  done
  echo "$result"
}

# Daemon mode
if [[ "$DAEMON" == "true" ]]; then
  if [[ -z "$PID_FILE" ]]; then
    PID_FILE="/tmp/directory-watcher-$(echo "$DIR" | md5sum | cut -c1-8).pid"
  fi
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Watcher already running (PID: $(cat "$PID_FILE"))"
    exit 1
  fi
  nohup "$0" --dir "$DIR" --events "$EVENTS" --filter "$FILTER" --exclude "$EXCLUDE" \
    --on-change "$ON_CHANGE" --debounce "$DEBOUNCE" --log "${LOG_FILE:-/tmp/watcher.log}" \
    ${RECURSIVE:+--recursive} --quiet > /dev/null 2>&1 &
  echo $! > "$PID_FILE"
  echo "Watcher started (PID: $!, PID file: $PID_FILE)"
  exit 0
fi

# Event counter
EVENT_COUNT=0

# Signal handler
cleanup() {
  log "${YELLOW}🛑 Watcher stopped${NC}"
  if [[ -n "$DEBOUNCE_PID" ]] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
    kill "$DEBOUNCE_PID" 2>/dev/null || true
  fi
  exit 0
}
trap cleanup SIGINT SIGTERM

# Build inotify arguments
INOTIFY_EVENTS=$(build_inotify_events)
INOTIFY_ARGS=(-m -e "$INOTIFY_EVENTS" --format '%w%f|%e')
if [[ "$RECURSIVE" == "true" ]]; then
  INOTIFY_ARGS+=(-r)
fi

# Build exclude regex for inotify
if [[ -n "$EXCLUDE" ]]; then
  EXCLUDE_REGEX=""
  IFS=',' read -ra patterns <<< "$EXCLUDE"
  for pattern in "${patterns[@]}"; do
    pattern=$(echo "$pattern" | xargs)
    EXCLUDE_REGEX="${EXCLUDE_REGEX:+$EXCLUDE_REGEX|}$pattern"
  done
  INOTIFY_ARGS+=(--exclude "$EXCLUDE_REGEX")
fi

# Print start message
WATCH_DESC="$DIR"
[[ "$RECURSIVE" == "true" ]] && WATCH_DESC="$WATCH_DESC (recursive"
[[ -n "$FILTER" ]] && WATCH_DESC="$WATCH_DESC, filter: $FILTER"
[[ "$RECURSIVE" == "true" || -n "$FILTER" ]] && WATCH_DESC="$WATCH_DESC)"
log "${GREEN}👁️ Watching:${NC} $WATCH_DESC"
log "${GREEN}   Events:${NC} $EVENTS"
log "${GREEN}   Backend:${NC} $BACKEND | Debounce: ${DEBOUNCE}s"
[[ -n "$ON_CHANGE" ]] && log "${GREEN}   On change:${NC} $ON_CHANGE"
echo ""

# Main watch loop
if [[ "$BACKEND" == "inotify" ]]; then
  inotifywait "${INOTIFY_ARGS[@]}" "$DIR" 2>/dev/null | while IFS='|' read -r file event; do
    # Apply filter
    if ! matches_filter "$file"; then continue; fi

    # Map event
    local_event="CHANGE"
    case "$event" in
      *CREATE*) local_event="CREATE" ;;
      *MODIFY*|*CLOSE_WRITE*) local_event="MODIFY" ;;
      *DELETE*) local_event="DELETE" ;;
      *MOVED*) local_event="MOVE" ;;
      *ATTRIB*) local_event="ATTRIB" ;;
    esac

    # Log event
    case "$local_event" in
      CREATE) log "${GREEN}📄 CREATE:${NC} $file" ;;
      MODIFY) log "${YELLOW}📝 MODIFY:${NC} $file" ;;
      DELETE) log "${RED}🗑️  DELETE:${NC} $file" ;;
      MOVE)   log "${BLUE}📦 MOVE:${NC} $file" ;;
      *)      log "📌 $local_event: $file" ;;
    esac

    # JSON format
    if [[ "$FORMAT" == "json" ]]; then
      echo "{\"file\":\"$file\",\"event\":\"$local_event\",\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    fi

    # Run command
    cmd=$(get_event_cmd "$local_event")
    if [[ -n "$cmd" ]]; then
      run_command "$cmd" "$file" "$local_event" "$DIR"
    fi

    # Event count
    EVENT_COUNT=$((EVENT_COUNT + 1))
    if [[ "$MAX_EVENTS" -gt 0 && "$EVENT_COUNT" -ge "$MAX_EVENTS" ]]; then
      log "Max events ($MAX_EVENTS) reached. Stopping."
      break
    fi
  done

elif [[ "$BACKEND" == "fswatch" ]]; then
  FSWATCH_ARGS=(-0)
  [[ "$RECURSIVE" == "true" ]] && FSWATCH_ARGS+=(-r)

  if [[ -n "$EXCLUDE" ]]; then
    IFS=',' read -ra patterns <<< "$EXCLUDE"
    for pattern in "${patterns[@]}"; do
      pattern=$(echo "$pattern" | xargs)
      FSWATCH_ARGS+=(-e "$pattern")
    done
  fi

  if [[ -n "$FILTER" ]]; then
    IFS=',' read -ra patterns <<< "$FILTER"
    for pattern in "${patterns[@]}"; do
      pattern=$(echo "$pattern" | xargs)
      # Convert glob to regex
      regex=$(echo "$pattern" | sed 's/\./\\./g; s/\*/\.\*/g')
      FSWATCH_ARGS+=(-i "$regex")
    done
  fi

  fswatch "${FSWATCH_ARGS[@]}" "$DIR" | while IFS= read -r -d '' file; do
    log "${YELLOW}📝 CHANGE:${NC} $file"

    if [[ -n "$ON_CHANGE" ]]; then
      run_command "$ON_CHANGE" "$file" "CHANGE" "$DIR"
    fi

    EVENT_COUNT=$((EVENT_COUNT + 1))
    if [[ "$MAX_EVENTS" -gt 0 && "$EVENT_COUNT" -ge "$MAX_EVENTS" ]]; then
      log "Max events ($MAX_EVENTS) reached. Stopping."
      break
    fi
  done
fi
