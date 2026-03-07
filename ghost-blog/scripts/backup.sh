#!/bin/bash
# Ghost Blog Manager — Backup
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[ghost-blog]${NC} $1"; }

NAME="${1:-ghost}"
DEPLOY_DIR="$HOME/ghost-deployments/$NAME"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
BACKUP_DIR="$DEPLOY_DIR/backups"
BACKUP_FILE="ghost-backup-$TIMESTAMP.tar.gz"

cd "$DEPLOY_DIR"
mkdir -p "$BACKUP_DIR/tmp-$TIMESTAMP"
TMP="$BACKUP_DIR/tmp-$TIMESTAMP"

log "=== Backing up Ghost ($NAME) ==="

# 1. Database dump
log "Dumping MySQL database..."
source .env
CONTAINER=$(docker compose ps -q db 2>/dev/null || docker-compose ps -q db)
docker exec "$CONTAINER" mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" > "$TMP/database.sql"
log "Database dumped ($(du -h "$TMP/database.sql" | cut -f1))"

# 2. Content directory
log "Copying Ghost content..."
GHOST_CONTAINER=$(docker compose ps -q ghost 2>/dev/null || docker-compose ps -q ghost)
docker cp "$GHOST_CONTAINER:/var/lib/ghost/content" "$TMP/content"
log "Content copied"

# 3. Config files
cp docker-compose.yml "$TMP/"
cp .env "$TMP/"
[ -f Caddyfile ] && cp Caddyfile "$TMP/"
[ -f docker-compose.override.yml ] && cp docker-compose.override.yml "$TMP/"

# 4. Compress
log "Compressing..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_FILE" -C "tmp-$TIMESTAMP" .
rm -rf "tmp-$TIMESTAMP"

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "=== ✅ Backup complete ==="
log "File: $BACKUP_DIR/$BACKUP_FILE ($SIZE)"
