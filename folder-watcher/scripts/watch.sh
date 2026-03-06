#!/bin/bash
# Folder Watcher — monitor directories and trigger actions on file changes
set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
WATCH_DIR=""
EVENTS="create,modify,delete,moved_to,moved_from"
ACTION="log"
LOGFILE=""
SCRIPT_CMD=""
DEST_DIR=""
CONFIG=""
RECURSIVE=""
EXCLUDE=""
DEBOUNCE=0
MIN_SIZE=""
NOTIFY=""
ORGANIZE_CONFIG=""

# ─── Parse Arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --dir) WATCH_DIR="$2"; shift 2 ;;
    --events) EVENTS="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --logfile) LOGFILE="$2"; shift 2 ;;
    --script) SCRIPT_CMD="$2"; shift 2 ;;
    --dest) DEST_DIR="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --recursive) RECURSIVE="--recursive"; shift ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --debounce) DEBOUNCE="$2"; shift 2 ;;
    --min-size) MIN_SIZE="$2"; shift 2 ;;
    --notify) NOTIFY="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: watch.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --dir DIR          Directory to watch (required)"
      echo "  --events EVENTS    Comma-separated events: create,modify,delete,moved_to,moved_from"
      echo "  --action ACTION    Action: log, script, organize, compress, copy, notify"
      echo "  --logfile FILE     Log events to file (default: stdout)"
      echo "  --script CMD       Command to run (for script action)"
      echo "  --dest DIR         Destination directory (for copy action)"
      echo "  --config FILE      YAML config file for organize rules"
      echo "  --recursive        Watch subdirectories"
      echo "  --exclude PATTERN  Regex pattern to exclude"
      echo "  --debounce SECS    Wait N seconds before triggering (batches rapid changes)"
      echo "  --min-size SIZE    Minimum file size to act on (e.g., 10M)"
      echo "  --notify TYPE      Send notification: telegram, webhook"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Validate ────────────────────────────────────────────────────────────────
if [[ -z "$WATCH_DIR" && -z "$CONFIG" ]]; then
  echo "❌ Error: --dir or --config required"
  echo "Run: watch.sh --help"
  exit 1
fi

# Expand tilde
WATCH_DIR="${WATCH_DIR/#\~/$HOME}"
[[ -n "$DEST_DIR" ]] && DEST_DIR="${DEST_DIR/#\~/$HOME}"
[[ -n "$LOGFILE" ]] && LOGFILE="${LOGFILE/#\~/$HOME}"

if [[ -n "$WATCH_DIR" && ! -d "$WATCH_DIR" ]]; then
  echo "❌ Error: Directory does not exist: $WATCH_DIR"
  exit 1
fi

# Check for inotifywait
if ! command -v inotifywait &>/dev/null; then
  if command -v fswatch &>/dev/null; then
    echo "ℹ️  Using fswatch (macOS mode)"
    USE_FSWATCH=1
  else
    echo "❌ inotifywait not found. Run: bash scripts/install.sh"
    exit 1
  fi
else
  USE_FSWATCH=0
fi

# ─── Helper Functions ────────────────────────────────────────────────────────

log_event() {
  local timestamp event filepath
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  event="$1"
  filepath="$2"
  local msg="[$timestamp] $event $filepath"

  if [[ -n "$LOGFILE" ]]; then
    echo "$msg" >> "$LOGFILE"
  fi
  echo "$msg"
}

send_telegram() {
  local msg="$1"
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=${msg}" \
      -d "parse_mode=HTML" > /dev/null 2>&1 &
  else
    echo "⚠️  Telegram not configured (set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)"
  fi
}

get_file_ext() {
  local filename="$1"
  echo "${filename##*.}" | tr '[:upper:]' '[:lower:]'
}

check_min_size() {
  local filepath="$1"
  if [[ -z "$MIN_SIZE" ]]; then return 0; fi
  if [[ ! -f "$filepath" ]]; then return 1; fi

  local size_bytes
  size_bytes=$(stat -c%s "$filepath" 2>/dev/null || stat -f%z "$filepath" 2>/dev/null || echo 0)

  local min_bytes=0
  if [[ "$MIN_SIZE" =~ ^([0-9]+)[Kk]$ ]]; then
    min_bytes=$(( ${BASH_REMATCH[1]} * 1024 ))
  elif [[ "$MIN_SIZE" =~ ^([0-9]+)[Mm]$ ]]; then
    min_bytes=$(( ${BASH_REMATCH[1]} * 1024 * 1024 ))
  elif [[ "$MIN_SIZE" =~ ^([0-9]+)[Gg]$ ]]; then
    min_bytes=$(( ${BASH_REMATCH[1]} * 1024 * 1024 * 1024 ))
  elif [[ "$MIN_SIZE" =~ ^([0-9]+)$ ]]; then
    min_bytes=${BASH_REMATCH[1]}
  fi

  [[ $size_bytes -ge $min_bytes ]]
}

# ─── Action Handlers ─────────────────────────────────────────────────────────

do_action() {
  local event="$1"
  local filepath="$2"
  local filename
  filename="$(basename "$filepath")"

  # Skip temporary/partial files
  if [[ "$filename" == *.part || "$filename" == *.tmp || "$filename" == *.crdownload || "$filename" == .* ]]; then
    return
  fi

  # Check minimum size
  if [[ "$ACTION" == "compress" || "$ACTION" == "copy" ]]; then
    if ! check_min_size "$filepath"; then
      return
    fi
  fi

  case "$ACTION" in
    log)
      log_event "$event" "$filepath"
      ;;

    script)
      log_event "$event" "$filepath"
      if [[ -n "$SCRIPT_CMD" ]]; then
        export WATCH_EVENT="$event"
        export WATCH_FILE="$filepath"
        export WATCH_FILENAME="$filename"
        export WATCH_DIR_PATH="$WATCH_DIR"
        eval "$SCRIPT_CMD" &
      fi
      ;;

    organize)
      log_event "$event" "$filepath"
      if [[ ! -f "$filepath" ]]; then return; fi
      local ext
      ext="$(get_file_ext "$filename")"
      local dest=""

      case "$ext" in
        pdf) dest="$HOME/Documents/PDFs" ;;
        doc|docx|odt|rtf) dest="$HOME/Documents" ;;
        jpg|jpeg|png|gif|webp|svg|bmp) dest="$HOME/Pictures" ;;
        mp4|mkv|avi|mov|wmv|flv) dest="$HOME/Videos" ;;
        mp3|flac|wav|ogg|aac|m4a) dest="$HOME/Music" ;;
        zip|tar|gz|bz2|7z|rar|xz) dest="$HOME/Archives" ;;
        sh|py|js|ts|rb|go|rs|c|cpp|h) dest="$HOME/Code" ;;
        csv|json|xml|yaml|yml) dest="$HOME/Data" ;;
      esac

      if [[ -n "$dest" ]]; then
        mkdir -p "$dest"
        mv "$filepath" "$dest/" 2>/dev/null && \
          log_event "MOVED" "$filepath → $dest/$filename"
      fi
      ;;

    compress)
      log_event "$event" "$filepath"
      if [[ -f "$filepath" && ! "$filepath" =~ \.gz$ ]]; then
        gzip -k "$filepath" 2>/dev/null && \
          log_event "COMPRESSED" "${filepath}.gz"
      fi
      ;;

    copy)
      log_event "$event" "$filepath"
      if [[ -f "$filepath" && -n "$DEST_DIR" ]]; then
        mkdir -p "$DEST_DIR"
        cp "$filepath" "$DEST_DIR/" 2>/dev/null && \
          log_event "COPIED" "$filepath → $DEST_DIR/$filename"
      fi
      ;;

    notify)
      log_event "$event" "$filepath"
      local msg="📁 <b>File Event:</b> $event\n📄 <b>File:</b> $filename\n📂 <b>Path:</b> $filepath\n🕐 $(date '+%Y-%m-%d %H:%M:%S')"
      case "$NOTIFY" in
        telegram) send_telegram "$msg" ;;
        *) echo "$msg" ;;
      esac
      ;;
  esac
}

# ─── Debounce Logic ──────────────────────────────────────────────────────────

LAST_EVENT_TIME=0
PENDING_FILE=""
PENDING_EVENT=""

handle_event() {
  local event="$1"
  local filepath="$2"

  if [[ $DEBOUNCE -gt 0 ]]; then
    local now
    now=$(date +%s)
    PENDING_EVENT="$event"
    PENDING_FILE="$filepath"
    LAST_EVENT_TIME=$now
    # Fire after debounce period (simplified — works for single-file debounce)
    (
      sleep "$DEBOUNCE"
      local check_time
      check_time=$(date +%s)
      if [[ $((check_time - LAST_EVENT_TIME)) -ge $DEBOUNCE ]]; then
        do_action "$PENDING_EVENT" "$PENDING_FILE"
      fi
    ) &
  else
    do_action "$event" "$filepath"
  fi
}

# ─── Main Watch Loop ─────────────────────────────────────────────────────────

echo "👁️  Watching: $WATCH_DIR"
echo "📋 Events: $EVENTS"
echo "⚡ Action: $ACTION"
[[ -n "$LOGFILE" ]] && echo "📝 Logging to: $LOGFILE"
[[ $DEBOUNCE -gt 0 ]] && echo "⏱️  Debounce: ${DEBOUNCE}s"
echo "---"

# Build inotifywait args
INOTIFY_ARGS=(-m -e "$EVENTS" --format '%e %w%f')
[[ -n "$RECURSIVE" ]] && INOTIFY_ARGS+=($RECURSIVE)
[[ -n "$EXCLUDE" ]] && INOTIFY_ARGS+=(--exclude "$EXCLUDE")

if [[ $USE_FSWATCH -eq 0 ]]; then
  inotifywait "${INOTIFY_ARGS[@]}" "$WATCH_DIR" | while read -r event filepath; do
    handle_event "$event" "$filepath"
  done
else
  # macOS fswatch fallback
  FSWATCH_ARGS=()
  [[ -n "$RECURSIVE" ]] || FSWATCH_ARGS+=(--no-defer -1)
  fswatch "${FSWATCH_ARGS[@]}" "$WATCH_DIR" | while read -r filepath; do
    handle_event "CHANGED" "$filepath"
  done
fi
