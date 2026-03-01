#!/bin/bash
# Radicale Backup Script
set -e

RADICALE_DATA="${RADICALE_DATA_DIR:-$HOME/.local/share/radicale/collections}"
RADICALE_CONFIG="${RADICALE_CONFIG_DIR:-$HOME/.config/radicale}"
BACKUP_DIR="${RADICALE_BACKUP_DIR:-$HOME/radicale-backups}"
SETUP_CRON=false
KEEP_DAYS=30

while [[ $# -gt 0 ]]; do
  case $1 in
    --cron) SETUP_CRON=true; shift ;;
    --dir) BACKUP_DIR="$2"; shift 2 ;;
    --keep) KEEP_DAYS="$2"; shift 2 ;;
    --help)
      echo "Usage: bash backup.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --cron         Set up daily cron job"
      echo "  --dir PATH     Backup directory (default: ~/radicale-backups)"
      echo "  --keep DAYS    Keep backups for N days (default: 30)"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if $SETUP_CRON; then
  SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/backup.sh"
  CRON_LINE="0 2 * * * bash $SCRIPT_PATH --dir $BACKUP_DIR --keep $KEEP_DAYS >> /tmp/radicale-backup.log 2>&1"

  if crontab -l 2>/dev/null | grep -q "radicale.*backup"; then
    echo "⏭️  Cron job already exists"
  else
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    echo "✅ Daily backup cron set (2:00 AM)"
  fi
  exit 0
fi

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/radicale-backup-${TIMESTAMP}.tar.gz"

echo "📦 Backing up Radicale data..."

tar -czf "$BACKUP_FILE" \
  -C "$(dirname "$RADICALE_DATA")" "$(basename "$RADICALE_DATA")" \
  -C "$(dirname "$RADICALE_CONFIG")" "$(basename "$RADICALE_CONFIG")" \
  2>/dev/null

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
echo "✅ Backup created: $BACKUP_FILE ($SIZE)"

# Clean old backups
if [ "$KEEP_DAYS" -gt 0 ]; then
  DELETED=$(find "$BACKUP_DIR" -name "radicale-backup-*.tar.gz" -mtime +"$KEEP_DAYS" -delete -print | wc -l)
  [ "$DELETED" -gt 0 ] && echo "🧹 Cleaned $DELETED old backup(s)"
fi
