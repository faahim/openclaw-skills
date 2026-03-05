#!/bin/bash
# Node-RED Manager — Backup & Restore
set -euo pipefail

NR_DIR="${NODE_RED_DIR:-$HOME/.node-red}"
ACTION="backup"
OUTPUT_DIR=""
RESTORE_FILE=""
SCHEDULE=""
KEEP=7

while [[ $# -gt 0 ]]; do
  case $1 in
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --restore) ACTION="restore"; RESTORE_FILE="$2"; shift 2 ;;
    --schedule) SCHEDULE="$2"; shift 2 ;;
    --keep) KEEP="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

backup() {
  OUTPUT_DIR="${OUTPUT_DIR:-$HOME/node-red-backups}"
  mkdir -p "$OUTPUT_DIR"

  TIMESTAMP=$(date -u +%Y-%m-%dT%H-%M-%S)
  BACKUP_NAME="node-red-backup-${TIMESTAMP}.tar.gz"
  BACKUP_PATH="$OUTPUT_DIR/$BACKUP_NAME"

  echo "📦 Backing up Node-RED..."
  echo "   Source: $NR_DIR"

  # Files to backup
  FILES=""
  for f in flows.json flows_cred.json settings.js package.json package-lock.json .config.nodes.json .config.runtime.json; do
    if [ -f "$NR_DIR/$f" ]; then
      FILES="$FILES $f"
    fi
  done

  # Include lib/ directory if it exists (custom function libraries)
  TAR_EXTRA=""
  if [ -d "$NR_DIR/lib" ]; then
    TAR_EXTRA="lib/"
  fi

  # Include projects/ if it exists
  if [ -d "$NR_DIR/projects" ]; then
    TAR_EXTRA="$TAR_EXTRA projects/"
  fi

  cd "$NR_DIR"
  tar -czf "$BACKUP_PATH" $FILES $TAR_EXTRA 2>/dev/null

  SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
  echo "✅ Backup saved: $BACKUP_PATH ($SIZE)"
  echo "   Includes: $FILES $TAR_EXTRA"

  # Clean old backups
  if [ "$KEEP" -gt 0 ]; then
    BACKUPS=$(ls -1t "$OUTPUT_DIR"/node-red-backup-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)))
    if [ -n "$BACKUPS" ]; then
      echo "$BACKUPS" | xargs rm -f
      DELETED=$(echo "$BACKUPS" | wc -l)
      echo "🗑️  Cleaned $DELETED old backup(s) (keeping $KEEP)"
    fi
  fi

  # Create a 'latest' symlink
  ln -sf "$BACKUP_NAME" "$OUTPUT_DIR/latest.tar.gz"
}

restore() {
  if [ -z "$RESTORE_FILE" ] || [ ! -f "$RESTORE_FILE" ]; then
    echo "❌ Backup file not found: $RESTORE_FILE"
    exit 1
  fi

  echo "🔄 Restoring Node-RED from backup..."
  echo "   Source: $RESTORE_FILE"
  echo "   Target: $NR_DIR"

  # Backup current state first
  if [ -f "$NR_DIR/flows.json" ]; then
    SAFETY_BACKUP="$NR_DIR/flows.json.pre-restore.$(date +%s)"
    cp "$NR_DIR/flows.json" "$SAFETY_BACKUP"
    echo "   Safety backup: $SAFETY_BACKUP"
  fi

  cd "$NR_DIR"
  tar -xzf "$RESTORE_FILE"

  echo "✅ Restore complete"
  echo "   Restart Node-RED to apply: bash scripts/manage.sh restart"
}

schedule_backup() {
  if [ -z "$SCHEDULE" ]; then
    echo "Usage: bash scripts/backup.sh --schedule '0 2 * * *' --output ~/backups --keep 7"
    exit 1
  fi

  OUTPUT_DIR="${OUTPUT_DIR:-$HOME/node-red-backups}"
  SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/backup.sh"

  CRON_CMD="$SCHEDULE NODE_RED_DIR=$NR_DIR bash $SCRIPT_PATH --output $OUTPUT_DIR --keep $KEEP"

  # Add to crontab
  (crontab -l 2>/dev/null | grep -v "node-red-backup"; echo "$CRON_CMD") | crontab -

  echo "✅ Backup scheduled"
  echo "   Schedule: $SCHEDULE"
  echo "   Output:   $OUTPUT_DIR"
  echo "   Keep:     $KEEP backups"
  echo ""
  echo "Current crontab:"
  crontab -l | grep node-red
}

# Main
if [ -n "$SCHEDULE" ]; then
  schedule_backup
elif [ "$ACTION" = "restore" ]; then
  restore
else
  backup
fi
