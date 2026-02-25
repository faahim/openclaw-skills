#!/bin/bash
# MySQL/MariaDB Backup Script
set -euo pipefail

MYSQLDUMP_CMD="mysqldump"
MYSQL_CMD="mysql"
MYSQL_ARGS=""
[[ -n "${MYSQL_HOST:-}" ]] && MYSQL_ARGS+=" -h $MYSQL_HOST"
[[ -n "${MYSQL_PORT:-}" ]] && MYSQL_ARGS+=" -P $MYSQL_PORT"
[[ -n "${MYSQL_USER:-}" ]] && MYSQL_ARGS+=" -u $MYSQL_USER"
[[ -n "${MYSQL_PASSWORD:-}" ]] && MYSQL_ARGS+=" -p$MYSQL_PASSWORD"

BACKUP_DIR="${BACKUP_DIR:-/var/backups/mysql}"
RETAIN_DAYS="${BACKUP_RETAIN_DAYS:-7}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1" >&2; exit 1; }
run_sql() { $MYSQL_CMD $MYSQL_ARGS -N -e "$1" 2>/dev/null; }

backup_db() {
  local db="$1"
  local dir="$2"
  local compress="${3:-false}"
  local single_tx="${4:-false}"

  mkdir -p "$dir"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local filename="${db}_${timestamp}.sql"
  local dump_args="$MYSQL_ARGS --single-transaction --routines --triggers --events"

  if [[ "$single_tx" == "true" ]]; then
    dump_args+=" --single-transaction"
  fi

  log "Backing up '$db'..."

  if [[ "$compress" == "true" ]]; then
    $MYSQLDUMP_CMD $dump_args "$db" 2>/dev/null | gzip > "$dir/${filename}.gz"
    local size=$(du -h "$dir/${filename}.gz" | cut -f1)
    log "✅ $db → ${filename}.gz ($size)"
  else
    $MYSQLDUMP_CMD $dump_args "$db" 2>/dev/null > "$dir/$filename"
    local size=$(du -h "$dir/$filename" | cut -f1)
    log "✅ $db → $filename ($size)"
  fi
}

backup_all() {
  local dir="$1"
  local compress="${2:-false}"

  local databases=$(run_sql "SHOW DATABASES;" | grep -Ev '^(information_schema|performance_schema|sys|mysql)$')

  local count=0
  for db in $databases; do
    backup_db "$db" "$dir" "$compress"
    count=$((count + 1))
  done

  log "🎉 Backed up $count databases to $dir"
}

cleanup_old() {
  local dir="$1"
  local days="$2"

  local deleted=$(find "$dir" -name "*.sql" -o -name "*.sql.gz" | xargs -I{} find {} -mtime +$days -delete -print 2>/dev/null | wc -l)
  log "🧹 Cleaned up $deleted backups older than $days days"
}

setup_cron() {
  local time="$1"
  local dir="$2"
  local retain="$3"
  local script_path=$(readlink -f "$0")

  local cron_cmd="$time bash $script_path --all --compress --dir $dir --retain $retain --cleanup"

  # Check if already exists
  if crontab -l 2>/dev/null | grep -q "$script_path"; then
    log "⚠️  Cron job already exists. Updating..."
    crontab -l 2>/dev/null | grep -v "$script_path" | { cat; echo "$cron_cmd"; } | crontab -
  else
    (crontab -l 2>/dev/null; echo "$cron_cmd") | crontab -
  fi

  log "✅ Cron scheduled: $time"
  log "   Dir: $dir | Retain: $retain days"
}

# Parse arguments
ALL=false
DB=""
COMPRESS=false
DIR="$BACKUP_DIR"
RETAIN="$RETAIN_DAYS"
SCHEDULE=false
CRON_TIME="0 2 * * *"
CLEANUP=false
SINGLE_TX=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --all)                ALL=true; shift ;;
    --db)                 DB="$2"; shift 2 ;;
    --compress)           COMPRESS=true; shift ;;
    --dir)                DIR="$2"; shift 2 ;;
    --retain)             RETAIN="$2"; shift 2 ;;
    --schedule)           SCHEDULE=true; shift ;;
    --time)               CRON_TIME="$2"; shift 2 ;;
    --cleanup)            CLEANUP=true; shift ;;
    --single-transaction) SINGLE_TX=true; shift ;;
    *)                    shift ;;
  esac
done

if [[ "$SCHEDULE" == "true" ]]; then
  setup_cron "$CRON_TIME" "$DIR" "$RETAIN"
  exit 0
fi

if [[ "$ALL" == "true" ]]; then
  backup_all "$DIR" "$COMPRESS"
elif [[ -n "$DB" ]]; then
  backup_db "$DB" "$DIR" "$COMPRESS" "$SINGLE_TX"
else
  echo "MySQL Backup Tool"
  echo ""
  echo "Usage:"
  echo "  bash backup.sh --all --compress --dir /backups"
  echo "  bash backup.sh --db mydb --compress --dir /backups"
  echo "  bash backup.sh --schedule --time '0 2 * * *' --retain 7 --dir /backups"
  echo ""
  echo "Options:"
  echo "  --all                   Backup all databases"
  echo "  --db <name>             Backup specific database"
  echo "  --compress              Gzip compress output"
  echo "  --dir <path>            Backup directory (default: /var/backups/mysql)"
  echo "  --retain <days>         Days to keep backups (default: 7)"
  echo "  --single-transaction    Consistent InnoDB backup without locking"
  echo "  --schedule              Set up as cron job"
  echo "  --time '<cron>'         Cron schedule (default: '0 2 * * *')"
  exit 0
fi

if [[ "$CLEANUP" == "true" ]]; then
  cleanup_old "$DIR" "$RETAIN"
fi
