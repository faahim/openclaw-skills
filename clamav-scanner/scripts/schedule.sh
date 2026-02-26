#!/bin/bash
# ClamAV — Schedule recurring scans via cron
set -e

SCAN_PATH=""
INTERVAL=""
TIME=""
QUARANTINE=false
ALERT=""
EXCLUDE=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) SCAN_PATH="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --time) TIME="$2"; shift 2 ;;
        --quarantine) QUARANTINE=true; shift ;;
        --alert) ALERT="$2"; shift 2 ;;
        --exclude) EXCLUDE="$2"; shift 2 ;;
        --list) crontab -l 2>/dev/null | grep "clamav-scan" || echo "No scheduled scans"; exit 0 ;;
        --remove) crontab -l 2>/dev/null | grep -v "clamav-scan" | crontab - ; echo "✅ All scheduled scans removed"; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$SCAN_PATH" ]]; then
    echo "Usage: bash schedule.sh --path /directory --interval 6h [--quarantine] [--alert telegram]"
    echo "       bash schedule.sh --list"
    echo "       bash schedule.sh --remove"
    exit 1
fi

# Build scan command
SCAN_CMD="bash $SCRIPT_DIR/scan.sh --path $SCAN_PATH"
[[ "$QUARANTINE" == true ]] && SCAN_CMD="$SCAN_CMD --quarantine"
[[ -n "$ALERT" ]] && SCAN_CMD="$SCAN_CMD --alert $ALERT"
[[ -n "$EXCLUDE" ]] && SCAN_CMD="$SCAN_CMD --exclude $EXCLUDE"

# Convert interval to cron expression
CRON_EXPR=""
if [[ -n "$TIME" ]]; then
    HOUR=$(echo "$TIME" | cut -d: -f1)
    MINUTE=$(echo "$TIME" | cut -d: -f2)
    CRON_EXPR="$MINUTE $HOUR * * *"
elif [[ -n "$INTERVAL" ]]; then
    case "$INTERVAL" in
        1h)  CRON_EXPR="0 * * * *" ;;
        2h)  CRON_EXPR="0 */2 * * *" ;;
        3h)  CRON_EXPR="0 */3 * * *" ;;
        4h)  CRON_EXPR="0 */4 * * *" ;;
        6h)  CRON_EXPR="0 */6 * * *" ;;
        8h)  CRON_EXPR="0 */8 * * *" ;;
        12h) CRON_EXPR="0 */12 * * *" ;;
        24h) CRON_EXPR="0 3 * * *" ;;
        *)   echo "❌ Supported intervals: 1h, 2h, 3h, 4h, 6h, 8h, 12h, 24h"; exit 1 ;;
    esac
else
    CRON_EXPR="0 */6 * * *"  # Default: every 6 hours
fi

# Add to crontab
CRON_LINE="$CRON_EXPR $SCAN_CMD # clamav-scan:$SCAN_PATH"
(crontab -l 2>/dev/null | grep -v "clamav-scan:$SCAN_PATH"; echo "$CRON_LINE") | crontab -

echo "✅ Scheduled: $SCAN_PATH"
echo "   Cron: $CRON_EXPR"
echo "   Quarantine: $QUARANTINE"
echo "   Alerts: ${ALERT:-none}"
