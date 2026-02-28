#!/bin/bash
# SSHFS Remote Mount Manager v1.0
# Mount remote filesystems over SSH with profiles, auto-reconnect, and health checks
set -euo pipefail

CONFIG_DIR="$HOME/.config/sshfs-manager"
PROFILES_FILE="$CONFIG_DIR/profiles.yaml"
STATE_FILE="$CONFIG_DIR/state.json"
LOG_FILE="$CONFIG_DIR/sshfs-manager.log"
DEFAULT_MOUNT_BASE="$HOME/remote"

# Ensure directories exist
mkdir -p "$CONFIG_DIR" "$DEFAULT_MOUNT_BASE"

# --- Logging ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# --- Parse YAML profiles (lightweight, no yq dependency) ---
# Stores profiles as individual config files for simplicity
PROFILE_DIR="$CONFIG_DIR/profiles.d"
mkdir -p "$PROFILE_DIR"

get_profile() {
  local name="$1"
  local file="$PROFILE_DIR/$name.conf"
  if [ ! -f "$file" ]; then
    echo "❌ Profile '$name' not found. Use 'save-profile' first." >&2
    return 1
  fi
  source "$file"
}

# --- Commands ---

cmd_mount() {
  local host="" remote="" local_path="" port=22 identity="" options="reconnect,ServerAliveInterval=15,ServerAliveCountMax=3" profile=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --host) host="$2"; shift 2 ;;
      --remote) remote="$2"; shift 2 ;;
      --local) local_path="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --identity) identity="$2"; shift 2 ;;
      --options) options="$options,$2"; shift 2 ;;
      --profile) profile="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  # Load profile if specified
  if [ -n "$profile" ]; then
    get_profile "$profile"
    host="${PROFILE_HOST:-$host}"
    remote="${PROFILE_REMOTE:-$remote}"
    local_path="${PROFILE_LOCAL:-$local_path}"
    port="${PROFILE_PORT:-$port}"
    identity="${PROFILE_IDENTITY:-$identity}"
    options="${PROFILE_OPTIONS:-$options}"
  fi

  # Validate
  if [ -z "$host" ] || [ -z "$remote" ] || [ -z "$local_path" ]; then
    echo "❌ Required: --host, --remote, --local (or --profile)"
    echo "Usage: sshfs-manager.sh mount --host user@server --remote /path --local ~/remote/name"
    exit 1
  fi

  # Expand tilde
  local_path="${local_path/#\~/$HOME}"

  # Check if already mounted
  if mountpoint -q "$local_path" 2>/dev/null; then
    echo "⚠️  $local_path is already mounted"
    return 0
  fi

  # Create mount point
  mkdir -p "$local_path"

  # Build sshfs command
  local cmd="sshfs"
  cmd="$cmd -p $port"
  cmd="$cmd -o $options"
  [ -n "$identity" ] && cmd="$cmd -o IdentityFile=${identity/#\~/$HOME}"
  cmd="$cmd $host:$remote $local_path"

  echo "🔗 Mounting $host:$remote → $local_path"
  log "MOUNT: $host:$remote → $local_path"

  eval $cmd

  if mountpoint -q "$local_path" 2>/dev/null; then
    echo "✅ Mounted successfully"
    log "MOUNT OK: $local_path"

    # Save state
    _save_state "$local_path" "$host" "$remote" "$port" "$identity" "$options" "$profile"
  else
    echo "❌ Mount failed"
    log "MOUNT FAIL: $local_path"
    exit 1
  fi
}

cmd_unmount() {
  local local_path="" profile=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --local) local_path="$2"; shift 2 ;;
      --profile) profile="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  if [ -n "$profile" ]; then
    get_profile "$profile"
    local_path="${PROFILE_LOCAL:-$local_path}"
  fi

  if [ -z "$local_path" ]; then
    echo "❌ Required: --local or --profile"
    exit 1
  fi

  local_path="${local_path/#\~/$HOME}"

  echo "🔌 Unmounting $local_path"
  log "UNMOUNT: $local_path"

  if fusermount -uz "$local_path" 2>/dev/null || umount "$local_path" 2>/dev/null; then
    echo "✅ Unmounted"
    log "UNMOUNT OK: $local_path"
    _remove_state "$local_path"
  else
    echo "❌ Unmount failed. Try: fusermount -uz $local_path"
    log "UNMOUNT FAIL: $local_path"
  fi
}

cmd_list() {
  echo "📂 Active SSHFS Mounts:"
  echo ""

  local found=0
  while IFS= read -r line; do
    if echo "$line" | grep -q "fuse.sshfs\|sshfs#"; then
      found=1
      local device=$(echo "$line" | awk '{print $1}')
      local mountpoint=$(echo "$line" | awk '{print $2}')
      echo "  🔗 $device → $mountpoint"
    fi
  done < <(mount 2>/dev/null)

  if [ $found -eq 0 ]; then
    echo "  (no active SSHFS mounts)"
  fi
  echo ""
}

cmd_status() {
  echo "📊 SSHFS Mount Status:"
  echo ""

  local found=0
  while IFS= read -r line; do
    if echo "$line" | grep -q "fuse.sshfs\|sshfs#"; then
      found=1
      local mountpoint=$(echo "$line" | awk '{print $2}')
      local device=$(echo "$line" | awk '{print $1}')

      # Test if mount is responsive
      local start_ms=$(($(date +%s%N)/1000000))
      if timeout 5 ls "$mountpoint" &>/dev/null; then
        local end_ms=$(($(date +%s%N)/1000000))
        local latency=$((end_ms - start_ms))
        echo "  ✅ $device → $mountpoint (healthy, ${latency}ms)"
      else
        echo "  ❌ $device → $mountpoint (unresponsive)"
      fi
    fi
  done < <(mount 2>/dev/null)

  if [ $found -eq 0 ]; then
    echo "  (no active SSHFS mounts)"
  fi
  echo ""
}

cmd_save_profile() {
  local name="" host="" remote="" local_path="" port=22 identity="" options="reconnect,ServerAliveInterval=15,ServerAliveCountMax=3"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --host) host="$2"; shift 2 ;;
      --remote) remote="$2"; shift 2 ;;
      --local) local_path="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --identity) identity="$2"; shift 2 ;;
      --options) options="$options,$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  if [ -z "$name" ] || [ -z "$host" ] || [ -z "$remote" ] || [ -z "$local_path" ]; then
    echo "❌ Required: --name, --host, --remote, --local"
    exit 1
  fi

  cat > "$PROFILE_DIR/$name.conf" << EOF
PROFILE_HOST="$host"
PROFILE_REMOTE="$remote"
PROFILE_LOCAL="$local_path"
PROFILE_PORT="$port"
PROFILE_IDENTITY="$identity"
PROFILE_OPTIONS="$options"
PROFILE_AUTO_MOUNT="false"
EOF

  echo "✅ Profile '$name' saved"
  log "PROFILE SAVED: $name"
}

cmd_list_profiles() {
  echo "📋 Saved Profiles:"
  echo ""

  local found=0
  for f in "$PROFILE_DIR"/*.conf; do
    [ -f "$f" ] || continue
    found=1
    local name=$(basename "$f" .conf)
    source "$f"
    local auto=""
    [ "${PROFILE_AUTO_MOUNT:-false}" = "true" ] && auto=" [auto-mount]"
    echo "  📁 $name: ${PROFILE_HOST}:${PROFILE_REMOTE} → ${PROFILE_LOCAL}$auto"
  done

  if [ $found -eq 0 ]; then
    echo "  (no saved profiles)"
  fi
  echo ""
}

cmd_mount_all() {
  echo "🔗 Mounting all saved profiles..."
  for f in "$PROFILE_DIR"/*.conf; do
    [ -f "$f" ] || continue
    local name=$(basename "$f" .conf)
    echo ""
    cmd_mount --profile "$name" || true
  done
}

cmd_unmount_all() {
  echo "🔌 Unmounting all SSHFS mounts..."
  while IFS= read -r line; do
    if echo "$line" | grep -q "fuse.sshfs\|sshfs#"; then
      local mountpoint=$(echo "$line" | awk '{print $2}')
      echo "  Unmounting $mountpoint..."
      fusermount -uz "$mountpoint" 2>/dev/null || umount "$mountpoint" 2>/dev/null || true
    fi
  done < <(mount 2>/dev/null)
  echo "✅ All SSHFS mounts unmounted"
}

cmd_health() {
  local auto_reconnect=false
  [ "${1:-}" = "--auto-reconnect" ] && auto_reconnect=true

  echo "🏥 Health Check:"
  echo ""

  # Check state file for expected mounts
  if [ -f "$STATE_FILE" ]; then
    while IFS='|' read -r local_path host remote port identity options profile; do
      [ -z "$local_path" ] && continue
      local_path="${local_path/#\~/$HOME}"

      if mountpoint -q "$local_path" 2>/dev/null; then
        local start_ms=$(($(date +%s%N)/1000000))
        if timeout 5 ls "$local_path" &>/dev/null; then
          local end_ms=$(($(date +%s%N)/1000000))
          local latency=$((end_ms - start_ms))
          local label="${profile:-$host}"
          echo "  ✅ $label: $host:$remote → $local_path (healthy, ${latency}ms)"
        else
          echo "  ⚠️  ${profile:-$host}: $local_path (stale — transport broken)"
          if $auto_reconnect; then
            echo "     Reconnecting..."
            fusermount -uz "$local_path" 2>/dev/null || true
            sleep 1
            cmd_mount --host "$host" --remote "$remote" --local "$local_path" --port "$port" ${identity:+--identity "$identity"} 2>/dev/null && \
              echo "  ✅ Reconnected" || echo "  ❌ Reconnection failed"
          fi
        fi
      else
        echo "  ❌ ${profile:-$host}: $local_path (not mounted)"
        if $auto_reconnect; then
          echo "     Remounting..."
          cmd_mount --host "$host" --remote "$remote" --local "$local_path" --port "$port" ${identity:+--identity "$identity"} 2>/dev/null && \
            echo "  ✅ Remounted" || echo "  ❌ Remount failed"
        fi
      fi
    done < "$STATE_FILE"
  else
    # Fall back to checking active mounts
    cmd_status
  fi
}

cmd_auto_mount() {
  local profile="" enable=false disable=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --profile) profile="$2"; shift 2 ;;
      --enable) enable=true; shift ;;
      --disable) disable=true; shift ;;
      *) shift ;;
    esac
  done

  if [ -z "$profile" ]; then
    echo "❌ Required: --profile"
    exit 1
  fi

  local conf="$PROFILE_DIR/$profile.conf"
  if [ ! -f "$conf" ]; then
    echo "❌ Profile '$profile' not found"
    exit 1
  fi

  if $enable; then
    sed -i 's/PROFILE_AUTO_MOUNT=.*/PROFILE_AUTO_MOUNT="true"/' "$conf"
    echo "✅ Auto-mount enabled for '$profile'"

    # Create systemd user service
    local service_dir="$HOME/.config/systemd/user"
    mkdir -p "$service_dir"

    source "$conf"
    local local_expanded="${PROFILE_LOCAL/#\~/$HOME}"

    cat > "$service_dir/sshfs-$profile.service" << EOF
[Unit]
Description=SSHFS mount: $profile
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStart=$(realpath "$0") mount --profile $profile
ExecStop=$(realpath "$0") unmount --profile $profile
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable "sshfs-$profile.service" 2>/dev/null || true
    echo "   Systemd user service created: sshfs-$profile.service"

  elif $disable; then
    sed -i 's/PROFILE_AUTO_MOUNT=.*/PROFILE_AUTO_MOUNT="false"/' "$conf"
    systemctl --user disable "sshfs-$profile.service" 2>/dev/null || true
    echo "✅ Auto-mount disabled for '$profile'"
  fi
}

# --- State management ---
_save_state() {
  local local_path="$1" host="$2" remote="$3" port="$4" identity="$5" options="$6" profile="${7:-}"
  # Remove existing entry for this mount point
  [ -f "$STATE_FILE" ] && grep -v "^$local_path|" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE" || true
  echo "$local_path|$host|$remote|$port|$identity|$options|$profile" >> "$STATE_FILE"
}

_remove_state() {
  local local_path="$1"
  [ -f "$STATE_FILE" ] && grep -v "^$local_path|" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE" || true
}

# --- Help ---
cmd_help() {
  cat << 'EOF'
SSHFS Remote Mount Manager v1.0

Usage: sshfs-manager.sh <command> [options]

Commands:
  mount           Mount a remote directory
  unmount         Unmount a mount point
  list            List active SSHFS mounts
  status          Show mount status with health info
  health          Health check all tracked mounts
  save-profile    Save a mount profile
  list-profiles   List saved profiles
  mount-all       Mount all saved profiles
  unmount-all     Unmount all SSHFS mounts
  auto-mount      Enable/disable auto-mount on boot
  help            Show this help

Mount Options:
  --host USER@HOST    SSH host (required)
  --remote PATH       Remote directory (required)
  --local PATH        Local mount point (required)
  --port N            SSH port (default: 22)
  --identity PATH     SSH key file
  --options OPTS      Additional SSHFS options (comma-separated)
  --profile NAME      Use saved profile

Examples:
  sshfs-manager.sh mount --host user@server --remote /var/www --local ~/remote/web
  sshfs-manager.sh mount --profile prod-server
  sshfs-manager.sh health --auto-reconnect
  sshfs-manager.sh save-profile --name prod --host user@prod.com --remote /app --local ~/remote/prod
EOF
}

# --- Main ---
COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  mount) cmd_mount "$@" ;;
  unmount|umount) cmd_unmount "$@" ;;
  list) cmd_list ;;
  status) cmd_status ;;
  health) cmd_health "$@" ;;
  save-profile) cmd_save_profile "$@" ;;
  list-profiles|profiles) cmd_list_profiles ;;
  mount-all) cmd_mount_all ;;
  unmount-all) cmd_unmount_all ;;
  auto-mount) cmd_auto_mount "$@" ;;
  help|--help|-h) cmd_help ;;
  *) echo "Unknown command: $COMMAND. Run with 'help' for usage."; exit 1 ;;
esac
