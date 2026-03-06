#!/bin/bash
# Multi-directory watcher — reads YAML config and spawns watchers
set -euo pipefail

CONFIG=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIDS=()

usage() {
  echo "Usage: $(basename "$0") --config <watcher.yaml>"
  echo "Runs multiple directory watchers from a YAML config file."
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$CONFIG" || ! -f "$CONFIG" ]]; then
  echo "Error: --config <file> required"
  exit 1
fi

# Simple YAML parser for watcher configs
# Reads watcher blocks and spawns watch.sh for each
parse_and_run() {
  local name="" dir="" recursive="" events="" filter="" action="" debounce=""

  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    # Detect new watcher block
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.*) ]]; then
      # Launch previous watcher if exists
      if [[ -n "$name" && -n "$dir" ]]; then
        launch_watcher "$name" "$dir" "$recursive" "$events" "$filter" "$action" "$debounce"
      fi
      name="${BASH_REMATCH[1]}"
      dir="" recursive="" events="" filter="" action="" debounce=""
    elif [[ "$line" =~ ^[[:space:]]*dir:[[:space:]]*(.*) ]]; then
      dir="${BASH_REMATCH[1]}"
      dir=$(eval echo "$dir")  # Expand ~
    elif [[ "$line" =~ ^[[:space:]]*recursive:[[:space:]]*(true|false) ]]; then
      recursive="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*events:[[:space:]]*\[(.*)\] ]]; then
      events="${BASH_REMATCH[1]}"
      events="${events// /}"
    elif [[ "$line" =~ ^[[:space:]]*filter:[[:space:]]*(.*) ]]; then
      filter="${BASH_REMATCH[1]}"
      filter="${filter%\'}"
      filter="${filter#\'}"
      filter="${filter%\"}"
      filter="${filter#\"}"
    elif [[ "$line" =~ ^[[:space:]]*action:[[:space:]]*(.*) ]]; then
      action="${BASH_REMATCH[1]}"
      action="${action%\'}"
      action="${action#\'}"
      action="${action%\"}"
      action="${action#\"}"
    elif [[ "$line" =~ ^[[:space:]]*debounce:[[:space:]]*(.*) ]]; then
      debounce="${BASH_REMATCH[1]}"
    fi
  done < "$CONFIG"

  # Launch last watcher
  if [[ -n "$name" && -n "$dir" ]]; then
    launch_watcher "$name" "$dir" "$recursive" "$events" "$filter" "$action" "$debounce"
  fi
}

launch_watcher() {
  local name="$1" dir="$2" recursive="$3" events="$4" filter="$5" action="$6" debounce="$7"

  local args=(--dir "$dir")
  [[ "$recursive" == "true" ]] && args+=(--recursive)
  [[ -n "$events" ]] && args+=(--events "$events")
  [[ -n "$filter" ]] && args+=(--filter "$filter")
  [[ -n "$action" ]] && args+=(--action "$action")
  [[ -n "$debounce" ]] && args+=(--debounce "$debounce")
  args+=(--pidfile "/tmp/inotify-watcher-${name}.pid")

  echo "🚀 Starting watcher: $name (dir: $dir)"
  bash "$SCRIPT_DIR/watch.sh" "${args[@]}" &
  PIDS+=($!)
}

cleanup() {
  echo ""
  echo "Stopping all watchers..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null
  echo "All watchers stopped."
}
trap cleanup EXIT INT TERM

parse_and_run

echo ""
echo "All watchers running. Press Ctrl+C to stop all."
wait
