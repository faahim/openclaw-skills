#!/bin/bash
# vnstat-traffic — Network traffic monitoring and alerting
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${HOME}/.config/vnstat-traffic"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
LOG_DIR="${CONFIG_DIR}/logs"
ALERT_STATE="${CONFIG_DIR}/alert-state.json"

mkdir -p "$CONFIG_DIR" "$LOG_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ─── Helpers ───

get_default_interface() {
  ip route | grep '^default' | awk '{print $5}' | head -1
}

bytes_to_human() {
  local bytes=$1
  if (( bytes >= 1099511627776 )); then
    echo "$(echo "scale=1; $bytes / 1099511627776" | bc) TiB"
  elif (( bytes >= 1073741824 )); then
    echo "$(echo "scale=1; $bytes / 1073741824" | bc) GiB"
  elif (( bytes >= 1048576 )); then
    echo "$(echo "scale=0; $bytes / 1048576" | bc) MiB"
  elif (( bytes >= 1024 )); then
    echo "$(echo "scale=0; $bytes / 1024" | bc) KiB"
  else
    echo "${bytes} B"
  fi
}

gib_to_bytes() {
  echo "$(echo "$1 * 1073741824" | bc | cut -d. -f1)"
}

# ─── Commands ───

cmd_status() {
  local iface="${1:-$(get_default_interface)}"
  local json
  json=$(vnstat -i "$iface" --json 2>/dev/null)

  if [ -z "$json" ] || ! echo "$json" | jq -e '.interfaces[0]' &>/dev/null; then
    echo "❌ No data for interface '$iface'. Run: bash scripts/install.sh"
    exit 1
  fi

  local today_rx today_tx month_rx month_tx total_rx total_tx
  today_rx=$(echo "$json" | jq '[.interfaces[0].traffic.day[-1].rx // 0] | add')
  today_tx=$(echo "$json" | jq '[.interfaces[0].traffic.day[-1].tx // 0] | add')
  month_rx=$(echo "$json" | jq '[.interfaces[0].traffic.month[-1].rx // 0] | add')
  month_tx=$(echo "$json" | jq '[.interfaces[0].traffic.month[-1].tx // 0] | add')
  total_rx=$(echo "$json" | jq '.interfaces[0].traffic.total.rx // 0')
  total_tx=$(echo "$json" | jq '.interfaces[0].traffic.total.tx // 0')

  local today_total=$((today_rx + today_tx))
  local month_total=$((month_rx + month_tx))
  local all_total=$((total_rx + total_tx))

  echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║  Network Traffic Monitor — vnstat                       ║${NC}"
  echo -e "${BOLD}╠══════════════════════════════════════════════════════════╣${NC}"
  printf "║  Interface: %-44s ║\n" "$iface"
  printf "║  Today:     ↓ %-10s ↑ %-10s = %-14s ║\n" "$(bytes_to_human $today_rx)" "$(bytes_to_human $today_tx)" "$(bytes_to_human $today_total)"
  printf "║  This Month: ↓ %-9s ↑ %-10s = %-14s ║\n" "$(bytes_to_human $month_rx)" "$(bytes_to_human $month_tx)" "$(bytes_to_human $month_total)"
  printf "║  All Time:  ↓ %-10s ↑ %-10s = %-14s ║\n" "$(bytes_to_human $total_rx)" "$(bytes_to_human $total_tx)" "$(bytes_to_human $all_total)"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
}

cmd_daily() {
  local iface="${1:-$(get_default_interface)}"
  local json
  json=$(vnstat -i "$iface" --json 2>/dev/null)

  echo -e "${BOLD}Daily Traffic Report — $(date +%Y-%m-%d)${NC}"
  echo "═══════════════════════════════════"
  echo "Interface: $iface"
  echo ""

  # Show hourly breakdown if available
  vnstat -i "$iface" -h 24 2>/dev/null || vnstat -i "$iface" -d 2>/dev/null

  echo ""

  # Today's total
  local today_rx today_tx
  today_rx=$(echo "$json" | jq '.interfaces[0].traffic.day[-1].rx // 0')
  today_tx=$(echo "$json" | jq '.interfaces[0].traffic.day[-1].tx // 0')
  local today_total=$((today_rx + today_tx))

  echo -e "─────────────────────────────────"
  echo -e "Total:  ↓ $(bytes_to_human $today_rx)  ↑ $(bytes_to_human $today_tx)  = ${BOLD}$(bytes_to_human $today_total)${NC}"
}

cmd_monthly() {
  local iface="${1:-$(get_default_interface)}"
  local json
  json=$(vnstat -i "$iface" --json 2>/dev/null)

  local month_name
  month_name=$(date +"%B %Y")

  echo -e "${BOLD}Monthly Traffic — ${month_name}${NC}"
  echo "═══════════════════════════════"

  # Show daily breakdown for this month
  vnstat -i "$iface" -d 30 2>/dev/null

  echo ""

  # Monthly total and projection
  local month_rx month_tx
  month_rx=$(echo "$json" | jq '.interfaces[0].traffic.month[-1].rx // 0')
  month_tx=$(echo "$json" | jq '.interfaces[0].traffic.month[-1].tx // 0')
  local month_total=$((month_rx + month_tx))
  local day_of_month
  day_of_month=$(date +%-d)
  local days_in_month
  days_in_month=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +%-d 2>/dev/null || echo 30)
  local projected=0
  if [ "$day_of_month" -gt 0 ]; then
    projected=$((month_total * days_in_month / day_of_month))
  fi

  echo -e "─────────────────────────────────"
  echo -e "Total:     ↓ $(bytes_to_human $month_rx)  ↑ $(bytes_to_human $month_tx)  = ${BOLD}$(bytes_to_human $month_total)${NC}"
  echo -e "Projected: ${YELLOW}$(bytes_to_human $projected) this month${NC}"
}

cmd_live() {
  local iface="${1:-$(get_default_interface)}"
  echo -e "${BOLD}Live Traffic — ${iface} [Ctrl+C to stop]${NC}"
  vnstat -i "$iface" -l
}

cmd_top() {
  echo -e "${BOLD}Interface Ranking (This Month)${NC}"
  echo "══════════════════════════════"

  local interfaces
  interfaces=$(vnstat --json | jq -r '.interfaces[].name' 2>/dev/null)

  local data=()
  for iface in $interfaces; do
    local total
    total=$(vnstat -i "$iface" --json | jq '.interfaces[0].traffic.month[-1] | (.rx // 0) + (.tx // 0)' 2>/dev/null || echo 0)
    data+=("$total $iface")
  done

  local grand_total=0
  for entry in "${data[@]}"; do
    grand_total=$((grand_total + $(echo "$entry" | awk '{print $1}')))
  done

  local rank=1
  printf '%s\n' "${data[@]}" | sort -rn | while read -r bytes iface; do
    local pct=0
    if [ "$grand_total" -gt 0 ]; then
      pct=$(echo "scale=1; $bytes * 100 / $grand_total" | bc)
    fi
    printf "%d. %-12s %10s  (%s%%)\n" "$rank" "$iface" "$(bytes_to_human $bytes)" "$pct"
    rank=$((rank + 1))
  done
}

cmd_export() {
  local iface="${1:-$(get_default_interface)}"
  local period="${2:-monthly}"

  case "$period" in
    daily)
      vnstat -i "$iface" --json | jq '{
        interface: .interfaces[0].name,
        period: (now | strftime("%Y-%m-%d")),
        rx_bytes: .interfaces[0].traffic.day[-1].rx,
        tx_bytes: .interfaces[0].traffic.day[-1].tx,
        total_bytes: (.interfaces[0].traffic.day[-1].rx + .interfaces[0].traffic.day[-1].tx)
      }'
      ;;
    monthly)
      vnstat -i "$iface" --json | jq '{
        interface: .interfaces[0].name,
        period: (now | strftime("%Y-%m")),
        rx_bytes: .interfaces[0].traffic.month[-1].rx,
        tx_bytes: .interfaces[0].traffic.month[-1].tx,
        total_bytes: (.interfaces[0].traffic.month[-1].rx + .interfaces[0].traffic.month[-1].tx),
        days: [.interfaces[0].traffic.day[] | {
          date: "\(.date.year)-\(.date.month | tostring | if length < 2 then "0" + . else . end)-\(.date.day | tostring | if length < 2 then "0" + . else . end)",
          rx: .rx,
          tx: .tx
        }]
      }'
      ;;
    *)
      echo "Usage: traffic.sh export [interface] [daily|monthly]"
      exit 1
      ;;
  esac
}

cmd_check_caps() {
  local iface="${1:-$(get_default_interface)}"
  local monthly_limit_gib="${2:-500}"

  local json
  json=$(vnstat -i "$iface" --json 2>/dev/null)
  local month_rx month_tx
  month_rx=$(echo "$json" | jq '.interfaces[0].traffic.month[-1].rx // 0')
  month_tx=$(echo "$json" | jq '.interfaces[0].traffic.month[-1].tx // 0')
  local month_total=$((month_rx + month_tx))
  local limit_bytes
  limit_bytes=$(gib_to_bytes "$monthly_limit_gib")

  local pct=0
  if [ "$limit_bytes" -gt 0 ]; then
    pct=$(echo "scale=1; $month_total * 100 / $limit_bytes" | bc)
  fi

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $iface: $(bytes_to_human $month_total) / ${monthly_limit_gib} GiB (${pct}%)"

  # Alert at 80% and 95%
  local pct_int
  pct_int=$(echo "$pct" | cut -d. -f1)

  if [ "${pct_int:-0}" -ge 95 ]; then
    send_alert "🚨 CRITICAL: ${iface} at ${pct}% of monthly data cap ($(bytes_to_human $month_total) / ${monthly_limit_gib} GiB)"
  elif [ "${pct_int:-0}" -ge 80 ]; then
    send_alert "⚠️ WARNING: ${iface} at ${pct}% of monthly data cap ($(bytes_to_human $month_total) / ${monthly_limit_gib} GiB)"
  fi
}

cmd_compare() {
  local iface="${1:-$(get_default_interface)}"
  echo -e "${BOLD}Monthly Comparison — ${iface}${NC}"
  echo "═══════════════════════════════"
  vnstat -i "$iface" -m 12 2>/dev/null
}

cmd_heatmap() {
  local iface="${1:-$(get_default_interface)}"
  local json
  json=$(vnstat -i "$iface" --json 2>/dev/null)

  echo -e "${BOLD}Daily Traffic Heatmap (last 30 days)${NC}"
  echo "Each █ = 5 GiB"
  echo ""

  echo "$json" | jq -r '.interfaces[0].traffic.day[-30:][] |
    "\(.date.year)-\(.date.month | tostring | if length < 2 then "0" + . else . end)-\(.date.day | tostring | if length < 2 then "0" + . else . end) \(.rx + .tx)"' | \
  while read -r date bytes; do
    local gib
    gib=$(echo "scale=1; $bytes / 1073741824" | bc)
    local blocks
    blocks=$(echo "$bytes / 5368709120" | bc)
    local bar=""
    for ((i=0; i<blocks && i<20; i++)); do
      bar="${bar}█"
    done
    local remaining=$((20 - ${#bar}))
    for ((i=0; i<remaining; i++)); do
      bar="${bar}░"
    done
    printf "%s %s %s GiB\n" "$date" "$bar" "$gib"
  done
}

cmd_setup_cron() {
  local script_path
  script_path="$(cd "$SCRIPT_DIR" && pwd)/traffic.sh"
  local cron_entry="0 * * * * bash $script_path check-caps >> $LOG_DIR/caps.log 2>&1"

  if crontab -l 2>/dev/null | grep -qF "vnstat-traffic"; then
    echo "⚠️  Cron job already exists"
    crontab -l | grep "vnstat-traffic"
  else
    (crontab -l 2>/dev/null; echo "# vnstat-traffic cap checker"; echo "$cron_entry") | crontab -
    echo "✅ Cron job added (hourly cap check)"
    echo "   Logs: $LOG_DIR/caps.log"
  fi
}

cmd_reset() {
  local iface="${1:-}"
  if [ -z "$iface" ]; then
    echo "Usage: traffic.sh reset <interface|--all>"
    exit 1
  fi

  if [ "$iface" = "--all" ]; then
    sudo vnstat --remove --force -i "$(get_default_interface)" 2>/dev/null
    echo "✅ All stats reset. Re-run install.sh to reinitialize."
  else
    sudo vnstat --remove --force -i "$iface" 2>/dev/null
    sudo vnstat --add -i "$iface" 2>/dev/null
    echo "✅ Stats reset for $iface"
  fi
}

# ─── Alerting ───

send_alert() {
  local message="$1"

  # Deduplicate: don't send same alert within 4 hours
  local alert_hash
  alert_hash=$(echo "$message" | md5sum | cut -d' ' -f1)
  if [ -f "$ALERT_STATE" ]; then
    local last_sent
    last_sent=$(jq -r ".[\"$alert_hash\"] // 0" "$ALERT_STATE" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    if [ $((now - last_sent)) -lt 14400 ]; then
      return 0  # Skip, sent recently
    fi
  fi

  # Send via Telegram if configured
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=${message}" \
      -d "parse_mode=HTML" >/dev/null 2>&1
    echo "  📨 Alert sent to Telegram"
  fi

  # Update state
  local now
  now=$(date +%s)
  if [ -f "$ALERT_STATE" ]; then
    jq ".[\"$alert_hash\"] = $now" "$ALERT_STATE" > "${ALERT_STATE}.tmp" && mv "${ALERT_STATE}.tmp" "$ALERT_STATE"
  else
    echo "{\"$alert_hash\": $now}" > "$ALERT_STATE"
  fi
}

# ─── Main ───

case "${1:-help}" in
  status)     cmd_status "${2:-}" ;;
  daily)      cmd_daily "${2:-}" ;;
  monthly)    cmd_monthly "${2:-}" ;;
  live)       cmd_live "${2:-}" ;;
  top)        cmd_top ;;
  export)     cmd_export "${2:-}" "${3:-monthly}" ;;
  check-caps) cmd_check_caps "${2:-}" "${3:-500}" ;;
  compare)    cmd_compare "${2:-}" ;;
  heatmap)    cmd_heatmap "${2:-}" ;;
  setup-cron) cmd_setup_cron ;;
  reset)      cmd_reset "${2:-}" ;;
  alert)
    # Parse --interface, --monthly-limit, etc.
    iface="$(get_default_interface)"
    limit=500
    shift
    while [[ $# -gt 0 ]]; do
      case $1 in
        --interface) iface="$2"; shift 2 ;;
        --monthly-limit) limit="$2"; shift 2 ;;
        --daily-limit) shift 2 ;;  # TODO
        --unit) shift 2 ;;
        --notify) shift 2 ;;
        *) shift ;;
      esac
    done
    cmd_check_caps "$iface" "$limit"
    ;;
  help|--help|-h)
    echo "Network Traffic Monitor (vnstat)"
    echo ""
    echo "Usage: bash traffic.sh <command> [interface]"
    echo ""
    echo "Commands:"
    echo "  status [iface]         Show current usage summary"
    echo "  daily [iface]          Today's traffic breakdown"
    echo "  monthly [iface]        This month's usage + projection"
    echo "  live [iface]           Real-time traffic rates"
    echo "  top                    Rank interfaces by usage"
    echo "  export [iface] [period] Export as JSON (daily|monthly)"
    echo "  check-caps [iface] [gib] Check against data cap"
    echo "  compare [iface]        Compare monthly usage"
    echo "  heatmap [iface]        30-day traffic heatmap"
    echo "  setup-cron             Install hourly cap checker"
    echo "  reset <iface|--all>    Reset traffic stats"
    echo "  alert --interface <i> --monthly-limit <n>  Set alert"
    echo ""
    echo "Default interface: $(get_default_interface)"
    ;;
  *)
    echo "Unknown command: $1"
    echo "Run: bash traffic.sh help"
    exit 1
    ;;
esac
