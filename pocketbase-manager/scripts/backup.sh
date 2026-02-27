#!/bin/bash
# PocketBase Backup & Restore
set -euo pipefail

DATA_BASE="/opt/pocketbase"
NAME=""
DEST=""
S3=""
SCHEDULE=""
RESTORE=""
LIST=false

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --name NAME      Instance name (required)
  --dest PATH      Local backup destination
  --s3 URI         S3 backup destination (s3://bucket/prefix)
  --schedule FREQ  Install backup cron (daily|hourly|weekly)
  --restore PATH   Restore from backup file (local path or s3:// URI)
  --list           List available backups
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --dest) DEST="$2"; shift 2 ;;
    --s3) S3="$2"; shift 2 ;;
    --schedule) SCHEDULE="$2"; shift 2 ;;
    --restore) RESTORE="$2"; shift 2 ;;
    --list) LIST=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$NAME" ]] && { echo "❌ --name is required"; usage; }

INSTANCE_DIR="${DATA_BASE}/${NAME}"
[[ -d "$INSTANCE_DIR" ]] || { echo "❌ Instance '$NAME' not found at $INSTANCE_DIR"; exit 1; }

do_backup() {
  local timestamp
  timestamp=$(date +%Y-%m-%dT%H-%M-%S)
  local backup_name="pocketbase-${NAME}-${timestamp}.zip"

  echo "📦 Backing up '$NAME'..."

  # Create backup
  local tmp_backup="/tmp/${backup_name}"
  cd "$INSTANCE_DIR"
  zip -qr "$tmp_backup" pb_data/ pb_migrations/ config.yaml 2>/dev/null

  local size
  size=$(du -sh "$tmp_backup" | cut -f1)

  # Copy to destination(s)
  if [[ -n "$DEST" ]]; then
    mkdir -p "$DEST"
    cp "$tmp_backup" "$DEST/${backup_name}"
    echo "✅ Local backup: ${DEST}/${backup_name} (${size})"

    # Clean old backups (keep last 30)
    local count
    count=$(ls -1 "$DEST"/pocketbase-${NAME}-*.zip 2>/dev/null | wc -l)
    if [[ $count -gt 30 ]]; then
      ls -1t "$DEST"/pocketbase-${NAME}-*.zip | tail -n +31 | xargs rm -f
      echo "🧹 Cleaned old backups (kept last 30)"
    fi
  fi

  if [[ -n "$S3" ]]; then
    if ! command -v aws &>/dev/null; then
      echo "❌ aws CLI not found. Install: pip install awscli"
      exit 1
    fi
    aws s3 cp "$tmp_backup" "${S3}/${backup_name}" --quiet
    echo "✅ S3 backup: ${S3}/${backup_name} (${size})"
  fi

  rm -f "$tmp_backup"
}

do_list() {
  echo "Available backups for '$NAME':"
  echo ""

  if [[ -n "$DEST" ]]; then
    echo "📁 Local ($DEST):"
    ls -lh "$DEST"/pocketbase-${NAME}-*.zip 2>/dev/null | awk '{print "  " $NF " (" $5 ")"}' || echo "  (none)"
  fi

  if [[ -n "$S3" ]]; then
    echo ""
    echo "☁️  S3 ($S3):"
    aws s3 ls "${S3}/" 2>/dev/null | grep "pocketbase-${NAME}" | awk '{print "  " $4 " (" $3 ")"}' || echo "  (none)"
  fi
}

do_restore() {
  local backup_file="$RESTORE"
  local service="pocketbase-${NAME}"

  echo "⚠️  Restoring '$NAME' from: $backup_file"
  echo "   This will REPLACE all current data!"
  read -p "   Continue? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

  # Download from S3 if needed
  if [[ "$backup_file" == s3://* ]]; then
    local tmp="/tmp/pocketbase-restore-${NAME}.zip"
    echo "⬇️  Downloading from S3..."
    aws s3 cp "$backup_file" "$tmp" --quiet
    backup_file="$tmp"
  fi

  # Stop service
  if systemctl is-active --quiet "$service" 2>/dev/null; then
    echo "⏹️  Stopping service..."
    sudo systemctl stop "$service"
  fi

  # Backup current state
  echo "📦 Backing up current state (just in case)..."
  local safety="/tmp/pocketbase-${NAME}-pre-restore-$(date +%Y%m%d%H%M%S).zip"
  cd "$INSTANCE_DIR" && zip -qr "$safety" pb_data/ 2>/dev/null || true

  # Restore
  echo "📂 Restoring data..."
  rm -rf "$INSTANCE_DIR/pb_data"
  unzip -qo "$backup_file" -d "$INSTANCE_DIR"

  # Restart service
  if systemctl is-enabled --quiet "$service" 2>/dev/null; then
    echo "▶️  Restarting service..."
    sudo systemctl start "$service"
    sleep 2
    if systemctl is-active --quiet "$service"; then
      echo "✅ Restore complete. Service is running."
    else
      echo "❌ Service failed to start. Check logs."
      echo "   Safety backup: $safety"
    fi
  else
    echo "✅ Data restored. Start manually."
  fi
}

do_schedule() {
  local cron_expr
  case "$SCHEDULE" in
    daily) cron_expr="0 2 * * *" ;;
    hourly) cron_expr="0 * * * *" ;;
    weekly) cron_expr="0 2 * * 0" ;;
    *) echo "❌ Invalid schedule: $SCHEDULE (use daily|hourly|weekly)"; exit 1 ;;
  esac

  local script_path
  script_path="$(cd "$(dirname "$0")" && pwd)/backup.sh"
  local cron_cmd="${cron_expr} ${script_path} --name ${NAME}"
  [[ -n "$DEST" ]] && cron_cmd+=" --dest ${DEST}"
  [[ -n "$S3" ]] && cron_cmd+=" --s3 ${S3}"

  # Add to crontab
  (crontab -l 2>/dev/null | grep -v "pocketbase.*${NAME}"; echo "$cron_cmd") | crontab -
  echo "✅ Backup scheduled: $SCHEDULE"
  echo "   Cron: $cron_expr"
}

if [[ "$LIST" == "true" ]]; then
  do_list
elif [[ -n "$RESTORE" ]]; then
  do_restore
elif [[ -n "$SCHEDULE" ]]; then
  do_schedule
else
  do_backup
fi
