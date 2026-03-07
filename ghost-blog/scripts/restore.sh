#!/bin/bash
# Ghost Blog Manager — Restore from Backup
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[ghost-blog]${NC} $1"; }
err() { echo -e "${RED}[ghost-blog]${NC} $1" >&2; }

BACKUP_FILE="${1:-}"
NAME="${2:-ghost}"
[ -z "$BACKUP_FILE" ] && { err "Usage: $0 <backup-file.tar.gz> [name]"; exit 1; }
[ ! -f "$BACKUP_FILE" ] && { err "Backup not found: $BACKUP_FILE"; exit 1; }

DEPLOY_DIR="$HOME/ghost-deployments/$NAME"
TMP=$(mktemp -d)

log "=== Restoring Ghost ($NAME) from backup ==="

# Extract
tar -xzf "$BACKUP_FILE" -C "$TMP"

# Restore config
cd "$DEPLOY_DIR"
cp "$TMP/docker-compose.yml" .
cp "$TMP/.env" .
[ -f "$TMP/Caddyfile" ] && cp "$TMP/Caddyfile" .

source .env

# Restart services
docker compose up -d 2>/dev/null || docker-compose up -d
sleep 10

# Restore database
log "Restoring database..."
CONTAINER=$(docker compose ps -q db 2>/dev/null || docker-compose ps -q db)
docker exec -i "$CONTAINER" mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" < "$TMP/database.sql"

# Restore content
log "Restoring content..."
GHOST_CONTAINER=$(docker compose ps -q ghost 2>/dev/null || docker-compose ps -q ghost)
docker cp "$TMP/content/." "$GHOST_CONTAINER:/var/lib/ghost/content/"

# Restart Ghost to pick up changes
docker compose restart ghost 2>/dev/null || docker-compose restart ghost

rm -rf "$TMP"
log "=== ✅ Restore complete ==="
