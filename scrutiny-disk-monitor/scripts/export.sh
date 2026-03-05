#!/bin/bash
# Export S.M.A.R.T data from all drives
set -euo pipefail

FORMAT="${1:---format}"
FORMAT="${2:-json}"

case "$1" in
  --format) FORMAT="$2" ;;
  *) FORMAT="json" ;;
esac

case "$FORMAT" in
  json)
    echo "["
    FIRST=true
    for dev in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
      [ -b "$dev" ] || continue
      [ "$FIRST" = true ] && FIRST=false || echo ","
      MODEL=$(lsblk -d -n -o MODEL "$dev" 2>/dev/null | xargs || echo "Unknown")
      SIZE=$(lsblk -d -n -o SIZE "$dev" 2>/dev/null | xargs || echo "?")
      SMART=$(sudo smartctl -j -a "$dev" 2>/dev/null || echo '{}')
      echo "  {\"device\": \"$dev\", \"model\": \"$MODEL\", \"size\": \"$SIZE\", \"smart\": $SMART}"
    done
    echo ""
    echo "]"
    ;;
  csv)
    echo "device,model,size,health,temperature,power_on_hours"
    for dev in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
      [ -b "$dev" ] || continue
      MODEL=$(lsblk -d -n -o MODEL "$dev" 2>/dev/null | xargs || echo "Unknown")
      SIZE=$(lsblk -d -n -o SIZE "$dev" 2>/dev/null | xargs || echo "?")
      HEALTH=$(sudo smartctl -H "$dev" 2>/dev/null | grep -ioP "(passed|failed)" || echo "unknown")
      TEMP=$(sudo smartctl -A "$dev" 2>/dev/null | grep -i "temperature" | head -1 | awk '{print $(NF-1)}' || echo "")
      HOURS=$(sudo smartctl -A "$dev" 2>/dev/null | grep -i "power_on_hours" | head -1 | awk '{print $NF}' || echo "")
      echo "$dev,$MODEL,$SIZE,$HEALTH,$TEMP,$HOURS"
    done
    ;;
  *)
    echo "Unknown format: $FORMAT (use json or csv)"
    exit 1
    ;;
esac
