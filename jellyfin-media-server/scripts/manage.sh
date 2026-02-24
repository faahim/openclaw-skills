#!/bin/bash
# Jellyfin Media Server Manager
# Manage libraries, users, health, backups, updates

set -euo pipefail

JELLYFIN_URL="${JELLYFIN_URL:-http://localhost:8096}"
JELLYFIN_API_KEY="${JELLYFIN_API_KEY:-}"
CONTAINER_NAME="${JELLYFIN_CONTAINER:-jellyfin}"
CONFIG_DIR="${JELLYFIN_CONFIG_DIR:-$HOME/.jellyfin/config}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helpers
api_get() {
  local endpoint="$1"
  curl -sf -H "X-Emby-Token: ${JELLYFIN_API_KEY}" "${JELLYFIN_URL}${endpoint}"
}

api_post() {
  local endpoint="$1"
  local data="${2:-}"
  curl -sf -X POST -H "X-Emby-Token: ${JELLYFIN_API_KEY}" -H "Content-Type: application/json" -d "$data" "${JELLYFIN_URL}${endpoint}"
}

api_delete() {
  local endpoint="$1"
  curl -sf -X DELETE -H "X-Emby-Token: ${JELLYFIN_API_KEY}" "${JELLYFIN_URL}${endpoint}"
}

require_api_key() {
  if [ -z "$JELLYFIN_API_KEY" ]; then
    echo -e "${RED}❌ JELLYFIN_API_KEY not set.${NC}"
    echo "   Get it from: Jellyfin Dashboard > API Keys"
    echo "   Set: export JELLYFIN_API_KEY=\"your-key\""
    exit 1
  fi
}

# Commands
cmd_status() {
  echo -e "${BLUE}🖥️ Jellyfin Server Status${NC}"
  echo "========================="

  # Check container
  if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    local uptime
    uptime=$(docker ps --format '{{.Status}}' --filter "name=^${CONTAINER_NAME}$")
    echo -e "   Container: ${GREEN}✅ Running${NC} ($uptime)"
  else
    echo -e "   Container: ${RED}❌ Not running${NC}"
    echo "   Start with: docker start $CONTAINER_NAME"
    return 1
  fi

  echo "   URL: $JELLYFIN_URL"

  # Check health
  if curl -sf "${JELLYFIN_URL}/health" &>/dev/null; then
    echo -e "   Health: ${GREEN}✅ Healthy${NC}"
  else
    echo -e "   Health: ${RED}❌ Unreachable${NC}"
    return 1
  fi

  # Get server info (needs API key)
  if [ -n "$JELLYFIN_API_KEY" ]; then
    local info
    info=$(api_get "/System/Info" 2>/dev/null || echo "{}")
    local version
    version=$(echo "$info" | jq -r '.Version // "unknown"')
    local os
    os=$(echo "$info" | jq -r '.OperatingSystem // "unknown"')
    echo "   Version: $version"
    echo "   OS: $os"

    # Active sessions
    local sessions
    sessions=$(api_get "/Sessions" 2>/dev/null || echo "[]")
    local active
    active=$(echo "$sessions" | jq '[.[] | select(.NowPlayingItem != null)] | length')
    local transcoding
    transcoding=$(echo "$sessions" | jq '[.[] | select(.TranscodingInfo != null)] | length')
    echo "   Active streams: $active ($transcoding transcoding)"

    # Libraries
    local libraries
    libraries=$(api_get "/Library/VirtualFolders" 2>/dev/null || echo "[]")
    local lib_count
    lib_count=$(echo "$libraries" | jq 'length')
    echo "   Libraries: $lib_count configured"
  fi

  # Resource usage
  local stats
  stats=$(docker stats --no-stream --format '{{.CPUPerc}}\t{{.MemUsage}}' "$CONTAINER_NAME" 2>/dev/null || echo "N/A\tN/A")
  local cpu mem
  cpu=$(echo "$stats" | cut -f1)
  mem=$(echo "$stats" | cut -f2)
  echo "   CPU: $cpu | RAM: $mem"
}

cmd_list_libraries() {
  require_api_key
  echo -e "${BLUE}📚 Media Libraries${NC}"
  echo "==================="

  local libraries
  libraries=$(api_get "/Library/VirtualFolders" 2>/dev/null)

  if [ -z "$libraries" ] || [ "$libraries" = "[]" ]; then
    echo "   No libraries configured."
    echo "   Add one: bash manage.sh add-library --name Movies --type movies --path /media/movies"
    return
  fi

  echo "$libraries" | jq -r '.[] | "   \(.Name) — \(.CollectionType // "mixed") — \(.Locations | join(", "))"'
}

cmd_add_library() {
  require_api_key
  local name="" type="" path=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --path) path="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$name" ] || [ -z "$type" ] || [ -z "$path" ]; then
    echo "Usage: manage.sh add-library --name NAME --type TYPE --path PATH"
    echo "Types: movies, tvshows, music, musicvideos, homevideos, photos, books"
    exit 1
  fi

  api_post "/Library/VirtualFolders?collectionType=${type}&refreshLibrary=true&name=${name}" \
    "{\"LibraryOptions\":{},\"Paths\":[\"${path}\"]}" &>/dev/null

  echo -e "${GREEN}✅ Library '$name' added ($type) at $path${NC}"
  echo "   Scanning..."
}

cmd_scan_all() {
  require_api_key
  api_post "/Library/Refresh" &>/dev/null
  echo -e "${GREEN}✅ Library scan started${NC}"
}

cmd_scan_library() {
  require_api_key
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in --name) name="$2"; shift 2 ;; *) shift ;; esac
  done

  if [ -z "$name" ]; then
    echo "Usage: manage.sh scan-library --name NAME"
    exit 1
  fi

  # Get library ID by name
  local lib_id
  lib_id=$(api_get "/Library/VirtualFolders" | jq -r --arg name "$name" '.[] | select(.Name == $name) | .ItemId')

  if [ -z "$lib_id" ] || [ "$lib_id" = "null" ]; then
    echo -e "${RED}❌ Library '$name' not found${NC}"
    return 1
  fi

  api_post "/Items/${lib_id}/Refresh" &>/dev/null
  echo -e "${GREEN}✅ Scanning library: $name${NC}"
}

cmd_list_users() {
  require_api_key
  echo -e "${BLUE}👥 Users${NC}"
  echo "========="

  api_get "/Users" | jq -r '.[] | "   \(.Name) — \(if .Policy.IsAdministrator then "Admin" else "User" end) — Last login: \(.LastLoginDate // "never")"'
}

cmd_create_user() {
  require_api_key
  local name="" password="" is_admin="true"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --password) password="$2"; shift 2 ;;
      --no-admin) is_admin="false"; shift ;;
      *) shift ;;
    esac
  done

  if [ -z "$name" ]; then
    echo "Usage: manage.sh create-user --name NAME [--password PASS] [--no-admin]"
    exit 1
  fi

  local result
  result=$(api_post "/Users/New" "{\"Name\":\"${name}\",\"Password\":\"${password}\"}")
  local user_id
  user_id=$(echo "$result" | jq -r '.Id')

  if [ "$is_admin" = "false" ] && [ -n "$user_id" ]; then
    api_post "/Users/${user_id}/Policy" "{\"IsAdministrator\":false}" &>/dev/null
  fi

  echo -e "${GREEN}✅ User '$name' created ($([ "$is_admin" = "true" ] && echo "admin" || echo "user"))${NC}"
}

cmd_delete_user() {
  require_api_key
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in --name) name="$2"; shift 2 ;; *) shift ;; esac
  done

  local user_id
  user_id=$(api_get "/Users" | jq -r --arg name "$name" '.[] | select(.Name == $name) | .Id')

  if [ -z "$user_id" ] || [ "$user_id" = "null" ]; then
    echo -e "${RED}❌ User '$name' not found${NC}"
    return 1
  fi

  api_delete "/Users/${user_id}" &>/dev/null
  echo -e "${GREEN}✅ User '$name' deleted${NC}"
}

cmd_health() {
  require_api_key
  echo -e "${BLUE}🖥️ Jellyfin Health Report${NC}"
  echo "=========================="

  cmd_status
  echo ""

  # Scheduled tasks
  local tasks
  tasks=$(api_get "/ScheduledTasks" 2>/dev/null || echo "[]")
  local running
  running=$(echo "$tasks" | jq '[.[] | select(.State == "Running")] | length')
  echo "   Scheduled tasks: $(echo "$tasks" | jq 'length') total, $running running"

  # Disk usage
  echo ""
  echo -e "${BLUE}💾 Storage${NC}"
  df -h "$CONFIG_DIR" 2>/dev/null | tail -1 | awk '{print "   Config disk: "$3" used / "$2" ("$5" full)"}'

  # Log errors in last hour
  local log_errors
  log_errors=$(docker logs "$CONTAINER_NAME" --since 1h 2>&1 | grep -ci "error" || echo 0)
  if [ "$log_errors" -gt 0 ]; then
    echo -e "   ${YELLOW}⚠️  $log_errors errors in logs (last hour)${NC}"
  else
    echo -e "   ${GREEN}✅ No errors in logs (last hour)${NC}"
  fi
}

cmd_backup() {
  local output=""
  while [[ $# -gt 0 ]]; do
    case $1 in --output) output="$2"; shift 2 ;; *) shift ;; esac
  done

  output="${output:-jellyfin-backup-$(date +%Y%m%d-%H%M%S).tar.gz}"

  echo "📦 Backing up Jellyfin..."
  echo "   Config: $CONFIG_DIR"

  # Stop for consistent backup
  echo "   Stopping Jellyfin..."
  docker stop "$CONTAINER_NAME" &>/dev/null

  tar -czf "$output" -C "$(dirname "$CONFIG_DIR")" "$(basename "$CONFIG_DIR")"

  # Restart
  docker start "$CONTAINER_NAME" &>/dev/null
  echo -e "${GREEN}✅ Backup saved: $output ($(du -h "$output" | cut -f1))${NC}"
}

cmd_restore() {
  local input=""
  while [[ $# -gt 0 ]]; do
    case $1 in --input) input="$2"; shift 2 ;; *) shift ;; esac
  done

  if [ -z "$input" ] || [ ! -f "$input" ]; then
    echo "Usage: manage.sh restore --input /path/to/backup.tar.gz"
    exit 1
  fi

  echo "📦 Restoring Jellyfin from $input..."
  docker stop "$CONTAINER_NAME" &>/dev/null || true

  tar -xzf "$input" -C "$(dirname "$CONFIG_DIR")"

  docker start "$CONTAINER_NAME" &>/dev/null
  echo -e "${GREEN}✅ Restored. Jellyfin restarted.${NC}"
}

cmd_update() {
  echo "🔄 Updating Jellyfin..."

  local current
  if [ -n "$JELLYFIN_API_KEY" ]; then
    current=$(api_get "/System/Info" 2>/dev/null | jq -r '.Version // "unknown"')
    echo "   Current version: $current"
  fi

  echo "   Pulling latest image..."
  docker pull jellyfin/jellyfin:latest

  echo "   Restarting container..."
  docker stop "$CONTAINER_NAME" &>/dev/null
  docker rm "$CONTAINER_NAME" &>/dev/null

  # Get existing config from meta
  local meta="${CONFIG_DIR}/.jellyfin-skill-meta.json"
  if [ -f "$meta" ]; then
    local port media_dir cache_dir
    port=$(jq -r '.port' "$meta")
    media_dir=$(jq -r '.media_dir' "$meta")
    cache_dir=$(jq -r '.cache_dir' "$meta")

    # Detect hardware accel
    local hwaccel_args=""
    if [ -e /dev/dri/renderD128 ]; then
      hwaccel_args="--device /dev/dri:/dev/dri"
    elif command -v nvidia-smi &>/dev/null; then
      hwaccel_args="--runtime=nvidia --gpus all"
    fi

    docker run -d \
      --name "$CONTAINER_NAME" \
      --restart unless-stopped \
      -p "${port}:8096" -p 8920:8920 -p 7359:7359/udp -p 1900:1900/udp \
      -v "${CONFIG_DIR}:/config" \
      -v "${cache_dir}:/cache" \
      -v "${media_dir}/movies:/media/movies:ro" \
      -v "${media_dir}/tv:/media/tv:ro" \
      -v "${media_dir}/music:/media/music:ro" \
      -v "${media_dir}/photos:/media/photos:ro" \
      $hwaccel_args \
      jellyfin/jellyfin:latest
  else
    echo -e "${RED}❌ No install metadata found. Reinstall with install.sh${NC}"
    return 1
  fi

  # Wait and verify
  sleep 5
  if [ -n "$JELLYFIN_API_KEY" ]; then
    local new_version
    new_version=$(api_get "/System/Info" 2>/dev/null | jq -r '.Version // "unknown"')
    echo -e "${GREEN}✅ Jellyfin updated: $current → $new_version${NC}"
  else
    echo -e "${GREEN}✅ Jellyfin updated and restarted${NC}"
  fi
}

cmd_check_update() {
  require_api_key
  local current
  current=$(api_get "/System/Info" | jq -r '.Version')
  echo "   Current: $current"

  # Check Docker Hub for latest tag
  local latest
  latest=$(curl -sf "https://hub.docker.com/v2/repositories/jellyfin/jellyfin/tags/?page_size=5&name=latest" | jq -r '.results[0].last_updated')
  echo "   Latest image updated: $latest"
  echo "   Run: bash manage.sh update"
}

cmd_logs() {
  local tail_n=50
  while [[ $# -gt 0 ]]; do
    case $1 in --tail) tail_n="$2"; shift 2 ;; *) shift ;; esac
  done
  docker logs "$CONTAINER_NAME" --tail "$tail_n" 2>&1
}

cmd_restart() {
  local force=false
  while [[ $# -gt 0 ]]; do
    case $1 in --force) force=true; shift ;; *) shift ;; esac
  done

  if [ "$force" = true ]; then
    docker restart "$CONTAINER_NAME"
  else
    docker restart "$CONTAINER_NAME"
  fi
  echo -e "${GREEN}✅ Jellyfin restarted${NC}"
}

cmd_detect_hwaccel() {
  echo -e "${BLUE}🎬 Hardware Acceleration Detection${NC}"
  echo "====================================="

  if [ -e /dev/dri/renderD128 ]; then
    echo -e "   Intel QuickSync/VAAPI: ${GREEN}✅ Available${NC} (/dev/dri/renderD128)"
  else
    echo -e "   Intel QuickSync/VAAPI: ${RED}❌ Not detected${NC}"
  fi

  if command -v nvidia-smi &>/dev/null; then
    local gpu_name
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    echo -e "   NVIDIA NVENC: ${GREEN}✅ Available${NC} ($gpu_name)"
  else
    echo -e "   NVIDIA NVENC: ${RED}❌ Not detected${NC}"
  fi

  if [ -e /dev/video10 ] || [ -e /dev/video11 ]; then
    echo -e "   V4L2 (RPi): ${GREEN}✅ Available${NC}"
  else
    echo -e "   V4L2 (RPi): ${RED}❌ Not detected${NC}"
  fi
}

cmd_enable_hwaccel() {
  local type=""
  while [[ $# -gt 0 ]]; do
    case $1 in --type) type="$2"; shift 2 ;; *) shift ;; esac
  done

  echo "⚠️  To enable hardware transcoding:"
  echo "   1. Stop: docker stop $CONTAINER_NAME"
  echo "   2. Remove: docker rm $CONTAINER_NAME"
  echo "   3. Re-run install.sh (it auto-detects GPU)"
  echo "   4. In Jellyfin Dashboard > Playback > Transcoding:"
  echo "      Set 'Hardware acceleration' to '${type:-VAAPI}'"
}

# Main router
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  status) cmd_status ;;
  health) cmd_health ;;
  list-libraries) cmd_list_libraries ;;
  add-library) cmd_add_library "$@" ;;
  scan-all) cmd_scan_all ;;
  scan-library) cmd_scan_library "$@" ;;
  list-users) cmd_list_users ;;
  create-user) cmd_create_user "$@" ;;
  delete-user) cmd_delete_user "$@" ;;
  backup) cmd_backup "$@" ;;
  restore) cmd_restore "$@" ;;
  update) cmd_update ;;
  check-update) cmd_check_update ;;
  logs) cmd_logs "$@" ;;
  restart) cmd_restart "$@" ;;
  detect-hwaccel) cmd_detect_hwaccel ;;
  enable-hwaccel) cmd_enable_hwaccel "$@" ;;
  help|*)
    echo "Jellyfin Media Server Manager"
    echo ""
    echo "Usage: manage.sh COMMAND [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status              Show server status"
    echo "  health              Full health report"
    echo "  list-libraries      List media libraries"
    echo "  add-library         Add a media library"
    echo "  scan-all            Scan all libraries"
    echo "  scan-library        Scan specific library"
    echo "  list-users          List user accounts"
    echo "  create-user         Create a user"
    echo "  delete-user         Delete a user"
    echo "  backup              Backup config & metadata"
    echo "  restore             Restore from backup"
    echo "  update              Update to latest version"
    echo "  check-update        Check for updates"
    echo "  logs                View container logs"
    echo "  restart             Restart Jellyfin"
    echo "  detect-hwaccel      Detect hardware acceleration"
    echo "  enable-hwaccel      Enable hardware transcoding"
    ;;
esac
