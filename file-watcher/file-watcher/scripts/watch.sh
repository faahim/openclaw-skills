#!/bin/bash
# File Watcher — Monitor files/dirs and trigger commands on changes
# Requires: inotify-tools (inotifywait)

set -euo pipefail

# Defaults
DIR="${WATCH_DIR:-.}"
EVENTS="${WATCH_EVENTS:-modify,create,delete,move}"
EXT=""
EXCLUDE="${WATCH_EXCLUDE:-}"
ON_CHANGE=""
DEBOUNCE="${WATCH_DEBOUNCE:-1}"
LOG_FILE=""
RECURSIVE=true
DAEMON=false
PIDFILE="/tmp/file-watcher.pid"
CONFIG=""
STATUS=false
STOP=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --dir DIR           Directory to watch (default: .)
  --events EVENTS     Comma-separated events: modify,create,delete,move,attrib,close_write
  --ext EXTENSIONS    Filter by extensions: .js,.ts,.py
  --exclude REGEX     Exclude pattern (regex): node_modules|\.git
  --on-change CMD     Command to run (\$FILE = changed file, \$EVENT = event type)
  --debounce SECS     Wait before running command (default: 1)
  --log FILE          Log output to file
  --no-recursive      Don't watch subdirectories
  --daemon            Run in background
  --pidfile FILE      PID file for daemon mode (default: /tmp/file-watcher.pid)
  --config FILE       YAML config with multiple watch rules
  --status            Check if daemon is running
  --stop              Stop daemon
  -h, --help          Show this help

Examples:
  $(basename "$0") --dir ./src --on-change "npm test" --debounce 3
  $(basename "$0") --dir ./uploads --events create --ext ".jpg,.png" --on-change 'echo "New: \$FILE"'
  $(basename "$0") --dir ./src --on-change "make build" --daemon
EOF
  exit 0
}

log_msg() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo -e "$msg"
  [[ -n "$LOG_FILE" ]] && echo -e "$msg" >> "$LOG_FILE"
}

check_deps() {
  if ! command -v inotifywait &>/dev/null; then
    echo -e "${RED}Error: inotifywait not found. Install inotify-tools:${NC}"
    echo "  Ubuntu/Debian: sudo apt-get install -y inotify-tools"
    echo "  Fedora/RHEL:   sudo dnf install -y inotify-tools"
    echo "  Alpine:        sudo apk add inotify-tools"
    echo "  Arch:          sudo pacman -S inotify-tools"
    exit 1
  fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dir) DIR="$2"; shift 2 ;;
    --events) EVENTS="$2"; shift 2 ;;
    --ext) EXT="$2"; shift 2 ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --on-change) ON_CHANGE="$2"; shift 2 ;;
    --debounce) DEBOUNCE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --no-recursive) RECURSIVE=false; shift ;;
    --daemon) DAEMON=true; shift ;;
    --pidfile) PIDFILE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --status) STATUS=true; shift ;;
    --stop) STOP=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Handle --status
if $STATUS; then
  if [[ -f "$PIDFILE" ]]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
      echo -e "${GREEN}✅ File watcher running (PID: $PID)${NC}"
      exit 0
    else
      echo -e "${YELLOW}⚠️ PID file exists but process not running. Cleaning up.${NC}"
      rm -f "$PIDFILE"
      exit 1
    fi
  else
    echo -e "${RED}❌ No file watcher running (no PID file at $PIDFILE)${NC}"
    exit 1
  fi
fi

# Handle --stop
if $STOP; then
  if [[ -f "$PIDFILE" ]]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID"
      rm -f "$PIDFILE"
      echo -e "${GREEN}✅ File watcher stopped (PID: $PID)${NC}"
      exit 0
    else
      rm -f "$PIDFILE"
      echo -e "${YELLOW}⚠️ Process already stopped. Cleaned up PID file.${NC}"
      exit 0
    fi
  else
    echo -e "${RED}❌ No PID file found at $PIDFILE${NC}"
    exit 1
  fi
fi

check_deps

# Handle config file mode
if [[ -n "$CONFIG" ]]; then
  if ! command -v yq &>/dev/null; then
    echo -e "${RED}Error: yq required for config files. Install: pip install yq${NC}"
    exit 1
  fi

  RULE_COUNT=$(yq -r '.rules | length' "$CONFIG")
  echo -e "${CYAN}📋 Loading $RULE_COUNT watch rules from $CONFIG${NC}"

  for i in $(seq 0 $((RULE_COUNT - 1))); do
    RULE_NAME=$(yq -r ".rules[$i].name" "$CONFIG")
    RULE_DIR=$(yq -r ".rules[$i].dir" "$CONFIG")
    RULE_EVENTS=$(yq -r ".rules[$i].events | join(\",\")" "$CONFIG")
    RULE_EXT=$(yq -r "(.rules[$i].ext // []) | join(\",\")" "$CONFIG")
    RULE_CMD=$(yq -r ".rules[$i].on_change" "$CONFIG")
    RULE_DEBOUNCE=$(yq -r ".rules[$i].debounce // 1" "$CONFIG")

    echo -e "${GREEN}  ▶ $RULE_NAME: watching $RULE_DIR${NC}"

    # Spawn each rule as a background process
    bash "$0" \
      --dir "$RULE_DIR" \
      --events "$RULE_EVENTS" \
      ${RULE_EXT:+--ext "$RULE_EXT"} \
      --on-change "$RULE_CMD" \
      --debounce "$RULE_DEBOUNCE" &
  done

  echo -e "${CYAN}All watchers started. Press Ctrl+C to stop all.${NC}"
  wait
  exit 0
fi

# Validate required args
if [[ -z "$ON_CHANGE" ]]; then
  echo -e "${RED}Error: --on-change is required${NC}"
  echo "Example: $(basename "$0") --dir ./src --on-change \"npm test\""
  exit 1
fi

if [[ ! -d "$DIR" ]]; then
  echo -e "${RED}Error: Directory '$DIR' does not exist${NC}"
  exit 1
fi

# Build inotifywait args
INOTIFY_ARGS=()
$RECURSIVE && INOTIFY_ARGS+=("-r")
INOTIFY_ARGS+=("-m")  # monitor mode (continuous)
INOTIFY_ARGS+=("-e" "$EVENTS")

# Exclude pattern
if [[ -n "$EXCLUDE" ]]; then
  INOTIFY_ARGS+=("--exclude" "$EXCLUDE")
fi

INOTIFY_ARGS+=("--format" "%w%f %e")
INOTIFY_ARGS+=("$DIR")

# Build extension filter
EXT_FILTER=""
if [[ -n "$EXT" ]]; then
  IFS=',' read -ra EXTS <<< "$EXT"
  for e in "${EXTS[@]}"; do
    e=$(echo "$e" | sed 's/^\.//')  # strip leading dot
    [[ -n "$EXT_FILTER" ]] && EXT_FILTER+="|"
    EXT_FILTER+="\\.${e}$"
  done
fi

# Daemon mode
if $DAEMON; then
  nohup bash "$0" \
    --dir "$DIR" \
    --events "$EVENTS" \
    ${EXT:+--ext "$EXT"} \
    ${EXCLUDE:+--exclude "$EXCLUDE"} \
    --on-change "$ON_CHANGE" \
    --debounce "$DEBOUNCE" \
    ${LOG_FILE:+--log "$LOG_FILE"} \
    $($RECURSIVE || echo "--no-recursive") \
    > /dev/null 2>&1 &

  echo $! > "$PIDFILE"
  echo -e "${GREEN}✅ File watcher started in background (PID: $!)${NC}"
  echo -e "   PID file: $PIDFILE"
  echo -e "   Stop with: $(basename "$0") --stop --pidfile $PIDFILE"
  exit 0
fi

# Main watch loop
log_msg "${CYAN}👁️ Watching: $DIR (events: $EVENTS)${NC}"
[[ -n "$EXT" ]] && log_msg "${CYAN}   Extensions: $EXT${NC}"
[[ -n "$EXCLUDE" ]] && log_msg "${CYAN}   Excluding: $EXCLUDE${NC}"
log_msg "${CYAN}   Debounce: ${DEBOUNCE}s${NC}"
log_msg "${CYAN}   Command: $ON_CHANGE${NC}"
echo ""

LAST_RUN=0

inotifywait "${INOTIFY_ARGS[@]}" 2>/dev/null | while read -r line; do
  FILE=$(echo "$line" | awk '{print $1}')
  EVENT=$(echo "$line" | awk '{print $2}')

  # Extension filter
  if [[ -n "$EXT_FILTER" ]]; then
    if ! echo "$FILE" | grep -qE "$EXT_FILTER"; then
      continue
    fi
  fi

  # Event icon
  case "$EVENT" in
    *CREATE*) ICON="🆕" ;;
    *MODIFY*) ICON="📝" ;;
    *DELETE*) ICON="🗑️" ;;
    *MOVED*|*MOVE*) ICON="📦" ;;
    *ATTRIB*) ICON="🔒" ;;
    *) ICON="📄" ;;
  esac

  log_msg "${GREEN}${ICON} ${EVENT}: ${FILE}${NC}"

  # Debounce
  NOW=$(date +%s)
  if (( NOW - LAST_RUN < DEBOUNCE )); then
    continue
  fi
  LAST_RUN=$NOW

  # Run command with FILE and EVENT as env vars
  export FILE EVENT
  eval "$ON_CHANGE" 2>&1 | while IFS= read -r out_line; do
    log_msg "   ${out_line}"
  done || true
done
