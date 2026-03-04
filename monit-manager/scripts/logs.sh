#!/bin/bash
# View Monit logs
LINES=50
FOLLOW=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --tail) LINES="$2"; shift 2 ;;
    --follow|-f) FOLLOW=true; shift ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

LOG="/var/log/monit.log"
[ ! -f "$LOG" ] && LOG="/var/log/monit"

if [ ! -f "$LOG" ]; then
  echo "❌ Log file not found. Check: journalctl -u monit"
  journalctl -u monit --no-pager -n "$LINES" 2>/dev/null || echo "No journal entries found."
  exit 0
fi

if $FOLLOW; then
  sudo tail -f "$LOG"
else
  sudo tail -n "$LINES" "$LOG"
fi
