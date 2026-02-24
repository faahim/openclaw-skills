#!/bin/bash
# Immich Server — Database Backup Script
set -euo pipefail

INSTALL_DIR="${IMMICH_DIR:-/opt/immich}"
BACKUP_DIR="$INSTALL_DIR/backups"
KEEP=7
TAG=""
SCHEDULE=""

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

while [[ $# -gt 0 ]]; do
  case $1 in
    --keep) KEEP="$2"; shift 2 ;;
    --tag) TAG="-$2"; shift 2 ;;
    --backup-dir) BACKUP_DIR="$2"; shift 2 ;;
    --schedule)
      SCHEDULE="$2"; shift 2
      CRON_EXPR=""
      case "$SCHEDULE" in
        daily) CRON_EXPR="0 3 * * *" ;;
        weekly) CRON_EXPR="0 3 * * 0" ;;
        hourly) CRON_EXPR="0 * * * *" ;;
        *) echo "Unknown schedule: $SCHEDULE (use daily/weekly/hourly)"; exit 1 ;;
      esac
      SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/backup.sh"
      (crontab -l 2>/dev/null | grep -v "immich.*backup"; echo "$CRON_EXPR $SCRIPT_PATH --keep $KEEP >> /var/log/immich-backup.log 2>&1") | crontab -
      log "✅ Scheduled $SCHEDULE backup (keeping last $KEEP)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

cd "$INSTALL_DIR"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/immich-backup-${TIMESTAMP}${TAG}.sql.gz"

# Get DB container name
DB_CONTAINER=$(docker compose ps -q database 2>/dev/null || docker compose ps -q immich_postgres 2>/dev/null || echo "")
if [ -z "$DB_CONTAINER" ]; then
  # Try common names
  DB_CONTAINER=$(docker ps --filter "name=immich" --filter "name=postgres" -q | head -1)
fi

if [ -z "$DB_CONTAINER" ]; then
  log "❌ Cannot find Immich PostgreSQL container"
  exit 1
fi

# Source .env for DB credentials
source .env 2>/dev/null || true
DB_USER="${DB_USERNAME:-postgres}"

# Dump database
log "💾 Dumping PostgreSQL database..."
docker exec "$DB_CONTAINER" pg_dumpall -U "$DB_USER" | gzip > "$BACKUP_FILE"

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "📦 Compressed: $(basename "$BACKUP_FILE") ($BACKUP_SIZE)"

# Cleanup old backups
if [ "$KEEP" -gt 0 ]; then
  DELETED=$(find "$BACKUP_DIR" -name "immich-backup-*.sql.gz" -type f | sort -r | tail -n +$((KEEP + 1)))
  if [ -n "$DELETED" ]; then
    echo "$DELETED" | xargs rm -f
    log "🗑️ Cleaned up $(echo "$DELETED" | wc -l) old backups (keeping last $KEEP)"
  fi
fi

log "✅ Backup complete: $BACKUP_FILE"
