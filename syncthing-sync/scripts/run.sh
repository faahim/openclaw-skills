#!/bin/bash
# Syncthing Manager — Control and query Syncthing via REST API
set -e

# --- Config ---
SYNCTHING_URL="${SYNCTHING_URL:-http://127.0.0.1:8384}"

get_api_key() {
  if [[ -n "$SYNCTHING_API_KEY" ]]; then
    echo "$SYNCTHING_API_KEY"
    return
  fi
  # Auto-detect from config
  for cfg in "$HOME/.local/state/syncthing/config.xml" "$HOME/.config/syncthing/config.xml"; do
    if [[ -f "$cfg" ]]; then
      grep -oP '<apikey>\K[^<]+' "$cfg" 2>/dev/null && return
    fi
  done
  echo "ERROR: No API key found. Set SYNCTHING_API_KEY or run syncthing once." >&2
  exit 1
}

API_KEY=""
api() {
  local method="$1" endpoint="$2" data="$3"
  [[ -z "$API_KEY" ]] && API_KEY=$(get_api_key)
  local args=(-s -H "X-API-Key: $API_KEY" -H "Content-Type: application/json")
  if [[ "$method" == "GET" ]]; then
    curl "${args[@]}" "${SYNCTHING_URL}/rest/${endpoint}"
  elif [[ "$method" == "POST" ]]; then
    curl "${args[@]}" -X POST -d "$data" "${SYNCTHING_URL}/rest/${endpoint}"
  elif [[ "$method" == "PUT" ]]; then
    curl "${args[@]}" -X PUT -d "$data" "${SYNCTHING_URL}/rest/${endpoint}"
  elif [[ "$method" == "DELETE" ]]; then
    curl "${args[@]}" -X DELETE "${SYNCTHING_URL}/rest/${endpoint}"
  fi
}

cmd_start() {
  if pgrep -x syncthing &>/dev/null; then
    echo "✅ Syncthing already running (PID $(pgrep -x syncthing | head -1))"
  else
    echo "Starting Syncthing..."
    nohup syncthing serve --no-browser --no-default-folder > /tmp/syncthing.log 2>&1 &
    sleep 2
    if pgrep -x syncthing &>/dev/null; then
      echo "✅ Syncthing started (PID $!)"
      echo "   Web UI: $SYNCTHING_URL"
    else
      echo "❌ Failed to start. Check /tmp/syncthing.log"
      exit 1
    fi
  fi
}

cmd_stop() {
  api POST "system/shutdown" "{}" 2>/dev/null || true
  echo "✅ Syncthing stopped"
}

cmd_restart() {
  api POST "system/restart" "{}" 2>/dev/null || true
  echo "🔄 Syncthing restarting..."
  sleep 3
  echo "✅ Syncthing restarted"
}

cmd_status() {
  if ! pgrep -x syncthing &>/dev/null; then
    echo "❌ Syncthing is not running"
    echo "   Start with: bash scripts/run.sh start"
    return 1
  fi
  
  local sys=$(api GET "system/status" 2>/dev/null)
  local cfg=$(api GET "config" 2>/dev/null)
  local conns=$(api GET "system/connections" 2>/dev/null)
  
  local my_id=$(echo "$sys" | jq -r '.myID // "unknown"' 2>/dev/null)
  local uptime=$(echo "$sys" | jq -r '.uptime // 0' 2>/dev/null)
  local folders=$(echo "$cfg" | jq '.folders | length' 2>/dev/null)
  local devices=$(echo "$cfg" | jq '.devices | length' 2>/dev/null)
  local connected=$(echo "$conns" | jq '[.connections | to_entries[] | select(.value.connected)] | length' 2>/dev/null)
  
  local hrs=$((uptime / 3600))
  local mins=$(((uptime % 3600) / 60))
  
  echo "✅ Syncthing running (PID $(pgrep -x syncthing | head -1))"
  echo "🆔 Device ID: ${my_id:0:7}-..."
  echo "⏱️  Uptime: ${hrs}h ${mins}m"
  echo "📂 Shared folders: ${folders:-0}"
  echo "🖥️  Connected devices: ${connected:-0}/${devices:-0}"
}

cmd_device_id() {
  local sys=$(api GET "system/status" 2>/dev/null)
  echo "$sys" | jq -r '.myID'
}

cmd_add_folder() {
  local path="" label="" id="" type="sendreceive"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --path) path="$2"; shift 2 ;;
      --label) label="$2"; shift 2 ;;
      --id) id="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  [[ -z "$path" ]] && { echo "❌ --path required"; exit 1; }
  [[ -z "$id" ]] && id=$(basename "$path" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  [[ -z "$label" ]] && label=$(basename "$path")
  
  # Expand path
  path=$(realpath "$path" 2>/dev/null || echo "$path")
  
  local payload=$(jq -n \
    --arg id "$id" \
    --arg label "$label" \
    --arg path "$path" \
    --arg type "$type" \
    '{id: $id, label: $label, path: $path, type: $type, rescanIntervalS: 3600, fsWatcherEnabled: true, fsWatcherDelayS: 10}')
  
  api POST "config/folders" "$payload" > /dev/null 2>&1
  echo "✅ Folder added: $label ($path)"
  echo "   ID: $id | Type: $type"
}

cmd_add_device() {
  local device_id="" name="" address=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --device-id) device_id="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --address) address="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  [[ -z "$device_id" ]] && { echo "❌ --device-id required"; exit 1; }
  [[ -z "$name" ]] && name="Device-$(echo "$device_id" | cut -c1-7)"
  
  local addresses='["dynamic"]'
  [[ -n "$address" ]] && addresses=$(jq -n --arg a "$address" '[$a, "dynamic"]')
  
  local payload=$(jq -n \
    --arg id "$device_id" \
    --arg name "$name" \
    --argjson addrs "$addresses" \
    '{deviceID: $id, name: $name, addresses: $addrs, autoAcceptFolders: false}')
  
  api POST "config/devices" "$payload" > /dev/null 2>&1
  echo "✅ Device added: $name"
  echo "   ID: ${device_id:0:7}-..."
}

cmd_share_folder() {
  local folder_id="" device_id=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --folder-id) folder_id="$2"; shift 2 ;;
      --device-id) device_id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  [[ -z "$folder_id" || -z "$device_id" ]] && { echo "❌ --folder-id and --device-id required"; exit 1; }
  
  # Get current folder config
  local folder=$(api GET "config/folders/$folder_id" 2>/dev/null)
  
  # Add device to folder
  local updated=$(echo "$folder" | jq --arg did "$device_id" \
    '.devices += [{"deviceID": $did}] | .devices |= unique_by(.deviceID)')
  
  api PUT "config/folders/$folder_id" "$updated" > /dev/null 2>&1
  echo "✅ Folder '$folder_id' shared with device ${device_id:0:7}-..."
}

cmd_sync_status() {
  local verbose=false
  [[ "$1" == "--verbose" ]] && verbose=true
  
  local cfg=$(api GET "config" 2>/dev/null)
  local folders=$(echo "$cfg" | jq -r '.folders[] | .id + "|" + .label + "|" + .path')
  
  while IFS='|' read -r id label path; do
    local completion=$(api GET "db/completion?folder=$id" 2>/dev/null)
    local pct=$(echo "$completion" | jq '.completion // 0' 2>/dev/null)
    local need_bytes=$(echo "$completion" | jq '.needBytes // 0' 2>/dev/null)
    
    local icon="✅"
    local state="Up to Date"
    if (( $(echo "$pct < 100" | bc -l 2>/dev/null || echo 0) )); then
      icon="🔄"
      state="Syncing (${pct}%)"
    fi
    
    local db_status=$(api GET "db/status?folder=$id" 2>/dev/null)
    local files=$(echo "$db_status" | jq '.localFiles // 0' 2>/dev/null)
    local bytes=$(echo "$db_status" | jq '.localBytes // 0' 2>/dev/null)
    local size_mb=$((bytes / 1048576))
    
    echo "📂 $label: $icon $state ($files files, ${size_mb} MB)"
    
    if $verbose; then
      echo "   Path: $path"
      echo "   ID: $id"
      local folder_state=$(echo "$db_status" | jq -r '.state // "unknown"')
      echo "   State: $folder_state"
    fi
  done <<< "$folders"
}

cmd_conflicts() {
  local cfg=$(api GET "config" 2>/dev/null)
  local folders=$(echo "$cfg" | jq -r '.folders[] | .path')
  local total=0
  
  while read -r path; do
    [[ -z "$path" ]] && continue
    local conflicts=$(find "$path" -name "*.sync-conflict-*" 2>/dev/null)
    if [[ -n "$conflicts" ]]; then
      while read -r f; do
        echo "⚠️  $f"
        total=$((total + 1))
      done <<< "$conflicts"
    fi
  done <<< "$folders"
  
  if [[ $total -eq 0 ]]; then
    echo "✅ No sync conflicts found"
  else
    echo ""
    echo "⚠️  $total sync conflict(s) found"
  fi
}

cmd_resolve_conflicts() {
  local strategy="newest"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --strategy) strategy="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local cfg=$(api GET "config" 2>/dev/null)
  local folders=$(echo "$cfg" | jq -r '.folders[] | .path')
  local resolved=0
  
  while read -r path; do
    [[ -z "$path" ]] && continue
    find "$path" -name "*.sync-conflict-*" 2>/dev/null | while read -r conflict; do
      # Extract original filename
      local original=$(echo "$conflict" | sed 's/\.sync-conflict-[0-9]*-[0-9]*-[A-Z0-9]*//; s/\(.*\)\.\(.*\)/\1.\2/')
      
      if [[ "$strategy" == "newest" ]]; then
        if [[ "$conflict" -nt "$original" ]] 2>/dev/null; then
          mv "$conflict" "$original"
          echo "✅ Kept conflict (newer): $original"
        else
          rm "$conflict"
          echo "✅ Kept original (newer): $original"
        fi
      else
        rm "$conflict"
        echo "✅ Kept original: $original"
      fi
      resolved=$((resolved + 1))
    done
  done <<< "$folders"
  
  echo "Resolved $resolved conflict(s) using strategy: $strategy"
}

cmd_set_ignores() {
  local folder_id="" patterns=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --folder-id) folder_id="$2"; shift 2 ;;
      --patterns) shift; while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do patterns+=("$1"); shift; done ;;
      *) shift ;;
    esac
  done
  
  [[ -z "$folder_id" ]] && { echo "❌ --folder-id required"; exit 1; }
  
  local ignore_lines=""
  for p in "${patterns[@]}"; do
    ignore_lines+="$p\n"
  done
  
  local payload=$(jq -n --arg lines "$(echo -e "$ignore_lines")" '{ignore: ($lines | split("\n") | map(select(. != "")))}')
  api POST "db/ignores?folder=$folder_id" "$payload" > /dev/null 2>&1
  echo "✅ Ignore patterns set for folder $folder_id: ${patterns[*]}"
}

cmd_pause() {
  local folder_id=""
  while [[ $# -gt 0 ]]; do
    case $1 in --folder-id) folder_id="$2"; shift 2 ;; *) shift ;; esac
  done
  [[ -z "$folder_id" ]] && { echo "❌ --folder-id required"; exit 1; }
  
  local folder=$(api GET "config/folders/$folder_id" 2>/dev/null)
  local updated=$(echo "$folder" | jq '.paused = true')
  api PUT "config/folders/$folder_id" "$updated" > /dev/null 2>&1
  echo "⏸️  Folder $folder_id paused"
}

cmd_resume() {
  local folder_id=""
  while [[ $# -gt 0 ]]; do
    case $1 in --folder-id) folder_id="$2"; shift 2 ;; *) shift ;; esac
  done
  [[ -z "$folder_id" ]] && { echo "❌ --folder-id required"; exit 1; }
  
  local folder=$(api GET "config/folders/$folder_id" 2>/dev/null)
  local updated=$(echo "$folder" | jq '.paused = false')
  api PUT "config/folders/$folder_id" "$updated" > /dev/null 2>&1
  echo "▶️  Folder $folder_id resumed"
}

cmd_set_folder_type() {
  local folder_id="" type=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --folder-id) folder_id="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$folder_id" || -z "$type" ]] && { echo "❌ --folder-id and --type required"; exit 1; }
  
  local folder=$(api GET "config/folders/$folder_id" 2>/dev/null)
  local updated=$(echo "$folder" | jq --arg t "$type" '.type = $t')
  api PUT "config/folders/$folder_id" "$updated" > /dev/null 2>&1
  echo "✅ Folder $folder_id type set to: $type"
}

cmd_config() {
  api GET "config" 2>/dev/null | jq .
}

cmd_enable_service() {
  if [[ "$(uname)" == "Darwin" ]]; then
    brew services start syncthing 2>/dev/null || {
      echo "Run: brew services start syncthing"
    }
  else
    systemctl --user enable syncthing.service
    systemctl --user start syncthing.service
    echo "✅ Syncthing systemd service enabled and started"
    echo "   Auto-starts on login"
  fi
}

# --- Main ---
CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
  start)            cmd_start ;;
  stop)             cmd_stop ;;
  restart)          cmd_restart ;;
  status)           cmd_status ;;
  device-id)        cmd_device_id ;;
  add-folder)       cmd_add_folder "$@" ;;
  add-device)       cmd_add_device "$@" ;;
  share-folder)     cmd_share_folder "$@" ;;
  sync-status)      cmd_sync_status "$@" ;;
  conflicts)        cmd_conflicts ;;
  resolve-conflicts) cmd_resolve_conflicts "$@" ;;
  set-ignores)      cmd_set_ignores "$@" ;;
  pause)            cmd_pause "$@" ;;
  resume)           cmd_resume "$@" ;;
  set-folder-type)  cmd_set_folder_type "$@" ;;
  config)           cmd_config ;;
  enable-service)   cmd_enable_service ;;
  help|*)
    echo "Syncthing Manager"
    echo ""
    echo "Usage: bash scripts/run.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start              Start Syncthing daemon"
    echo "  stop               Stop Syncthing"
    echo "  restart            Restart Syncthing"
    echo "  status             Show running status"
    echo "  device-id          Print this device's ID"
    echo "  add-folder         Add a shared folder"
    echo "  add-device         Add a remote device"
    echo "  share-folder       Share a folder with a device"
    echo "  sync-status        Show per-folder sync progress"
    echo "  conflicts          Find sync conflict files"
    echo "  resolve-conflicts  Auto-resolve conflict files"
    echo "  set-ignores        Set ignore patterns for a folder"
    echo "  pause              Pause folder syncing"
    echo "  resume             Resume folder syncing"
    echo "  set-folder-type    Set folder type (sendreceive/sendonly/receiveonly)"
    echo "  config             Dump full config as JSON"
    echo "  enable-service     Enable systemd/launchd auto-start"
    ;;
esac
