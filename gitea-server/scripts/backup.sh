#!/bin/bash
# Gitea Backup Manager — backup/restore/schedule
set -euo pipefail

BACKUP_DIR="${GITEA_BACKUP_DIR:-/backups/gitea}"
KEEP="${GITEA_BACKUP_KEEP:-7}"
GITEA_CONFIG="/etc/gitea/app.ini"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[BACKUP]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Parse arguments
ACTION="backup"
RESTORE_FILE=""
SCHEDULE_TIME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --output) BACKUP_DIR="$2"; shift 2 ;;
    --keep) KEEP="$2"; shift 2 ;;
    --schedule) ACTION="schedule"; shift ;;
    --time) SCHEDULE_TIME="$2"; shift 2 ;;
    --restore) ACTION="restore"; shift ;;
    --file) RESTORE_FILE="$2"; shift 2 ;;
    --help) echo "Usage: backup.sh [--output /backups/gitea] [--keep 7] [--schedule --time 02:00] [--restore --file <path>]"; exit 0 ;;
    *) shift ;;
  esac
done

do_backup() {
  mkdir -p "$BACKUP_DIR"

  local timestamp
  timestamp=$(date +%Y-%m-%d_%H%M%S)
  local backup_file="gitea-backup-${timestamp}.zip"

  log "Starting backup..."
  log "Output: $BACKUP_DIR/$backup_file"

  # Use Gitea's built-in dump
  cd /tmp
  sudo -u git gitea dump \
    --config "$GITEA_CONFIG" \
    --file "$BACKUP_DIR/$backup_file" \
    --type zip 2>&1 | while read -r line; do
    log "  $line"
  done

  if [[ -f "$BACKUP_DIR/$backup_file" ]]; then
    local size
    size=$(du -h "$BACKUP_DIR/$backup_file" | cut -f1)
    log "✅ Backup complete: $backup_file ($size)"
  else
    # Gitea dump sometimes names differently
    local actual
    actual=$(ls -t /tmp/gitea-dump-*.zip 2>/dev/null | head -1)
    if [[ -n "$actual" ]]; then
      mv "$actual" "$BACKUP_DIR/$backup_file"
      local size
      size=$(du -h "$BACKUP_DIR/$backup_file" | cut -f1)
      log "✅ Backup complete: $backup_file ($size)"
    else
      error "Backup file not found"
      exit 1
    fi
  fi

  # Rotate old backups
  local count
  count=$(ls -1 "$BACKUP_DIR"/gitea-backup-*.zip 2>/dev/null | wc -l)
  if [[ $count -gt $KEEP ]]; then
    local to_delete=$((count - KEEP))
    log "Rotating: removing $to_delete old backup(s)..."
    ls -1t "$BACKUP_DIR"/gitea-backup-*.zip | tail -n "$to_delete" | while read -r f; do
      rm -f "$f"
      log "  Deleted: $(basename "$f")"
    done
  fi

  log "Backups retained: $KEEP"
}

do_restore() {
  if [[ -z "$RESTORE_FILE" || ! -f "$RESTORE_FILE" ]]; then
    error "Restore file not found: $RESTORE_FILE"
    error "Usage: backup.sh --restore --file /path/to/gitea-backup.zip"
    exit 1
  fi

  warn "⚠️  This will overwrite the current Gitea installation!"
  warn "Press Ctrl+C within 5 seconds to cancel..."
  sleep 5

  log "Stopping Gitea..."
  sudo systemctl stop gitea

  log "Extracting backup..."
  local temp_dir
  temp_dir=$(mktemp -d)
  unzip -q "$RESTORE_FILE" -d "$temp_dir"

  # Restore database
  if [[ -f "$temp_dir/gitea-db.sql" ]]; then
    log "Restoring database..."
    # For SQLite
    if grep -q 'DB_TYPE.*=.*sqlite' "$GITEA_CONFIG"; then
      cp "$temp_dir/gitea-db.sql" /var/lib/gitea/data/gitea.db
    else
      warn "Non-SQLite restore requires manual database import"
      log "SQL dump: $temp_dir/gitea-db.sql"
    fi
  fi

  # Restore repositories
  if [[ -d "$temp_dir/repos" ]]; then
    log "Restoring repositories..."
    cp -r "$temp_dir/repos/"* /var/lib/gitea/repositories/ 2>/dev/null || true
  fi

  # Restore data
  if [[ -d "$temp_dir/data" ]]; then
    log "Restoring data..."
    cp -r "$temp_dir/data/"* /var/lib/gitea/data/ 2>/dev/null || true
  fi

  # Fix permissions
  chown -R git:git /var/lib/gitea

  # Cleanup
  rm -rf "$temp_dir"

  log "Starting Gitea..."
  sudo systemctl start gitea

  sleep 3
  if systemctl is-active --quiet gitea; then
    log "✅ Restore complete. Gitea is running."
  else
    error "Gitea failed to start. Check: sudo journalctl -u gitea -f"
  fi
}

do_schedule() {
  local time="${SCHEDULE_TIME:-02:00}"
  local hour minute
  hour=$(echo "$time" | cut -d: -f1)
  minute=$(echo "$time" | cut -d: -f2)

  local script_path
  script_path=$(readlink -f "$0")

  local cron_line="$minute $hour * * * $script_path --output $BACKUP_DIR --keep $KEEP >> /var/log/gitea-backup.log 2>&1"

  # Add to crontab
  (crontab -l 2>/dev/null | grep -v "gitea.*backup"; echo "$cron_line") | crontab -

  log "✅ Backup scheduled at $time daily"
  log "Keeping last $KEEP backups in $BACKUP_DIR"
  log "Logs: /var/log/gitea-backup.log"
  log ""
  log "To remove: crontab -e (delete the gitea backup line)"
}

# Dispatch
case "$ACTION" in
  backup) do_backup ;;
  restore) do_restore ;;
  schedule) do_schedule ;;
esac
