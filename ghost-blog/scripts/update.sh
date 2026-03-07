#!/bin/bash
# Ghost Blog Manager — Update to Latest Version
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[ghost-blog]${NC} $1"; }
warn() { echo -e "${YELLOW}[ghost-blog]${NC} $1"; }

NAME="${1:-ghost}"
DEPLOY_DIR="$HOME/ghost-deployments/$NAME"
cd "$DEPLOY_DIR"

# Get current version
CONTAINER=$(docker compose ps -q ghost 2>/dev/null || docker-compose ps -q ghost)
CURRENT=$(docker inspect "$CONTAINER" --format '{{.Config.Image}}' 2>/dev/null || echo "unknown")
log "Current: $CURRENT"

# Backup first
log "Creating pre-update backup..."
bash "$(dirname "$0")/backup.sh" "$NAME"

# Pull latest
log "Pulling latest Ghost image..."
docker compose pull ghost 2>/dev/null || docker-compose pull ghost

# Restart
log "Restarting with new image..."
docker compose up -d ghost 2>/dev/null || docker-compose up -d ghost

# Wait
sleep 15

NEW=$(docker inspect "$(docker compose ps -q ghost 2>/dev/null)" --format '{{.Config.Image}}' 2>/dev/null || echo "unknown")
log "=== ✅ Update complete ==="
log "Previous: $CURRENT"
log "Current:  $NEW"
