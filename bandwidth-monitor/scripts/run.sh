#!/bin/bash
# Bandwidth Monitor — Main Script
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${BW_CONFIG_DIR:-$HOME/.config/bandwidth-monitor}"
CONFIG_FILE="${BW_CONFIG:-$CONFIG_DIR/config.yaml}"

# Defaults
IFACE="${BW_INTERFACE:-}"
POLL_INTERVAL=5
DAILY_THRESHOLD=""
WEEKLY_THRESHOLD=""
MONTHLY_THRESHOLD=""
RATE_THRESHOLD=""
OUTPUT_FORMAT="table"

# Load config if exists (simple YAML parser)
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        IFACE="${IFACE:-$(grep '^interface:' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')}"
        POLL_INTERVAL=$(grep '^poll_interval:' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}' || echo 5)
        DAILY_THRESHOLD=$(grep 'daily:' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
        WEEKLY_THRESHOLD=$(grep 'weekly:' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
        MONTHLY_THRESHOLD=$(grep 'monthly:' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
        RATE_THRESHOLD=$(grep 'rate:' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
    fi
}

# Auto-detect interface if not set
detect_interface() {
    if [ -z "$IFACE" ]; then
        IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
        if [ -z "$IFACE" ]; then
            IFACE=$(vnstat --iflist 2>/dev/null | grep -oP '(?<=Available interfaces: )\S+' | head -1)
        fi
        if [ -z "$IFACE" ]; then
            echo "❌ Cannot detect network interface. Use --iface <name>" >&2
            exit 1
        fi
    fi
}

# Parse human-readable sizes to bytes (50G -> 53687091200)
parse_size() {
    local val="$1"
    local num=$(echo "$val" | grep -oP '[\d.]+')
    local unit=$(echo "$val" | grep -oP '[A-Za-z]+$')
    case "${unit^^}" in
        M|MB|MIB) echo "$num * 1048576" | bc | cut -d. -f1 ;;
        G|GB|GIB) echo "$num * 1073741824" | bc | cut -d. -f1 ;;
        T|TB|TIB) echo "$num * 1099511627776" | bc | cut -d. -f1 ;;
        *) echo "$num" ;;
    esac
}

# Format bytes to human-readable
format_bytes() {
    local bytes=$1
    if [ "$bytes" -ge 1099511627776 ] 2>/dev/null; then
        echo "$(echo "scale=2; $bytes / 1099511627776" | bc) TiB"
    elif [ "$bytes" -ge 1073741824 ] 2>/dev/null; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GiB"
    elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MiB"
    elif [ "$bytes" -ge 1024 ] 2>/dev/null; then
        echo "$(echo "scale=2; $bytes / 1024" | bc) KiB"
    else
        echo "${bytes} B"
    fi
}

# Send Telegram alert
send_telegram() {
    local message="$1"
    local token="${TELEGRAM_BOT_TOKEN}"
    local chat_id="${TELEGRAM_CHAT_ID}"
    if [ -n "$token" ] && [ -n "$chat_id" ]; then
        curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
            -d "chat_id=${chat_id}" \
            -d "text=${message}" \
            -d "parse_mode=Markdown" >/dev/null 2>&1
        echo "📨 Alert sent to Telegram"
    fi
}

# Get vnstat JSON data
get_vnstat_json() {
    vnstat -i "$IFACE" --json 2>/dev/null
}

# Status display
cmd_status() {
    local json=$(get_vnstat_json)
    if [ -z "$json" ] || echo "$json" | grep -q "Error"; then
        echo "❌ No data available for $IFACE yet. vnstat needs time to collect data."
        echo "   Try: vnstat --oneline"
        return 1
    fi

    local today_rx=$(echo "$json" | jq -r '.interfaces[0].traffic.day[-1].rx // 0')
    local today_tx=$(echo "$json" | jq -r '.interfaces[0].traffic.day[-1].tx // 0')
    local today_total=$((today_rx + today_tx))

    local month_rx=$(echo "$json" | jq -r '.interfaces[0].traffic.month[-1].rx // 0')
    local month_tx=$(echo "$json" | jq -r '.interfaces[0].traffic.month[-1].tx // 0')
    local month_total=$((month_rx + month_tx))

    echo "═══════════════════════════════════════════"
    echo "  Bandwidth Monitor — Interface: $IFACE"
    echo "═══════════════════════════════════════════"
    echo "  Today:      ↓ $(format_bytes $today_rx)  ↑ $(format_bytes $today_tx)  ($(format_bytes $today_total) total)"
    echo "  This Month: ↓ $(format_bytes $month_rx)  ↑ $(format_bytes $month_tx)  ($(format_bytes $month_total) total)"

    # Live rate (from vnstat 5-second sample)
    local live=$(vnstat -i "$IFACE" -tr 2 2>/dev/null)
    if [ -n "$live" ]; then
        local rx_rate=$(echo "$live" | grep "rx" | awk '{print $2, $3}')
        local tx_rate=$(echo "$live" | grep "tx" | awk '{print $2, $3}')
        echo "  Right Now:  ↓ ${rx_rate}  ↑ ${tx_rate}"
    fi
    echo "═══════════════════════════════════════════"
}

# Live monitoring
cmd_live() {
    echo "Live bandwidth on $IFACE (Ctrl+C to stop)..."
    echo ""
    while true; do
        local live=$(vnstat -i "$IFACE" -tr "$POLL_INTERVAL" 2>/dev/null)
        local rx_rate=$(echo "$live" | grep "rx" | awk '{print $2, $3}')
        local tx_rate=$(echo "$live" | grep "tx" | awk '{print $2, $3}')
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $IFACE — ↓ ${rx_rate}  ↑ ${tx_rate}"
    done
}

# Reports
cmd_report() {
    local period="${1:-daily}"
    local json=$(get_vnstat_json)

    if [ "$OUTPUT_FORMAT" = "json" ]; then
        if [ "$period" = "daily" ]; then
            echo "$json" | jq '.interfaces[0].traffic.day'
        elif [ "$period" = "monthly" ]; then
            echo "$json" | jq '.interfaces[0].traffic.month'
        fi
        return
    fi

    echo ""
    if [ "$period" = "daily" ]; then
        echo "Daily Bandwidth Report — $IFACE"
        echo "─────────────────────────────────────────────────"
        printf "%-14s %-14s %-14s %s\n" "Date" "↓ Received" "↑ Sent" "Total"
        echo "─────────────────────────────────────────────────"

        local total_rx=0 total_tx=0 count=0
        echo "$json" | jq -r '.interfaces[0].traffic.day[] | "\(.date.year)-\(.date.month | tostring | if length == 1 then "0" + . else . end)-\(.date.day | tostring | if length == 1 then "0" + . else . end) \(.rx) \(.tx)"' | while read -r date rx tx; do
            total=$((rx + tx))
            printf "%-14s %-14s %-14s %s\n" "$date" "$(format_bytes $rx)" "$(format_bytes $tx)" "$(format_bytes $total)"
        done
    elif [ "$period" = "monthly" ]; then
        echo "Monthly Bandwidth Report — $IFACE"
        echo "─────────────────────────────────────────────────"
        printf "%-14s %-14s %-14s %s\n" "Month" "↓ Received" "↑ Sent" "Total"
        echo "─────────────────────────────────────────────────"

        echo "$json" | jq -r '.interfaces[0].traffic.month[] | "\(.date.year)-\(.date.month | tostring | if length == 1 then "0" + . else . end) \(.rx) \(.tx)"' | while read -r month rx tx; do
            total=$((rx + tx))
            printf "%-14s %-14s %-14s %s\n" "$month" "$(format_bytes $rx)" "$(format_bytes $tx)" "$(format_bytes $total)"
        done
    fi
    echo "─────────────────────────────────────────────────"
}

# Threshold checking
cmd_check_thresholds() {
    local json=$(get_vnstat_json)
    local alerts=""

    if [ -n "$DAILY_THRESHOLD" ]; then
        local threshold_bytes=$(parse_size "$DAILY_THRESHOLD")
        local today_rx=$(echo "$json" | jq -r '.interfaces[0].traffic.day[-1].rx // 0')
        local today_tx=$(echo "$json" | jq -r '.interfaces[0].traffic.day[-1].tx // 0')
        local today_total=$((today_rx + today_tx))

        if [ "$today_total" -gt "$threshold_bytes" ] 2>/dev/null; then
            alerts="${alerts}🚨 *Daily threshold exceeded!*\nUsage: $(format_bytes $today_total) / $(format_bytes $threshold_bytes)\n\n"
        fi
    fi

    if [ -n "$MONTHLY_THRESHOLD" ]; then
        local threshold_bytes=$(parse_size "$MONTHLY_THRESHOLD")
        local month_rx=$(echo "$json" | jq -r '.interfaces[0].traffic.month[-1].rx // 0')
        local month_tx=$(echo "$json" | jq -r '.interfaces[0].traffic.month[-1].tx // 0')
        local month_total=$((month_rx + month_tx))

        if [ "$month_total" -gt "$threshold_bytes" ] 2>/dev/null; then
            alerts="${alerts}🚨 *Monthly threshold exceeded!*\nUsage: $(format_bytes $month_total) / $(format_bytes $threshold_bytes)\n\n"
        fi
    fi

    if [ -n "$alerts" ]; then
        local msg="📡 *Bandwidth Alert — $IFACE*\n\n${alerts}$(date '+%Y-%m-%d %H:%M:%S UTC')"
        echo -e "$msg"
        send_telegram "$msg"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ All thresholds OK on $IFACE"
    fi
}

# List interfaces
cmd_interfaces() {
    echo "Network Interfaces:"
    echo "───────────────────"
    vnstat --iflist 2>/dev/null
    echo ""
    echo "Interfaces with data:"
    vnstat --dbiflist 2>/dev/null || vnstat 2>/dev/null | grep -E "^\s+[a-z]"
}

# Per-process bandwidth (requires nethogs)
cmd_top_processes() {
    if ! command -v nethogs &>/dev/null; then
        echo "❌ nethogs not installed. Run: bash scripts/install.sh"
        exit 1
    fi
    echo "Top bandwidth consumers on $IFACE (5-second sample, needs root)..."
    sudo nethogs -t -c 2 "$IFACE" 2>/dev/null | grep -v "^Waiting" | head -20
}

# Compare all interfaces
cmd_compare() {
    echo "Interface Comparison (This Month)"
    echo "──────────────────────────────────────────────────"
    printf "%-12s %-14s %-14s %s\n" "Interface" "↓ Received" "↑ Sent" "Total"
    echo "──────────────────────────────────────────────────"

    for iface in $(vnstat --dbiflist 2>/dev/null | tr ' ' '\n' | grep -v "^$"); do
        local json=$(vnstat -i "$iface" --json 2>/dev/null)
        local rx=$(echo "$json" | jq -r '.interfaces[0].traffic.month[-1].rx // 0')
        local tx=$(echo "$json" | jq -r '.interfaces[0].traffic.month[-1].tx // 0')
        local total=$((rx + tx))
        printf "%-12s %-14s %-14s %s\n" "$iface" "$(format_bytes $rx)" "$(format_bytes $tx)" "$(format_bytes $total)"
    done
    echo "──────────────────────────────────────────────────"
}

# Parse arguments
ACTION=""
REPORT_PERIOD="daily"

load_config

while [[ $# -gt 0 ]]; do
    case $1 in
        --status) ACTION="status"; shift ;;
        --live) ACTION="live"; shift ;;
        --report) ACTION="report"; REPORT_PERIOD="${2:-daily}"; shift; shift 2>/dev/null || true ;;
        --check-thresholds) ACTION="check"; shift ;;
        --interfaces) ACTION="interfaces"; shift ;;
        --top-processes) ACTION="top"; shift ;;
        --compare) ACTION="compare"; shift ;;
        --iface) IFACE="$2"; shift 2 ;;
        --alert-daily) DAILY_THRESHOLD="$2"; shift 2 ;;
        --alert-weekly) WEEKLY_THRESHOLD="$2"; shift 2 ;;
        --alert-monthly) MONTHLY_THRESHOLD="$2"; shift 2 ;;
        --json) OUTPUT_FORMAT="json"; shift ;;
        --help|-h)
            echo "Bandwidth Monitor"
            echo ""
            echo "Usage: bash run.sh [ACTION] [OPTIONS]"
            echo ""
            echo "Actions:"
            echo "  --status             Show current bandwidth usage"
            echo "  --live               Real-time bandwidth monitoring"
            echo "  --report [daily|monthly]  Generate usage report"
            echo "  --check-thresholds   Check against configured thresholds"
            echo "  --interfaces         List all network interfaces"
            echo "  --top-processes      Show per-process bandwidth (needs root)"
            echo "  --compare            Compare bandwidth across interfaces"
            echo ""
            echo "Options:"
            echo "  --iface <name>       Specify network interface"
            echo "  --alert-daily <size> Set daily alert threshold (e.g. 50G)"
            echo "  --alert-monthly <size> Set monthly alert threshold (e.g. 1T)"
            echo "  --json               Output in JSON format"
            exit 0
            ;;
        *) echo "Unknown option: $1. Use --help for usage."; exit 1 ;;
    esac
done

# Default action
if [ -z "$ACTION" ]; then
    ACTION="status"
fi

detect_interface

case "$ACTION" in
    status) cmd_status ;;
    live) cmd_live ;;
    report) cmd_report "$REPORT_PERIOD" ;;
    check) cmd_check_thresholds ;;
    interfaces) cmd_interfaces ;;
    top) cmd_top_processes ;;
    compare) cmd_compare ;;
esac
