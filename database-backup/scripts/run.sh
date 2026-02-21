#!/usr/bin/env bash
# Database Backup — Automated backup for PostgreSQL, MySQL, MongoDB
# Usage: bash run.sh --env backup.env
#        bash run.sh --type postgres --host localhost --user myuser --database mydb --output /backups
set -euo pipefail

# ─── Defaults ───
DB_TYPE="${DB_TYPE:-}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-}"
DB_USER="${DB_USER:-}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
COMPRESS="${COMPRESS:-true}"
RETAIN_DAYS="${RETAIN_DAYS:-7}"
TIMESTAMP_FORMAT="${TIMESTAMP_FORMAT:-%Y-%m-%d_%H%M%S}"
UPLOAD_TYPE="${UPLOAD_TYPE:-}"
UPLOAD_BUCKET="${UPLOAD_BUCKET:-}"
UPLOAD_PREFIX="${UPLOAD_PREFIX:-}"
UPLOAD_REGION="${UPLOAD_REGION:-us-east-1}"
NOTIFY_ON_SUCCESS="${NOTIFY_ON_SUCCESS:-false}"
NOTIFY_ON_FAILURE="${NOTIFY_ON_FAILURE:-true}"
NOTIFY_WEBHOOK="${NOTIFY_WEBHOOK:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
EXTRA_DUMP_ARGS="${EXTRA_DUMP_ARGS:-}"
ALL_DATABASES=false
PRE_HOOK=""
POST_HOOK=""
ENCRYPT=false
GPG_RECIPIENT=""
INSTALL_CRON=""
ENV_FILE=""

# ─── Parse Args ───
while [[ $# -gt 0 ]]; do
  case $1 in
    --env) ENV_FILE="$2"; shift 2 ;;
    --type) DB_TYPE="$2"; shift 2 ;;
    --host) DB_HOST="$2"; shift 2 ;;
    --port) DB_PORT="$2"; shift 2 ;;
    --user) DB_USER="$2"; shift 2 ;;
    --password) DB_PASSWORD="$2"; shift 2 ;;
    --database) DB_NAME="$2"; shift 2 ;;
    --output) BACKUP_DIR="$2"; shift 2 ;;
    --upload) UPLOAD_TYPE="$2"; shift 2 ;;
    --bucket) UPLOAD_BUCKET="$2"; shift 2 ;;
    --prefix) UPLOAD_PREFIX="$2"; shift 2 ;;
    --retain) RETAIN_DAYS="$2"; shift 2 ;;
    --extra) EXTRA_DUMP_ARGS="$2"; shift 2 ;;
    --all-databases) ALL_DATABASES=true; shift ;;
    --pre-hook) PRE_HOOK="$2"; shift 2 ;;
    --post-hook) POST_HOOK="$2"; shift 2 ;;
    --encrypt) ENCRYPT=true; shift ;;
    --gpg-recipient) GPG_RECIPIENT="$2"; shift 2 ;;
    --install-cron) INSTALL_CRON="$2"; shift 2 ;;
    --no-compress) COMPRESS=false; shift ;;
    -h|--help) echo "Usage: bash run.sh --env backup.env (or --type postgres --host ... --database ...)"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Load env file if provided
if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
fi

# ─── Validate ───
if [[ -z "$DB_TYPE" ]]; then
  echo "❌ Error: --type required (postgres|mysql|mongo)"; exit 1
fi

# Set default ports
if [[ -z "$DB_PORT" ]]; then
  case "$DB_TYPE" in
    postgres) DB_PORT=5432 ;;
    mysql)    DB_PORT=3306 ;;
    mongo)    DB_PORT=27017 ;;
  esac
fi

# ─── Install Cron ───
if [[ -n "$INSTALL_CRON" ]]; then
  SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/run.sh"
  ENV_ABS=""
  [[ -n "$ENV_FILE" ]] && ENV_ABS="$(cd "$(dirname "$ENV_FILE")" && pwd)/$(basename "$ENV_FILE")"
  CRON_CMD="$INSTALL_CRON cd $(dirname "$SCRIPT_PATH") && bash $SCRIPT_PATH"
  [[ -n "$ENV_ABS" ]] && CRON_CMD="$CRON_CMD --env $ENV_ABS"
  CRON_CMD="$CRON_CMD >> /var/log/db-backup.log 2>&1"
  (crontab -l 2>/dev/null | grep -v "db-backup"; echo "$CRON_CMD") | crontab -
  echo "✅ Cron installed: $CRON_CMD"
  exit 0
fi

mkdir -p "$BACKUP_DIR"

# ─── Helpers ───
ts() { date -u "+%Y-%m-%d %H:%M:%S"; }
file_ts() { date -u "+$TIMESTAMP_FORMAT"; }
notify() {
  local msg="$1"
  if [[ -n "$NOTIFY_WEBHOOK" ]]; then
    curl -sf -X POST "$NOTIFY_WEBHOOK" -H "Content-Type: application/json" \
      -d "{\"text\":\"$msg\"}" >/dev/null 2>&1 || true
  fi
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -sf "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=${msg}" >/dev/null 2>&1 || true
  fi
}

# ─── Pre-Hook ───
[[ -n "$PRE_HOOK" ]] && eval "$PRE_HOOK"

START_TIME=$(date +%s)
echo "[$(ts)] 🔄 Starting backup: ${DB_NAME:-all} ($DB_TYPE)"

# ─── Dump ───
FNAME="${DB_NAME:-all}_$(file_ts)"
DUMP_FILE="$BACKUP_DIR/$FNAME"

case "$DB_TYPE" in
  postgres)
    export PGPASSWORD="$DB_PASSWORD"
    if [[ "$ALL_DATABASES" == "true" ]]; then
      pg_dumpall -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" $EXTRA_DUMP_ARGS > "${DUMP_FILE}.sql"
    else
      pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" $EXTRA_DUMP_ARGS > "${DUMP_FILE}.sql"
    fi
    DUMP_FILE="${DUMP_FILE}.sql"
    ;;
  mysql)
    if [[ "$ALL_DATABASES" == "true" ]]; then
      mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" --all-databases $EXTRA_DUMP_ARGS > "${DUMP_FILE}.sql"
    else
      mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" $EXTRA_DUMP_ARGS > "${DUMP_FILE}.sql"
    fi
    DUMP_FILE="${DUMP_FILE}.sql"
    ;;
  mongo)
    MONGO_ARGS="--host $DB_HOST --port $DB_PORT"
    [[ -n "$DB_USER" ]] && MONGO_ARGS="$MONGO_ARGS --username $DB_USER --password $DB_PASSWORD --authenticationDatabase admin"
    if [[ "$ALL_DATABASES" == "true" ]]; then
      mongodump $MONGO_ARGS --gzip --archive="${DUMP_FILE}.archive.gz" $EXTRA_DUMP_ARGS
      DUMP_FILE="${DUMP_FILE}.archive.gz"
      COMPRESS=false  # already gzipped
    else
      mongodump $MONGO_ARGS --db "$DB_NAME" --gzip --archive="${DUMP_FILE}.archive.gz" $EXTRA_DUMP_ARGS
      DUMP_FILE="${DUMP_FILE}.archive.gz"
      COMPRESS=false
    fi
    ;;
  *)
    echo "❌ Unsupported database type: $DB_TYPE (use postgres|mysql|mongo)"; exit 1
    ;;
esac

# ─── Compress ───
if [[ "$COMPRESS" == "true" && -f "$DUMP_FILE" ]]; then
  gzip -f "$DUMP_FILE"
  DUMP_FILE="${DUMP_FILE}.gz"
fi

FILE_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
echo "[$(ts)] ✅ Dumped: ${DB_NAME:-all} → $DUMP_FILE ($FILE_SIZE)"

# ─── Encrypt ───
if [[ "$ENCRYPT" == "true" ]]; then
  if [[ -n "$GPG_RECIPIENT" ]]; then
    gpg --encrypt --recipient "$GPG_RECIPIENT" --trust-model always "$DUMP_FILE"
    rm -f "$DUMP_FILE"
    DUMP_FILE="${DUMP_FILE}.gpg"
    echo "[$(ts)] 🔐 Encrypted: $DUMP_FILE"
  else
    echo "[$(ts)] ⚠️  --encrypt requires --gpg-recipient"
  fi
fi

# ─── Upload ───
UPLOAD_PATH="${UPLOAD_PREFIX}$(basename "$DUMP_FILE")"
case "$UPLOAD_TYPE" in
  s3)
    aws s3 cp "$DUMP_FILE" "s3://${UPLOAD_BUCKET}/${UPLOAD_PATH}" --region "$UPLOAD_REGION"
    echo "[$(ts)] ☁️  Uploaded to s3://${UPLOAD_BUCKET}/${UPLOAD_PATH}"
    ;;
  gcs)
    gsutil cp "$DUMP_FILE" "gs://${UPLOAD_BUCKET}/${UPLOAD_PATH}"
    echo "[$(ts)] ☁️  Uploaded to gs://${UPLOAD_BUCKET}/${UPLOAD_PATH}"
    ;;
  b2)
    b2 upload-file "$UPLOAD_BUCKET" "$DUMP_FILE" "$UPLOAD_PATH"
    echo "[$(ts)] ☁️  Uploaded to b2://${UPLOAD_BUCKET}/${UPLOAD_PATH}"
    ;;
  "") ;; # no upload
  *)
    echo "[$(ts)] ⚠️  Unknown upload type: $UPLOAD_TYPE (use s3|gcs|b2)"
    ;;
esac

# ─── Rotate ───
if [[ "$RETAIN_DAYS" -gt 0 ]]; then
  DELETED=$(find "$BACKUP_DIR" -name "${DB_NAME:-all}_*" -type f -mtime +"$RETAIN_DAYS" -delete -print | wc -l)
  if [[ "$DELETED" -gt 0 ]]; then
    echo "[$(ts)] 🗑️  Rotated: removed $DELETED backups older than ${RETAIN_DAYS} days"
  fi
fi

# ─── Summary ───
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "[$(ts)] ✅ Backup complete (${ELAPSED}s)"

# ─── Notify ───
if [[ "$NOTIFY_ON_SUCCESS" == "true" ]]; then
  notify "✅ DB Backup: ${DB_NAME:-all} ($DB_TYPE) — $FILE_SIZE in ${ELAPSED}s"
fi

# ─── Post-Hook ───
[[ -n "$POST_HOOK" ]] && eval "$POST_HOOK"
