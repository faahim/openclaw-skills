#!/bin/bash
# Immich Server — Database Restore Script
set -euo pipefail

INSTALL_DIR="${IMMICH_DIR:-/opt/immich}"

if [ $# -lt 1 ]; then
  echo "Usage: restore.sh <backup-file.sql.gz>"
  echo ""
  echo "Available backups:"
  ls -lt "$INSTALL_DIR/backups/"*.sql.gz 2>/dev/null | awk '{print "  " $NF " (" $5 " bytes, " $6 " " $7 " " $8 ")"}'
  exit 1
fi

BACKUP_FILE="$1"
log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

if [ ! -f "$BACKUP_FILE" ]; then
  log "❌ Backup file not found: $BACKUP_FILE"
  exit 1
fi

cd "$INSTALL_DIR"
source .env 2>/dev/null || true
DB_USER="${DB_USERNAME:-postgres}"

# Get DB container
DB_CONTAINER=$(docker compose ps -q database 2>/dev/null || docker compose ps -q immich_postgres 2>/dev/null)
if [ -z "$DB_CONTAINER" ]; then
  DB_CONTAINER=$(docker ps --filter "name=immich" --filter "name=postgres" -q | head -1)
fi

if [ -z "$DB_CONTAINER" ]; then
  log "❌ Cannot find PostgreSQL container"
  exit 1
fi

log "⚠️ This will REPLACE the current database with the backup."
read -p "Are you sure? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  log "Cancelled."
  exit 0
fi

# Stop app containers but keep DB running
log "🛑 Stopping Immich application..."
docker compose stop immich-server immich-microservices immich-machine-learning 2>/dev/null || true

# Restore
log "💾 Restoring database from $(basename "$BACKUP_FILE")..."
gunzip -c "$BACKUP_FILE" | docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" 2>/dev/null

# Restart everything
log "🚀 Restarting Immich..."
docker compose up -d

log "✅ Database restored successfully!"
