#!/bin/bash
# File Watcher & Trigger — Main script
# Uses inotifywait to watch directories and trigger actions on file changes
set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="/tmp/file-watcher"
LOG_FILE=""
POLL_MODE=false
POLL_INTERVAL=5

# Defaults
DIR=""
EVENTS="create,modify,delete,move"
ACTION=""
CONFIG=""
RECURSIVE=false
FILTER=""
EXCLUDE=""
DEBOUNCE=1
DAEMON=false
STATUS_MODE=false
STOP_ALL=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$msg"
    [[ -n "$LOG_FILE" ]] && echo -e "$msg" >> "$LOG_FILE"
}

usage() {
    cat <<EOF
File Watcher & Trigger v${VERSION}

Usage: bash watch.sh [OPTIONS]

Options:
  --dir <path>        Directory to watch
  --events <list>     Events: create,modify,delete,move,attrib,close_write
  --action <cmd>      Shell command (receives \$WATCH_FILE, \$WATCH_EVENT, \$WATCH_DIR)
  --config <file>     YAML config for multiple watchers
  --recursive         Watch subdirectories
  --filter <regex>    Only trigger on matching filenames
  --exclude <regex>   Skip matching filenames
  --debounce <secs>   Seconds to wait before triggering (default: 1)
  --daemon            Run in background
  --log <file>        Log to file
  --poll <secs>       Use polling instead of inotify (for NFS/CIFS)
  --status            Show running watchers
  --stop-all          Stop all running watchers
  --help              Show this help
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir) DIR="$2"; shift 2 ;;
        --events) EVENTS="$2"; shift 2 ;;
        --action) ACTION="$2"; shift 2 ;;
        --config) CONFIG="$2"; shift 2 ;;
        --recursive) RECURSIVE=true; shift ;;
        --filter) FILTER="$2"; shift 2 ;;
        --exclude) EXCLUDE="$2"; shift 2 ;;
        --debounce) DEBOUNCE="$2"; shift 2 ;;
        --daemon) DAEMON=true; shift ;;
        --log) LOG_FILE="$2"; shift 2 ;;
        --poll) POLL_MODE=true; POLL_INTERVAL="$2"; shift 2 ;;
        --status) STATUS_MODE=true; shift ;;
        --stop-all) STOP_ALL=true; shift ;;
        --help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

mkdir -p "$PID_DIR"

# Status mode
if $STATUS_MODE; then
    echo -e "${BLUE}=== File Watcher Status ===${NC}"
    found=false
    shopt -s nullglob
    for pidfile in "$PID_DIR"/*.pid; do
        found=true
        pid=$(cat "$pidfile")
        name=$(basename "$pidfile" .pid)
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  ${GREEN}●${NC} $name (PID $pid) — running"
        else
            echo -e "  ${RED}●${NC} $name (PID $pid) — dead (removing stale PID)"
            rm -f "$pidfile"
        fi
    done
    shopt -u nullglob
    $found || echo "  No watchers running."
    exit 0
fi

# Stop all mode
if $STOP_ALL; then
    echo -e "${YELLOW}Stopping all watchers...${NC}"
    shopt -s nullglob
    for pidfile in "$PID_DIR"/*.pid; do
        pid=$(cat "$pidfile")
        name=$(basename "$pidfile" .pid)
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null && echo -e "  ${RED}■${NC} Stopped $name (PID $pid)"
        fi
        rm -f "$pidfile"
    done
    shopt -u nullglob
    exit 0
fi

# Check dependencies
if ! command -v inotifywait &>/dev/null && ! $POLL_MODE; then
    echo -e "${RED}Error: inotifywait not found${NC}"
    echo "Install: sudo apt-get install -y inotify-tools"
    echo "Or use --poll <seconds> for polling mode"
    exit 1
fi

# Config mode: parse YAML and launch multiple watchers
if [[ -n "$CONFIG" ]]; then
    if [[ ! -f "$CONFIG" ]]; then
        echo -e "${RED}Error: Config file not found: $CONFIG${NC}"
        exit 1
    fi

    log "${BLUE}📋 Loading config: $CONFIG${NC}"

    # Simple YAML parser (no yq dependency)
    # Extracts watcher blocks
    current_name=""
    current_dir=""
    current_events=""
    current_action=""
    current_recursive=""
    current_filter=""
    current_exclude=""
    current_debounce=""
    watcher_count=0

    launch_watcher() {
        [[ -z "$current_dir" || -z "$current_action" ]] && return
        watcher_count=$((watcher_count + 1))
        local args=("--dir" "$current_dir")
        [[ -n "$current_events" ]] && args+=("--events" "$current_events")
        args+=("--action" "$current_action")
        [[ "$current_recursive" == "true" ]] && args+=("--recursive")
        [[ -n "$current_filter" ]] && args+=("--filter" "$current_filter")
        [[ -n "$current_exclude" ]] && args+=("--exclude" "$current_exclude")
        [[ -n "$current_debounce" ]] && args+=("--debounce" "$current_debounce")
        args+=("--daemon")
        [[ -n "$LOG_FILE" ]] && args+=("--log" "$LOG_FILE")

        local label="${current_name:-watcher-$watcher_count}"
        log "  ${GREEN}▶${NC} Starting: $label → $current_dir"
        bash "$0" "${args[@]}"
    }

    in_watcher=false
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Detect new watcher block
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name: ]]; then
            # Launch previous watcher if exists
            $in_watcher && launch_watcher
            in_watcher=true
            current_name=$(echo "$line" | sed 's/.*name:[[:space:]]*//' | tr -d '"'"'")
            current_dir="" current_events="" current_action=""
            current_recursive="" current_filter="" current_exclude="" current_debounce=""
            continue
        fi

        $in_watcher || continue

        # Parse fields
        if [[ "$line" =~ ^[[:space:]]+dir: ]]; then
            current_dir=$(echo "$line" | sed 's/.*dir:[[:space:]]*//' | tr -d '"'"'" | envsubst 2>/dev/null || echo "$line" | sed 's/.*dir:[[:space:]]*//' | tr -d '"'"'")
            current_dir="${current_dir/#\~/$HOME}"
        elif [[ "$line" =~ ^[[:space:]]+events: ]]; then
            current_events=$(echo "$line" | sed 's/.*events:[[:space:]]*//' | tr -d '[]"'"'" | tr ',' ',' | sed 's/[[:space:]]//g')
        elif [[ "$line" =~ ^[[:space:]]+action: ]]; then
            current_action=$(echo "$line" | sed "s/.*action:[[:space:]]*//" | tr -d '"'"'")
        elif [[ "$line" =~ ^[[:space:]]+recursive: ]]; then
            current_recursive=$(echo "$line" | sed 's/.*recursive:[[:space:]]*//' | tr -d '"'"'")
        elif [[ "$line" =~ ^[[:space:]]+filter: ]]; then
            current_filter=$(echo "$line" | sed "s/.*filter:[[:space:]]*//" | tr -d '"'"'")
        elif [[ "$line" =~ ^[[:space:]]+exclude: ]]; then
            current_exclude=$(echo "$line" | sed "s/.*exclude:[[:space:]]*//" | tr -d '"'"'")
        elif [[ "$line" =~ ^[[:space:]]+debounce: ]]; then
            current_debounce=$(echo "$line" | sed 's/.*debounce:[[:space:]]*//' | tr -d '"'"'")
        fi
    done < "$CONFIG"

    # Launch last watcher
    $in_watcher && launch_watcher

    log "${GREEN}✅ Started $watcher_count watcher(s)${NC}"
    exit 0
fi

# Single watcher mode
if [[ -z "$DIR" ]]; then
    echo -e "${RED}Error: --dir required (or use --config)${NC}"
    usage
fi

DIR="${DIR/#\~/$HOME}"

if [[ ! -d "$DIR" ]]; then
    echo -e "${RED}Error: Directory not found: $DIR${NC}"
    exit 1
fi

# Daemon mode
if $DAEMON; then
    watcher_name=$(echo "$DIR" | tr '/' '-' | sed 's/^-//')
    nohup bash "$0" --dir "$DIR" --events "$EVENTS" --action "$ACTION" \
        ${RECURSIVE:+--recursive} \
        ${FILTER:+--filter "$FILTER"} \
        ${EXCLUDE:+--exclude "$EXCLUDE"} \
        --debounce "$DEBOUNCE" \
        ${LOG_FILE:+--log "$LOG_FILE"} \
        > /dev/null 2>&1 &

    echo $! > "$PID_DIR/${watcher_name}.pid"
    log "  ${GREEN}✅${NC} Daemon started (PID $!) watching $DIR"
    exit 0
fi

# Build inotifywait args
INOTIFY_ARGS=(-m -q)
$RECURSIVE && INOTIFY_ARGS+=(-r)

# Convert events
IFS=',' read -ra EVENT_LIST <<< "$EVENTS"
for evt in "${EVENT_LIST[@]}"; do
    INOTIFY_ARGS+=(-e "$evt")
done

[[ -n "$EXCLUDE" ]] && INOTIFY_ARGS+=(--exclude "$EXCLUDE")

INOTIFY_ARGS+=("$DIR")

log "${BLUE}👁️  Watching: $DIR (${EVENTS})${NC}"
$RECURSIVE && log "   ${BLUE}↳ Recursive: yes${NC}"
[[ -n "$FILTER" ]] && log "   ${BLUE}↳ Filter: $FILTER${NC}"
[[ -n "$EXCLUDE" ]] && log "   ${BLUE}↳ Exclude: $EXCLUDE${NC}"
log "   ${BLUE}↳ Debounce: ${DEBOUNCE}s${NC}"

# Debounce tracking
declare -A LAST_TRIGGER

# Polling mode fallback
if $POLL_MODE; then
    log "${YELLOW}⚠️  Using polling mode (${POLL_INTERVAL}s interval)${NC}"
    declare -A FILE_HASHES

    # Initial snapshot
    while IFS= read -r f; do
        FILE_HASHES["$f"]=$(stat -c '%Y%s' "$f" 2>/dev/null || echo "0")
    done < <(find "$DIR" ${RECURSIVE:+-maxdepth 999} ! $RECURSIVE && echo "-maxdepth 1" | xargs find "$DIR" -type f 2>/dev/null)

    while true; do
        sleep "$POLL_INTERVAL"
        while IFS= read -r f; do
            current=$(stat -c '%Y%s' "$f" 2>/dev/null || echo "0")
            prev="${FILE_HASHES[$f]:-}"
            if [[ "$current" != "$prev" ]]; then
                FILE_HASHES["$f"]="$current"
                [[ -z "$prev" ]] && event="CREATE" || event="MODIFY"

                # Apply filter
                if [[ -n "$FILTER" ]] && ! echo "$f" | grep -qE "$FILTER"; then
                    continue
                fi

                export WATCH_FILE="$f"
                export WATCH_EVENT="$event"
                export WATCH_DIR="$DIR"
                export WATCH_NAME="$(basename "$f")"
                export WATCH_EXT="${f##*.}"

                log "⚡ ${event}: $f"
                if [[ -n "$ACTION" ]]; then
                    eval "$ACTION" 2>&1 | while IFS= read -r line; do
                        log "   → $line"
                    done
                fi
            fi
        done < <(find "$DIR" -type f 2>/dev/null)
    done
    exit 0
fi

# Main inotifywait loop with debounce
inotifywait "${INOTIFY_ARGS[@]}" --format '%w %e %f' | while read -r dir event file; do
    filepath="${dir}${file}"

    # Apply filter
    if [[ -n "$FILTER" ]] && ! echo "$file" | grep -qE "$FILTER"; then
        continue
    fi

    # Debounce: skip if same file triggered within debounce window
    now=$(date +%s)
    key="${filepath}:${event}"
    last="${LAST_TRIGGER[$key]:-0}"
    if (( now - last < DEBOUNCE )); then
        continue
    fi
    LAST_TRIGGER[$key]=$now

    # Export env vars for action
    export WATCH_FILE="$filepath"
    export WATCH_EVENT="$event"
    export WATCH_DIR="$dir"
    export WATCH_NAME="$file"
    export WATCH_EXT="${file##*.}"

    log "⚡ ${event}: ${filepath}"

    # Run action
    if [[ -n "$ACTION" ]]; then
        (
            eval "$ACTION" 2>&1 | while IFS= read -r line; do
                log "   → $line"
            done
        ) &
    fi
done
