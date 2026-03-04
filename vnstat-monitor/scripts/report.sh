#!/bin/bash
# vnstat-monitor: Generate bandwidth reports
set -euo pipefail

# Defaults
PERIOD="monthly"
FORMAT="table"
INTERFACE=""
ALL_IFACES=false
TOP_N=0
LIVE=false
DBINFO=false
COMPARE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --period|-p) PERIOD="$2"; shift 2 ;;
    --format|-f) FORMAT="$2"; shift 2 ;;
    --interface|-i) INTERFACE="$2"; shift 2 ;;
    --all) ALL_IFACES=true; shift ;;
    --top) TOP_N="$2"; shift 2 ;;
    --live) LIVE=true; shift ;;
    --dbinfo) DBINFO=true; shift ;;
    --compare) COMPARE=true; shift ;;
    --help) echo "Usage: report.sh [--period daily|monthly|yearly] [--format table|json|csv] [--interface eth0] [--all] [--top N] [--live] [--compare]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

command -v vnstat &>/dev/null || { echo "❌ vnstat not installed. Run: bash scripts/install.sh"; exit 1; }

# Auto-detect interface if not specified
if [ -z "$INTERFACE" ] && ! $ALL_IFACES && ! $COMPARE; then
  INTERFACE=$(vnstat --iflist 2>/dev/null | grep -oP '(?:eth|ens|enp|wlan|wlp)\S+' | head -1)
  [ -z "$INTERFACE" ] && INTERFACE=$(vnstat --iflist 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i!="Available" && $i!="interfaces:" && $i!="lo") {print $i; exit}}')
fi

get_interfaces() {
  vnstat --iflist 2>/dev/null | grep -oP '(?:eth|ens|enp|wlan|wlp|wg|tun|veth)\S+' || echo "eth0"
}

human_bytes() {
  local bytes=$1
  if [ "$bytes" -ge 1073741824 ]; then
    echo "$(echo "scale=2; $bytes / 1073741824" | bc) GiB"
  elif [ "$bytes" -ge 1048576 ]; then
    echo "$(echo "scale=2; $bytes / 1048576" | bc) MiB"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$(echo "scale=2; $bytes / 1024" | bc) KiB"
  else
    echo "$bytes B"
  fi
}

# Live monitoring
if $LIVE; then
  echo "📡 Live bandwidth monitor on ${INTERFACE:-all interfaces} (Ctrl+C to stop)"
  vnstat -l ${INTERFACE:+-i "$INTERFACE"}
  exit 0
fi

# Database info
if $DBINFO; then
  vnstat --dbiflist
  echo "---"
  vnstat ${INTERFACE:+-i "$INTERFACE"} --dbinfo 2>/dev/null || vnstat ${INTERFACE:+-i "$INTERFACE"}
  exit 0
fi

# Top N days
if [ "$TOP_N" -gt 0 ]; then
  echo "📊 Top $TOP_N traffic days${INTERFACE:+ on $INTERFACE}:"
  echo ""
  vnstat ${INTERFACE:+-i "$INTERFACE"} -t "$TOP_N" 2>/dev/null || vnstat ${INTERFACE:+-i "$INTERFACE"} --top "$TOP_N"
  exit 0
fi

# Interface comparison
if $COMPARE; then
  echo "📊 Interface Comparison — $(date +%B\ %Y)"
  echo "──────────────────────────────────"
  
  MAX_TOTAL=0
  declare -A IFACE_TOTALS
  
  for iface in $(get_interfaces); do
    TOTAL=$(vnstat -i "$iface" --json m 2>/dev/null | jq -r '.interfaces[0].traffic.month[-1].total // 0' 2>/dev/null || echo "0")
    IFACE_TOTALS[$iface]=$TOTAL
    [ "$TOTAL" -gt "$MAX_TOTAL" ] && MAX_TOTAL=$TOTAL
  done
  
  GRAND=0
  for iface in "${!IFACE_TOTALS[@]}"; do
    TOTAL=${IFACE_TOTALS[$iface]}
    GRAND=$((GRAND + TOTAL))
    if [ "$MAX_TOTAL" -gt 0 ]; then
      BAR_LEN=$((TOTAL * 30 / MAX_TOTAL))
    else
      BAR_LEN=0
    fi
    BAR=$(printf '█%.0s' $(seq 1 $BAR_LEN 2>/dev/null) 2>/dev/null || echo "")
    printf "%-8s %s %s\n" "$iface:" "$BAR" "$(human_bytes $TOTAL)"
  done
  
  echo "──────────────────────────────────"
  echo "Total: $(human_bytes $GRAND)"
  exit 0
fi

# JSON output
if [ "$FORMAT" = "json" ]; then
  case "$PERIOD" in
    daily|d) vnstat ${INTERFACE:+-i "$INTERFACE"} --json d 2>/dev/null || vnstat ${INTERFACE:+-i "$INTERFACE"} --json ;;
    monthly|m) vnstat ${INTERFACE:+-i "$INTERFACE"} --json m 2>/dev/null || vnstat ${INTERFACE:+-i "$INTERFACE"} --json ;;
    yearly|y) vnstat ${INTERFACE:+-i "$INTERFACE"} --json y 2>/dev/null || vnstat ${INTERFACE:+-i "$INTERFACE"} --json ;;
    *) vnstat ${INTERFACE:+-i "$INTERFACE"} --json ;;
  esac
  exit 0
fi

# CSV output
if [ "$FORMAT" = "csv" ]; then
  echo "date,interface,rx_bytes,tx_bytes,total_bytes"
  vnstat ${INTERFACE:+-i "$INTERFACE"} --json d 2>/dev/null | jq -r --arg iface "${INTERFACE:-eth0}" '
    .interfaces[0].traffic.day[] |
    "\(.date.year)-\(.date.month | tostring | if length == 1 then "0" + . else . end)-\(.date.day | tostring | if length == 1 then "0" + . else . end),\($iface),\(.rx),\(.tx),\(.rx + .tx)"
  ' 2>/dev/null || echo "CSV export requires vnstat 2.6+ with JSON support"
  exit 0
fi

# Table output (default)
if $ALL_IFACES; then
  for iface in $(get_interfaces); do
    echo "═══════════════════════════════════════"
    echo "  Interface: $iface"
    echo "═══════════════════════════════════════"
    case "$PERIOD" in
      daily|d) vnstat -i "$iface" -d ;;
      monthly|m) vnstat -i "$iface" -m ;;
      yearly|y) vnstat -i "$iface" -y 2>/dev/null || vnstat -i "$iface" ;;
      *) vnstat -i "$iface" -m ;;
    esac
    echo ""
  done
else
  case "$PERIOD" in
    daily|d) vnstat ${INTERFACE:+-i "$INTERFACE"} -d ;;
    monthly|m) vnstat ${INTERFACE:+-i "$INTERFACE"} -m ;;
    yearly|y) vnstat ${INTERFACE:+-i "$INTERFACE"} -y 2>/dev/null || vnstat ${INTERFACE:+-i "$INTERFACE"} ;;
    hourly|h) vnstat ${INTERFACE:+-i "$INTERFACE"} -h ;;
    *) vnstat ${INTERFACE:+-i "$INTERFACE"} -m ;;
  esac
fi

# Show projection for monthly
if [ "$PERIOD" = "monthly" ] || [ "$PERIOD" = "m" ]; then
  echo ""
  DAY_OF_MONTH=$(date +%-d)
  DAYS_IN_MONTH=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +%-d 2>/dev/null || echo 30)
  
  MONTH_TOTAL=$(vnstat ${INTERFACE:+-i "$INTERFACE"} --json m 2>/dev/null | jq -r '.interfaces[0].traffic.month[-1].total // 0' 2>/dev/null || echo "0")
  
  if [ "$MONTH_TOTAL" -gt 0 ] && [ "$DAY_OF_MONTH" -gt 0 ]; then
    PROJECTED=$(echo "scale=0; $MONTH_TOTAL * $DAYS_IN_MONTH / $DAY_OF_MONTH" | bc 2>/dev/null || echo "0")
    if [ "$PROJECTED" -gt 0 ]; then
      echo "📈 Projected end-of-month: $(human_bytes $PROJECTED)"
    fi
  fi
fi
