#!/bin/bash
# Install sysmon as a cron job
set -euo pipefail

INTERVAL=5
CPU_WARN=80
RAM_WARN=90
DISK_WARN=85
ALERT_METHOD="telegram"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval) INTERVAL="$2"; shift 2 ;;
    --cpu-warn) CPU_WARN="$2"; shift 2 ;;
    --ram-warn) RAM_WARN="$2"; shift 2 ;;
    --disk-warn) DISK_WARN="$2"; shift 2 ;;
    --alert) ALERT_METHOD="$2"; shift 2 ;;
    --remove)
      crontab -l 2>/dev/null | grep -v 'sysmon.sh' | crontab -
      echo "✅ Sysmon cron job removed"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

CRON_LINE="*/$INTERVAL * * * * bash $SCRIPT_DIR/sysmon.sh --cpu-warn $CPU_WARN --ram-warn $RAM_WARN --disk-warn $DISK_WARN --alert $ALERT_METHOD --quiet >> /tmp/sysmon.log 2>&1"

# Remove existing sysmon entry, add new one
(crontab -l 2>/dev/null | grep -v 'sysmon.sh'; echo "$CRON_LINE") | crontab -

echo "✅ Sysmon cron installed: every $INTERVAL minutes"
echo "   CPU warn: ${CPU_WARN}%, RAM warn: ${RAM_WARN}%, Disk warn: ${DISK_WARN}%"
echo "   Alert: $ALERT_METHOD"
echo "   Log: /tmp/sysmon.log"
echo ""
echo "To remove: bash $SCRIPT_DIR/install-cron.sh --remove"
