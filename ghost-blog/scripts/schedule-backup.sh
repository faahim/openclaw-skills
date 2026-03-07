#!/bin/bash
# Schedule automatic Ghost backups via cron
set -euo pipefail

INTERVAL="${1:-daily}"
KEEP="${2:-7}"
NAME="${GHOST_DEPLOY_NAME:-ghost}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$INTERVAL" in
    daily)   CRON="0 3 * * *" ;;
    weekly)  CRON="0 3 * * 0" ;;
    monthly) CRON="0 3 1 * *" ;;
    *) echo "Usage: $0 [daily|weekly|monthly] [keep-count]"; exit 1 ;;
esac

CRON_LINE="$CRON bash $SCRIPT_DIR/backup.sh $NAME && find $HOME/ghost-deployments/$NAME/backups -name '*.tar.gz' -mtime +$KEEP -delete"

(crontab -l 2>/dev/null | grep -v "ghost.*backup"; echo "$CRON_LINE") | crontab -
echo "[ghost-blog] Scheduled $INTERVAL backups (keeping last $KEEP). Cron: $CRON"
