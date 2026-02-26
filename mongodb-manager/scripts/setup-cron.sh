#!/bin/bash
# Set up scheduled MongoDB backups via cron
set -euo pipefail

SCHEDULE=""
DB=""
COMPRESS=false
S3_PATH=""
RETENTION=30
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
  case $1 in
    --schedule) SCHEDULE="$2"; shift 2 ;;
    --db) DB="$2"; shift 2 ;;
    --compress) COMPRESS=true; shift ;;
    --s3) S3_PATH="$2"; shift 2 ;;
    --retention) RETENTION="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[[ -z "$SCHEDULE" ]] && { echo "❌ --schedule required (cron expression, e.g. '0 2 * * *')"; exit 1; }

# Build backup command
CMD="$SCRIPT_DIR/backup.sh"
[[ -n "$DB" ]] && CMD="$CMD --db $DB"
[[ "$COMPRESS" == true ]] && CMD="$CMD --compress"
[[ -n "$S3_PATH" ]] && CMD="$CMD --s3 $S3_PATH"
[[ "$RETENTION" -gt 0 ]] && CMD="$CMD --retention $RETENTION"

LOG_FILE="/var/log/mongo-backup.log"
CRON_LINE="$SCHEDULE $CMD >> $LOG_FILE 2>&1"

# Add to crontab (avoid duplicates)
(crontab -l 2>/dev/null | grep -v "backup.sh.*mongo" || true; echo "$CRON_LINE") | crontab -

echo "✅ Cron job added:"
echo "   Schedule: $SCHEDULE"
echo "   Command: $CMD"
echo "   Log: $LOG_FILE"
echo ""
echo "   Verify with: crontab -l"
