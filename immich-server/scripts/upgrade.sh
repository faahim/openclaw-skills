#!/bin/bash
# Immich Server — Upgrade Script
set -euo pipefail

INSTALL_DIR="${IMMICH_DIR:-/opt/immich}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

cd "$INSTALL_DIR"

# Get current version
CURRENT=$(docker inspect immich_server 2>/dev/null | jq -r '.[0].Config.Image' | cut -d: -f2)
log "📋 Current version: ${CURRENT:-unknown}"

# Check latest
LATEST=$(curl -sL "https://api.github.com/repos/immich-app/immich/releases/latest" | jq -r '.tag_name')
log "🆕 Latest version: $LATEST"

if [ "$CURRENT" = "$LATEST" ]; then
  log "✅ Already on latest version. No upgrade needed."
  exit 0
fi

# Backup before upgrade
log "💾 Creating pre-upgrade backup..."
bash "$SCRIPT_DIR/backup.sh" --tag "pre-upgrade-$LATEST"

# Pull new images
log "⬇️ Pulling new images..."
docker compose pull

# Restart
log "🔄 Restarting containers..."
docker compose down
docker compose up -d

# Wait for health
log "⏳ Waiting for server..."
sleep 15

PORT=$(grep -oP '(\d+):2283' docker-compose.yml | cut -d: -f1)
PORT="${PORT:-2283}"

RETRIES=20
for i in $(seq 1 $RETRIES); do
  if curl -sf "http://localhost:${PORT}/api/server/ping" &>/dev/null; then
    break
  fi
  sleep 5
done

# Verify
NEW_VER=$(docker inspect immich_server 2>/dev/null | jq -r '.[0].Config.Image' | cut -d: -f2)
log "✅ Upgraded to $NEW_VER"

# Cleanup old images
log "🗑️ Cleaning up old images..."
docker image prune -f --filter "until=24h" 2>/dev/null || true

log "✅ Upgrade complete!"
