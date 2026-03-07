#!/usr/bin/env bash
# File Watcher & Trigger — watch files/dirs and run commands on changes
# Requires: inotify-tools (Linux) or fswatch (macOS)

set -euo pipefail

VERSION="1.0.0"
PID_DIR="/tmp"

# Defaults
WATCH_PATH=""
EVENTS="create,modify,delete"
RUN_CMD=""
RECURSIVE=false
FILTER=""
EXCLUDE=""
DEBOUNCE=0
MAX_RUNS=0
LOG_FILE=""
DAEMON=false
QUIET=false
CONFIG_FILE=""
ACTION=""
STOP_TARGET=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { [[ "$QUIET" == "true" ]] && return; echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
log_to_file() { [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

usage() {
  cat <<EOF
File Watcher & Trigger v${VERSION}

Usage: bash watch.sh --path <path> --events <events> --run '<command>'

Options:
  --path <path>         File or directory to watch (required)
  --events <events>     Comma-separated: create,modify,delete,move,close_write,attrib
  --run <command>       Command to execute on event (required)
  --recursive           Watch subdirectories
  --filter <regex>      Only trigger for filenames matching regex
  --exclude <regex>     Ignore filenames matching regex
  --debounce <seconds>  Wait N seconds after event before running
  --max-runs <N>        Stop after N triggers (0 = unlimited)
  --log <file>          Log events to file
  --daemon              Run in background
  --quiet               Suppress event output
  --config <file>       Use YAML config file
  --list                List active watchers
  --stop <name|pid>     Stop a watcher
  --stop-all            Stop all watchers
  --version             Show version
  --help                Show this help

Environment variables available in --run commands:
  \$WATCH_FILE    Full path of changed file
  \$WATCH_EVENT   Event type (CREATE, MODIFY, DELETE, etc.)
  \$WATCH_DIR     Watched directory
  \$WATCH_NAME    Filename only
  \$WATCH_TIME    ISO timestamp

Examples:
  # Watch for new files
  bash watch.sh --path /uploads --events create --run 'echo "New: \$WATCH_FILE"'

  # Auto-reload nginx on config change
  bash watch.sh --path /etc/nginx/ --recursive --events modify --run 'nginx -t && systemctl reload nginx'

  # Watch with debounce (for editors that save multiple times)
  bash watch.sh --path ./src --recursive --filter '\.py$' --debounce 2 --run 'make build'
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --path) WATCH_PATH="$2"; shift 2 ;;
    --events) EVENTS="$2"; shift 2 ;;
    --run) RUN_CMD="$2"; shift 2 ;;
    --recursive) RECURSIVE=true; shift ;;
    --filter) FILTER="$2"; shift 2 ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --debounce) DEBOUNCE="$2"; shift 2 ;;
    --max-runs) MAX_RUNS="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --daemon) DAEMON=true; shift ;;
    --quiet) QUIET=true; shift ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --list) ACTION="list"; shift ;;
    --stop) ACTION="stop"; STOP_TARGET="$2"; shift 2 ;;
    --stop-all) ACTION="stop-all"; shift ;;
    --version) echo "File Watcher v${VERSION}"; exit 0 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Management Actions ---

list_watchers() {
  echo -e "${BLUE}Active File Watchers:${NC}"
  local found=false
  for pidfile in "$PID_DIR"/file-watcher-*.pid; do
    [[ -f "$pidfile" ]] || continue
    local pid
    pid=$(cat "$pidfile")
    local name
    name=$(basename "$pidfile" .pid | sed 's/file-watcher-//')
    if kill -0 "$pid" 2>/dev/null; then
      echo -e "  ${GREEN}●${NC} $name (PID: $pid)"
      found=true
    else
      rm -f "$pidfile"
    fi
  done
  [[ "$found" == "false" ]] && echo "  No active watchers"
}

stop_watcher() {
  local target="$1"
  # Try as PID first
  if [[ "$target" =~ ^[0-9]+$ ]] && kill -0 "$target" 2>/dev/null; then
    kill "$target" 2>/dev/null && echo -e "${GREEN}✅ Stopped PID $target${NC}"
    return
  fi
  # Try as name
  local pidfile="$PID_DIR/file-watcher-${target}.pid"
  if [[ -f "$pidfile" ]]; then
    local pid
    pid=$(cat "$pidfile")
    kill "$pid" 2>/dev/null && echo -e "${GREEN}✅ Stopped $target (PID: $pid)${NC}"
    rm -f "$pidfile"
    return
  fi
  echo -e "${RED}❌ Watcher not found: $target${NC}"
}

stop_all() {
  local count=0
  for pidfile in "$PID_DIR"/file-watcher-*.pid; do
    [[ -f "$pidfile" ]] || continue
    local pid
    pid=$(cat "$pidfile")
    kill "$pid" 2>/dev/null && ((count++))
    rm -f "$pidfile"
  done
  echo -e "${GREEN}✅ Stopped $count watcher(s)${NC}"
}

case "${ACTION:-}" in
  list) list_watchers; exit 0 ;;
  stop) stop_watcher "$STOP_TARGET"; exit 0 ;;
  stop-all) stop_all; exit 0 ;;
esac

# --- Config File Support ---

if [[ -n "$CONFIG_FILE" ]]; then
  if ! command -v yq &>/dev/null; then
    echo -e "${RED}❌ yq required for YAML config. Install: pip install yq${NC}"
    exit 1
  fi
  echo -e "${BLUE}📋 Loading config: $CONFIG_FILE${NC}"
  count=$(yq -r '.watchers | length' "$CONFIG_FILE")
  for ((i=0; i<count; i++)); do
    w_path=$(yq -r ".watchers[$i].path" "$CONFIG_FILE")
    w_events=$(yq -r ".watchers[$i].events | join(\",\")" "$CONFIG_FILE")
    w_run=$(yq -r ".watchers[$i].run" "$CONFIG_FILE")
    w_filter=$(yq -r ".watchers[$i].filter // \"\"" "$CONFIG_FILE")
    w_debounce=$(yq -r ".watchers[$i].debounce // 0" "$CONFIG_FILE")
    w_recursive=$(yq -r ".watchers[$i].recursive // false" "$CONFIG_FILE")
    w_name=$(yq -r ".watchers[$i].name // \"watcher-$i\"" "$CONFIG_FILE")

    args=("$0" --path "$w_path" --events "$w_events" --run "$w_run" --daemon)
    [[ -n "$w_filter" ]] && args+=(--filter "$w_filter")
    [[ "$w_debounce" != "0" ]] && args+=(--debounce "$w_debounce")
    [[ "$w_recursive" == "true" ]] && args+=(--recursive)

    echo -e "  ${GREEN}▶${NC} Starting: $w_name"
    bash "${args[@]}"
  done
  echo -e "${GREEN}✅ All watchers started${NC}"
  exit 0
fi

# --- Validation ---

if [[ -z "$WATCH_PATH" ]]; then
  echo -e "${RED}❌ --path is required${NC}"
  echo "Run with --help for usage"
  exit 1
fi

if [[ -z "$RUN_CMD" ]]; then
  echo -e "${RED}❌ --run is required${NC}"
  echo "Run with --help for usage"
  exit 1
fi

if [[ ! -e "$WATCH_PATH" ]]; then
  echo -e "${RED}❌ Path does not exist: $WATCH_PATH${NC}"
  exit 1
fi

# Detect platform
USE_FSWATCH=false
if [[ "$(uname)" == "Darwin" ]]; then
  if command -v fswatch &>/dev/null; then
    USE_FSWATCH=true
  else
    echo -e "${RED}❌ macOS detected — install fswatch: brew install fswatch${NC}"
    exit 1
  fi
else
  if ! command -v inotifywait &>/dev/null; then
    echo -e "${RED}❌ inotify-tools not installed${NC}"
    echo "Install: sudo apt-get install -y inotify-tools"
    exit 1
  fi
fi

# --- Daemon Mode ---

if [[ "$DAEMON" == "true" ]]; then
  hash=$(echo "$WATCH_PATH" | md5sum | cut -c1-8)
  pidfile="$PID_DIR/file-watcher-${hash}.pid"
  
  # Re-run without --daemon, in background
  args=()
  [[ -n "$WATCH_PATH" ]] && args+=(--path "$WATCH_PATH")
  [[ -n "$EVENTS" ]] && args+=(--events "$EVENTS")
  [[ -n "$RUN_CMD" ]] && args+=(--run "$RUN_CMD")
  [[ "$RECURSIVE" == "true" ]] && args+=(--recursive)
  [[ -n "$FILTER" ]] && args+=(--filter "$FILTER")
  [[ -n "$EXCLUDE" ]] && args+=(--exclude "$EXCLUDE")
  [[ "$DEBOUNCE" != "0" ]] && args+=(--debounce "$DEBOUNCE")
  [[ "$MAX_RUNS" != "0" ]] && args+=(--max-runs "$MAX_RUNS")
  [[ -n "$LOG_FILE" ]] && args+=(--log "$LOG_FILE")

  nohup bash "$0" "${args[@]}" > /dev/null 2>&1 &
  echo $! > "$pidfile"
  echo -e "${GREEN}✅ Watcher started in background (PID: $!, pidfile: $pidfile)${NC}"
  exit 0
fi

# --- Convert events to inotifywait format ---

map_events() {
  local input="$1"
  local mapped=""
  IFS=',' read -ra evts <<< "$input"
  for e in "${evts[@]}"; do
    case "$e" in
      create) mapped+="create," ;;
      modify) mapped+="modify," ;;
      delete) mapped+="delete," ;;
      move) mapped+="moved_to,moved_from," ;;
      close_write) mapped+="close_write," ;;
      attrib) mapped+="attrib," ;;
      *) mapped+="${e}," ;;
    esac
  done
  echo "${mapped%,}"
}

INOTIFY_EVENTS=$(map_events "$EVENTS")

# --- Main Watch Loop ---

run_count=0
last_run=0

log "${BLUE}👁️ Watching ${WATCH_PATH} for ${EVENTS} events${NC}"
[[ "$RECURSIVE" == "true" ]] && log "   Recursive: yes"
[[ -n "$FILTER" ]] && log "   Filter: $FILTER"
[[ -n "$EXCLUDE" ]] && log "   Exclude: $EXCLUDE"
[[ "$DEBOUNCE" -gt 0 ]] && log "   Debounce: ${DEBOUNCE}s"

# Build inotifywait command
INOTIFY_CMD=(inotifywait -m -e "$INOTIFY_EVENTS" --format '%w%f|%e|%f')
[[ "$RECURSIVE" == "true" ]] && INOTIFY_CMD+=(-r)
[[ -n "$EXCLUDE" ]] && INOTIFY_CMD+=(--exclude "$EXCLUDE")
INOTIFY_CMD+=("$WATCH_PATH")

if [[ "$USE_FSWATCH" == "true" ]]; then
  # macOS fswatch fallback
  FSWATCH_CMD=(fswatch -0)
  [[ "$RECURSIVE" != "true" ]] && FSWATCH_CMD+=(--no-defer)
  [[ -n "$FILTER" ]] && FSWATCH_CMD+=(--include "$FILTER" --exclude '.*')
  [[ -n "$EXCLUDE" ]] && FSWATCH_CMD+=(--exclude "$EXCLUDE")
  FSWATCH_CMD+=("$WATCH_PATH")

  "${FSWATCH_CMD[@]}" | while IFS= read -r -d '' filepath; do
    filename=$(basename "$filepath")
    event="CHANGE"
    now=$(date +%s)

    if [[ "$DEBOUNCE" -gt 0 ]] && [[ $((now - last_run)) -lt "$DEBOUNCE" ]]; then
      continue
    fi
    last_run=$now

    export WATCH_FILE="$filepath"
    export WATCH_EVENT="$event"
    export WATCH_DIR="$(dirname "$filepath")"
    export WATCH_NAME="$filename"
    export WATCH_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    log "📁 ${YELLOW}${event}${NC}: ${filename} → Running command"
    log_to_file "$event: $filepath"

    eval "$RUN_CMD" || log "${RED}⚠️ Command exited with error${NC}"

    ((run_count++))
    if [[ "$MAX_RUNS" -gt 0 ]] && [[ "$run_count" -ge "$MAX_RUNS" ]]; then
      log "${GREEN}✅ Reached max-runs ($MAX_RUNS). Stopping.${NC}"
      exit 0
    fi
  done
else
  # Linux inotifywait
  "${INOTIFY_CMD[@]}" | while IFS='|' read -r filepath event filename; do
    # Apply filter
    if [[ -n "$FILTER" ]] && ! echo "$filename" | grep -qE "$FILTER"; then
      continue
    fi

    now=$(date +%s)

    # Debounce
    if [[ "$DEBOUNCE" -gt 0 ]] && [[ $((now - last_run)) -lt "$DEBOUNCE" ]]; then
      continue
    fi
    last_run=$now

    export WATCH_FILE="$filepath"
    export WATCH_EVENT="$event"
    export WATCH_DIR="$(dirname "$filepath")"
    export WATCH_NAME="$filename"
    export WATCH_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    log "📁 ${YELLOW}${event}${NC}: ${filename} → Running command"
    log_to_file "$event: $filepath"

    eval "$RUN_CMD" || log "${RED}⚠️ Command exited with error${NC}"

    ((run_count++)) || true
    if [[ "$MAX_RUNS" -gt 0 ]] && [[ "$run_count" -ge "$MAX_RUNS" ]]; then
      log "${GREEN}✅ Reached max-runs ($MAX_RUNS). Stopping.${NC}"
      exit 0
    fi
  done
fi
