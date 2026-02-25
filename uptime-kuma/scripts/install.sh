#!/bin/bash
# Uptime Kuma Installer — Docker-based
set -euo pipefail

PORT="${KUMA_PORT:-3001}"
DATA_DIR="${KUMA_DATA_DIR:-$HOME/.uptime-kuma/data}"
CONTAINER_NAME="uptime-kuma"
IMAGE="louislam/uptime-kuma:1"

usage() {
  echo "Usage: $0 [install|status|upgrade|backup|restore|uninstall] [options]"
  echo ""
  echo "Commands:"
  echo "  install     Install Uptime Kuma (default)"
  echo "  status      Check container status"
  echo "  upgrade     Upgrade to latest version"
  echo "  backup      Backup data directory"
  echo "  restore     Restore from backup"
  echo "  uninstall   Remove container and optionally data"
  echo ""
  echo "Options:"
  echo "  --port PORT         Port to expose (default: 3001)"
  echo "  --data-dir DIR      Data directory (default: ~/.uptime-kuma/data)"
  echo "  --file FILE         Backup file for restore"
}

check_docker() {
  if ! command -v docker &>/dev/null; then
    echo "❌ Docker not found. Install it first:"
    echo "   curl -fsSL https://get.docker.com | sh"
    exit 1
  fi
  if ! docker info &>/dev/null; then
    echo "❌ Docker daemon not running or no permission."
    echo "   Try: sudo systemctl start docker"
    echo "   Or:  sudo usermod -aG docker \$USER && newgrp docker"
    exit 1
  fi
}

do_install() {
  check_docker
  
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "⚠️  Container '$CONTAINER_NAME' already exists."
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      echo "✅ Already running at http://localhost:${PORT}"
    else
      echo "Starting existing container..."
      docker start "$CONTAINER_NAME"
      echo "✅ Started at http://localhost:${PORT}"
    fi
    return
  fi

  mkdir -p "$DATA_DIR"

  echo "📦 Pulling Uptime Kuma..."
  docker pull "$IMAGE"

  echo "🚀 Starting Uptime Kuma on port ${PORT}..."
  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p "${PORT}:3001" \
    -v "${DATA_DIR}:/app/data" \
    "$IMAGE"

  echo ""
  echo "✅ Uptime Kuma is running!"
  echo "   Dashboard: http://localhost:${PORT}"
  echo "   Data dir:  ${DATA_DIR}"
  echo ""
  echo "Next: Open the dashboard to create your admin account."
  echo "Or run: bash scripts/setup.sh --username admin --password 'YourPassword'"
}

do_status() {
  if docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -q "^${CONTAINER_NAME}"; then
    echo "✅ Uptime Kuma is running"
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep "$CONTAINER_NAME"
    echo ""
    # Check API
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/api/info" | grep -q "200"; then
      echo "API: ✅ Responding"
      curl -s "http://localhost:${PORT}/api/info" | jq -r '"Version: \(.version)\nLatest: \(.latestVersion)"' 2>/dev/null || true
    else
      echo "API: ⏳ Starting up (may take a few seconds)"
    fi
  elif docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "⚠️  Uptime Kuma container exists but is stopped"
    echo "Run: docker start $CONTAINER_NAME"
  else
    echo "❌ Uptime Kuma is not installed"
    echo "Run: bash scripts/install.sh"
  fi
}

do_upgrade() {
  check_docker
  echo "📦 Pulling latest image..."
  docker pull "$IMAGE"
  
  echo "♻️  Restarting container..."
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  
  # Get current config
  CURRENT_PORT=$(docker port "$CONTAINER_NAME" 3001 2>/dev/null | cut -d: -f2 || echo "$PORT")
  CURRENT_MOUNT=$(docker inspect "$CONTAINER_NAME" --format '{{range .Mounts}}{{if eq .Destination "/app/data"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || echo "$DATA_DIR")
  
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  
  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p "${CURRENT_PORT:-$PORT}:3001" \
    -v "${CURRENT_MOUNT:-$DATA_DIR}:/app/data" \
    "$IMAGE"

  echo "✅ Upgraded! Dashboard: http://localhost:${CURRENT_PORT:-$PORT}"
}

do_backup() {
  BACKUP_FILE="uptime-kuma-backup-$(date +%Y-%m-%d-%H%M%S).tar.gz"
  
  echo "📦 Backing up Uptime Kuma data..."
  
  # Stop briefly for consistent backup
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  
  tar -czf "$BACKUP_FILE" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"
  
  docker start "$CONTAINER_NAME" 2>/dev/null || true
  
  echo "✅ Backup saved to: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
}

do_restore() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "❌ Backup file not found: $file"
    exit 1
  fi
  
  echo "⚠️  This will overwrite current data. Proceeding in 5 seconds..."
  sleep 5
  
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  
  rm -rf "$DATA_DIR"
  mkdir -p "$(dirname "$DATA_DIR")"
  tar -xzf "$file" -C "$(dirname "$DATA_DIR")"
  
  docker start "$CONTAINER_NAME"
  echo "✅ Restored from $file"
}

do_uninstall() {
  echo "Removing Uptime Kuma container..."
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  echo "✅ Container removed."
  echo "   Data still at: $DATA_DIR"
  echo "   To remove data: rm -rf $DATA_DIR"
}

# Parse args
CMD="${1:-install}"
shift 2>/dev/null || true
RESTORE_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    --file) RESTORE_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) shift ;;
  esac
done

case "$CMD" in
  install) do_install ;;
  status) do_status ;;
  upgrade) do_upgrade ;;
  backup) do_backup ;;
  restore) do_restore "$RESTORE_FILE" ;;
  uninstall) do_uninstall ;;
  *) usage; exit 1 ;;
esac
