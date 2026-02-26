#!/bin/bash
# MongoDB Backup & Restore Script
set -euo pipefail

MONGO_HOST="${MONGO_HOST:-localhost}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_USER="${MONGO_USER:-}"
MONGO_PASS="${MONGO_PASS:-}"
MONGO_AUTH_DB="${MONGO_AUTH_DB:-admin}"
MONGO_BACKUP_DIR="${MONGO_BACKUP_DIR:-/backups/mongo}"
MONGO_BACKUP_RETENTION="${MONGO_BACKUP_RETENTION:-30}"

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

ACTION="backup"
DB=""
OUTPUT=""
COMPRESS=false
S3_PATH=""
INPUT=""
RETENTION=""

usage() {
  cat <<EOF
MongoDB Backup & Restore

Usage:
  $0 [options]              Full or single-db backup
  $0 restore [options]      Restore from backup

Backup Options:
  --db NAME          Backup single database (default: all)
  --output DIR       Output directory (default: \$MONGO_BACKUP_DIR)
  --compress         Gzip compress the backup
  --s3 S3_PATH       Upload to S3 after backup
  --retention DAYS   Delete backups older than N days (default: 30)

Restore Options:
  --input PATH       Backup file/directory to restore
  --db NAME          Restore to specific database
EOF
  exit 1
}

# Parse args
if [[ "${1:-}" == "restore" ]]; then
  ACTION="restore"
  shift
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --db) DB="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --compress) COMPRESS=true; shift ;;
    --s3) S3_PATH="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    --retention) RETENTION="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown: $1"; usage ;;
  esac
done

# Build auth opts
AUTH_OPTS=""
if [[ -n "$MONGO_USER" && -n "$MONGO_PASS" ]]; then
  AUTH_OPTS="--host=$MONGO_HOST --port=$MONGO_PORT -u=$MONGO_USER -p=$MONGO_PASS --authenticationDatabase=$MONGO_AUTH_DB"
else
  AUTH_OPTS="--host=$MONGO_HOST --port=$MONGO_PORT"
fi

send_alert() {
  local msg="$1"
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=${msg}" \
      -d "parse_mode=HTML" > /dev/null 2>&1 || true
  fi
}

do_backup() {
  OUTPUT="${OUTPUT:-$MONGO_BACKUP_DIR}"
  RETENTION="${RETENTION:-$MONGO_BACKUP_RETENTION}"
  
  local TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
  local BACKUP_NAME="${DB:-full}_${TIMESTAMP}"
  local BACKUP_PATH="$OUTPUT/$BACKUP_NAME"
  
  mkdir -p "$OUTPUT"
  
  echo "🔄 Starting backup: $BACKUP_NAME"
  local START=$(date +%s)
  
  DUMP_OPTS="$AUTH_OPTS --out=$BACKUP_PATH"
  [[ -n "$DB" ]] && DUMP_OPTS="$DUMP_OPTS --db=$DB"
  [[ "$COMPRESS" == true ]] && DUMP_OPTS="$DUMP_OPTS --gzip"
  
  if mongodump $DUMP_OPTS 2>/dev/null; then
    local END=$(date +%s)
    local ELAPSED=$((END - START))
    local SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
    
    echo "✅ Backup saved to $BACKUP_PATH ($SIZE, ${ELAPSED}s)"
    
    # Compress to single archive if not using --gzip
    if [[ "$COMPRESS" == true ]]; then
      local ARCHIVE="${BACKUP_PATH}.tar.gz"
      tar -czf "$ARCHIVE" -C "$OUTPUT" "$BACKUP_NAME" 2>/dev/null
      rm -rf "$BACKUP_PATH"
      BACKUP_PATH="$ARCHIVE"
      SIZE=$(du -sh "$ARCHIVE" | cut -f1)
      echo "📦 Compressed to $ARCHIVE ($SIZE)"
    fi
    
    # Upload to S3
    if [[ -n "$S3_PATH" ]]; then
      echo "☁️ Uploading to $S3_PATH..."
      if aws s3 cp "$BACKUP_PATH" "$S3_PATH$(basename $BACKUP_PATH)" --quiet 2>/dev/null; then
        echo "✅ Uploaded to S3"
      else
        echo "❌ S3 upload failed"
        send_alert "❌ MongoDB backup S3 upload failed: $BACKUP_NAME"
      fi
    fi
    
    # Cleanup old backups
    if [[ "$RETENTION" -gt 0 ]]; then
      local DELETED=$(find "$OUTPUT" -maxdepth 1 -mtime +${RETENTION} -name "*.tar.gz" -o -name "*_full_*" -o -name "*_${DB:-full}_*" | wc -l)
      find "$OUTPUT" -maxdepth 1 -mtime +${RETENTION} \( -name "*.tar.gz" -o -type d -name "*_full_*" -o -type d -name "*_${DB:-full}_*" \) -exec rm -rf {} + 2>/dev/null || true
      [[ "$DELETED" -gt 0 ]] && echo "🗑️ Cleaned up $DELETED old backups (>${RETENTION} days)"
    fi
    
    send_alert "✅ MongoDB backup complete: $BACKUP_NAME ($SIZE, ${ELAPSED}s)"
    
  else
    echo "❌ Backup failed!"
    send_alert "❌ MongoDB backup FAILED: $BACKUP_NAME"
    exit 1
  fi
}

do_restore() {
  [[ -z "$INPUT" ]] && { echo "❌ --input required for restore"; exit 1; }
  
  echo "🔄 Restoring from $INPUT..."
  local START=$(date +%s)
  
  # Check if it's a tar.gz
  local RESTORE_PATH="$INPUT"
  if [[ "$INPUT" == *.tar.gz ]]; then
    local TMPDIR=$(mktemp -d)
    tar -xzf "$INPUT" -C "$TMPDIR"
    RESTORE_PATH="$TMPDIR/$(ls $TMPDIR | head -1)"
  fi
  
  RESTORE_OPTS="$AUTH_OPTS $RESTORE_PATH"
  [[ -n "$DB" ]] && RESTORE_OPTS="$AUTH_OPTS --db=$DB --nsInclude=${DB}.* $RESTORE_PATH"
  
  # Check if gzipped dumps
  if find "$RESTORE_PATH" -name "*.gz" | head -1 | grep -q .; then
    RESTORE_OPTS="$RESTORE_OPTS --gzip"
  fi
  
  if mongorestore --drop $RESTORE_OPTS 2>/dev/null; then
    local END=$(date +%s)
    echo "✅ Restore complete (${$((END - START))}s)"
  else
    echo "❌ Restore failed!"
    exit 1
  fi
  
  # Cleanup temp
  [[ -n "${TMPDIR:-}" ]] && rm -rf "$TMPDIR"
}

case "$ACTION" in
  backup)  do_backup ;;
  restore) do_restore ;;
esac
