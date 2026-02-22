#!/bin/bash
# Cloud Sync & Backup — Schedule automated backups via cron
set -euo pipefail

SOURCE=""
REMOTE=""
CRON_EXPR="0 2 * * *"
COMPRESS=false
ENCRYPT=false
RETENTION=""
EXTRA_ARGS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --source)     SOURCE="$2"; shift 2 ;;
    --remote)     REMOTE="$2"; shift 2 ;;
    --cron)       CRON_EXPR="$2"; shift 2 ;;
    --compress)   COMPRESS=true; shift ;;
    --encrypt)    ENCRYPT=true; shift ;;
    --retention)  RETENTION="$2"; shift 2 ;;
    *)            echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$SOURCE" || -z "$REMOTE" ]]; then
  echo "Usage: schedule.sh --source <path> --remote <remote:path> [--cron '<expr>'] [--compress] [--encrypt] [--retention <days>]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_CMD="bash ${SCRIPT_DIR}/backup.sh --source ${SOURCE} --remote ${REMOTE}"

[[ "$COMPRESS" == true ]] && BACKUP_CMD+=" --compress"
[[ "$ENCRYPT" == true ]] && BACKUP_CMD+=" --encrypt"
BACKUP_CMD+=" --log /var/log/cloud-backup.log"

# Add retention-based prune after backup
if [[ -n "$RETENTION" ]]; then
  BACKUP_CMD+=" && bash ${SCRIPT_DIR}/manage.sh prune --remote ${REMOTE} --retention ${RETENTION} </dev/null"
fi

# Check if already scheduled
EXISTING=$(crontab -l 2>/dev/null | grep -F "cloud-sync-backup:${SOURCE}" || true)
if [[ -n "$EXISTING" ]]; then
  echo "⚠️  Existing schedule found for $SOURCE:"
  echo "   $EXISTING"
  read -p "Replace? [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
  fi
  # Remove old entry
  crontab -l 2>/dev/null | grep -v "cloud-sync-backup:${SOURCE}" | crontab -
fi

# Add cron job
CRON_LINE="${CRON_EXPR} ${BACKUP_CMD} # cloud-sync-backup:${SOURCE}"
(crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -

echo "✅ Backup scheduled!"
echo ""
echo "  Schedule: $CRON_EXPR"
echo "  Source:   $SOURCE"
echo "  Remote:   $REMOTE"
echo "  Compress: $COMPRESS"
echo "  Encrypt:  $ENCRYPT"
[[ -n "$RETENTION" ]] && echo "  Retention: ${RETENTION} days"
echo "  Log:      /var/log/cloud-backup.log"
echo ""
echo "Verify: crontab -l | grep cloud-sync-backup"
echo "Remove: crontab -l | grep -v 'cloud-sync-backup:${SOURCE}' | crontab -"
