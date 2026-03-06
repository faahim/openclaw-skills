#!/bin/bash
# Vikunja Backup Script
set -euo pipefail

VIKUNJA_DIR="${VIKUNJA_DIR:-$HOME/vikunja}"
BACKUP_DIR="${BACKUP_DIR:-$VIKUNJA_DIR/backups}"
KEEP_DAYS="${KEEP_DAYS:-7}"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"
cd "$VIKUNJA_DIR"

echo "📦 Backing up Vikunja..."

# Create backup archive
BACKUP_FILE="$BACKUP_DIR/vikunja-$DATE.tar.gz"
tar czf "$BACKUP_FILE" \
    --exclude='backups' \
    --exclude='pgdata/postmaster.pid' \
    db/ files/ docker-compose.yml 2>/dev/null || \
tar czf "$BACKUP_FILE" \
    --exclude='backups' \
    files/ docker-compose.yml pgdata/ 2>/dev/null

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
echo "✅ Backup created: $BACKUP_FILE ($SIZE)"

# Cleanup old backups
if [ "$KEEP_DAYS" -gt 0 ]; then
    DELETED=$(find "$BACKUP_DIR" -name "vikunja-*.tar.gz" -mtime +"$KEEP_DAYS" -delete -print | wc -l)
    [ "$DELETED" -gt 0 ] && echo "🗑️  Cleaned up $DELETED old backup(s)"
fi

echo "Done."
