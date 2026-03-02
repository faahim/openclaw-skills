#!/bin/bash
# Latency Monitor — Continuous network latency, jitter, and packet loss monitoring
# Requires: fping, bc, curl (optional for alerts)
set -euo pipefail

VERSION="1.0.0"

# Defaults
HOSTS=""
INTERVAL=30
COUNT=5
DURATION=0
LOGFILE=""
LATENCY_WARN="${LATMON_LATENCY_WARN:-50}"
LATENCY_CRIT="${LATMON_LATENCY_CRIT:-100}"
JITTER_WARN="${LATMON_JITTER_WARN:-10}"
JITTER_CRIT="${LATMON_JITTER_CRIT:-20}"
LOSS_WARN="${LATMON_LOSS_WARN:-1}"
LOSS_CRIT="${LATMON_LOSS_CRIT:-5}"
ALERT_TELEGRAM="${LATMON_TELEGRAM_TOKEN:+${LATMON_TELEGRAM_TOKEN}:${LATMON_TELEGRAM_CHAT:-}}"
ALERT_WEBHOOK=""
ALERT_CMD=""
QUIET=false
NO_COLOR=false
TCP_MODE=false
TCP_PORT=443

# Alert dedup: track last alert state per host to avoid spam
declare -A LAST_ALERT_STATE

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    cat <<EOF
Latency Monitor v${VERSION}
Monitor network latency, jitter, and packet loss.

Usage: $(basename "$0") [OPTIONS]

Options:
  --host HOST              Single host to monitor
  --hosts HOST1,HOST2      Comma-separated list of hosts
  --interval SECS          Seconds between checks (default: $INTERVAL)
  --count N                Pings per check (default: $COUNT)
  --duration SECS          Stop after N seconds (0=unlimited, default: $DURATION)
  --log FILE               Log results to CSV file
  --latency-warn MS        Warn threshold for avg latency (default: $LATENCY_WARN)
  --latency-crit MS        Critical threshold for avg latency (default: $LATENCY_CRIT)
  --jitter-warn MS         Warn threshold for jitter/stddev (default: $JITTER_WARN)
  --jitter-crit MS         Critical threshold for jitter/stddev (default: $JITTER_CRIT)
  --loss-warn PCT          Warn threshold for packet loss % (default: $LOSS_WARN)
  --loss-crit PCT          Critical threshold for packet loss % (default: $LOSS_CRIT)
  --alert-telegram T:C     Telegram bot token:chat_id for alerts
  --alert-webhook URL      Webhook URL for alert POST
  --alert-cmd "CMD"        Custom command to run on alert (%h=host, %s=status, %m=message)
  --tcp                    Use TCP connect instead of ICMP ping
  --port PORT              TCP port (default: $TCP_PORT, used with --tcp)
  --quiet                  Only output alerts (suppress OK lines)
  --no-color               Disable colored output
  --version                Show version
  -h, --help               Show this help

Environment Variables:
  LATMON_TELEGRAM_TOKEN    Telegram bot token
  LATMON_TELEGRAM_CHAT     Telegram chat ID
  LATMON_LATENCY_WARN      Default latency warn threshold
  LATMON_LATENCY_CRIT      Default latency crit threshold
  LATMON_LOSS_WARN         Default loss warn threshold
  LATMON_LOSS_CRIT         Default loss crit threshold

Examples:
  $(basename "$0") --host 1.1.1.1 --interval 30
  $(basename "$0") --hosts "1.1.1.1,8.8.8.8,9.9.9.9" --interval 60 --log /tmp/latency.csv
  $(basename "$0") --host your-server.com --latency-warn 30 --alert-telegram "TOKEN:CHATID"
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host) HOSTS="$2"; shift 2 ;;
        --hosts) HOSTS="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --count) COUNT="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        --log) LOGFILE="$2"; shift 2 ;;
        --latency-warn) LATENCY_WARN="$2"; shift 2 ;;
        --latency-crit) LATENCY_CRIT="$2"; shift 2 ;;
        --jitter-warn) JITTER_WARN="$2"; shift 2 ;;
        --jitter-crit) JITTER_CRIT="$2"; shift 2 ;;
        --loss-warn) LOSS_WARN="$2"; shift 2 ;;
        --loss-crit) LOSS_CRIT="$2"; shift 2 ;;
        --alert-telegram) ALERT_TELEGRAM="$2"; shift 2 ;;
        --alert-webhook) ALERT_WEBHOOK="$2"; shift 2 ;;
        --alert-cmd) ALERT_CMD="$2"; shift 2 ;;
        --tcp) TCP_MODE=true; shift ;;
        --port) TCP_PORT="$2"; shift 2 ;;
        --quiet) QUIET=true; shift ;;
        --no-color) NO_COLOR=true; shift ;;
        --version) echo "Latency Monitor v${VERSION}"; exit 0 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$HOSTS" ]]; then
    echo "Error: No hosts specified. Use --host or --hosts."
    echo "Run with --help for usage."
    exit 1
fi

# Disable colors if requested
if $NO_COLOR; then
    RED="" YELLOW="" GREEN="" CYAN="" NC=""
fi

# Check dependencies
check_deps() {
    local missing=()
    if ! $TCP_MODE; then
        command -v fping >/dev/null 2>&1 || missing+=("fping")
    fi
    command -v bc >/dev/null 2>&1 || missing+=("bc")
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing dependencies: ${missing[*]}"
        echo "Install with: sudo apt-get install -y ${missing[*]}"
        exit 1
    fi
}

check_deps

# Initialize CSV log
if [[ -n "$LOGFILE" ]]; then
    mkdir -p "$(dirname "$LOGFILE")"
    if [[ ! -f "$LOGFILE" ]]; then
        echo "timestamp,host,latency_avg,latency_min,latency_max,jitter,loss_pct,status" > "$LOGFILE"
    fi
fi

# Convert hosts string to array
IFS=',' read -ra HOST_ARRAY <<< "$HOSTS"

# Send alert
send_alert() {
    local host="$1" status="$2" message="$3"
    
    # Dedup: don't re-alert if same state
    local prev_state="${LAST_ALERT_STATE[$host]:-ok}"
    if [[ "$prev_state" == "$status" && "$status" != "ok" ]]; then
        return
    fi
    LAST_ALERT_STATE[$host]="$status"
    
    # Only alert on non-OK transitions
    if [[ "$status" == "ok" && "$prev_state" == "ok" ]]; then
        return
    fi

    local alert_text
    if [[ "$status" == "ok" ]]; then
        alert_text="✅ RECOVERED: $host — $message"
    else
        alert_text="🚨 ALERT ($status): $host — $message"
    fi

    # Telegram
    if [[ -n "$ALERT_TELEGRAM" ]]; then
        local token="${ALERT_TELEGRAM%%:*}"
        local chat_id="${ALERT_TELEGRAM#*:}"
        # Handle TOKEN:CHATID format where token itself contains colons (bot tokens do)
        if [[ "$ALERT_TELEGRAM" =~ ^([^:]+:[^:]+):(.+)$ ]]; then
            token="${BASH_REMATCH[1]}"
            chat_id="${BASH_REMATCH[2]}"
        fi
        curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
            -d "chat_id=${chat_id}" \
            -d "text=${alert_text}" \
            -d "parse_mode=HTML" >/dev/null 2>&1 || true
    fi

    # Webhook
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"host\":\"$host\",\"status\":\"$status\",\"message\":\"$message\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            >/dev/null 2>&1 || true
    fi

    # Custom command
    if [[ -n "$ALERT_CMD" ]]; then
        local cmd="${ALERT_CMD//%h/$host}"
        cmd="${cmd//%s/$status}"
        cmd="${cmd//%m/$message}"
        eval "$cmd" 2>/dev/null || true
    fi
}

# Ping a host using fping, parse results
ping_host() {
    local host="$1"
    
    if $TCP_MODE; then
        # TCP connect timing using bash /dev/tcp
        local times=()
        local success=0
        local total=$COUNT
        
        for ((i=0; i<total; i++)); do
            local start end elapsed
            start=$(date +%s%N)
            if timeout 5 bash -c "echo >/dev/tcp/$host/$TCP_PORT" 2>/dev/null; then
                end=$(date +%s%N)
                elapsed=$(echo "scale=1; ($end - $start) / 1000000" | bc)
                times+=("$elapsed")
                ((success++))
            fi
        done
        
        local loss_pct
        if [[ $total -eq 0 ]]; then
            loss_pct="100"
        else
            loss_pct=$(echo "scale=1; ($total - $success) * 100 / $total" | bc)
        fi
        
        if [[ ${#times[@]} -eq 0 ]]; then
            echo "0|0|0|0|$loss_pct"
            return
        fi
        
        # Calculate stats
        local sum=0 min="${times[0]}" max="${times[0]}"
        for t in "${times[@]}"; do
            sum=$(echo "$sum + $t" | bc)
            if (( $(echo "$t < $min" | bc -l) )); then min="$t"; fi
            if (( $(echo "$t > $max" | bc -l) )); then max="$t"; fi
        done
        local avg=$(echo "scale=1; $sum / ${#times[@]}" | bc)
        
        # Jitter (standard deviation)
        local variance_sum=0
        for t in "${times[@]}"; do
            local diff=$(echo "$t - $avg" | bc)
            variance_sum=$(echo "$variance_sum + $diff * $diff" | bc)
        done
        local jitter=$(echo "scale=1; sqrt($variance_sum / ${#times[@]})" | bc)
        
        echo "${avg}|${min}|${max}|${jitter}|${loss_pct}"
        return
    fi
    
    # ICMP mode using fping
    local output
    output=$(fping -C "$COUNT" -q -p 200 "$host" 2>&1 || true)
    
    # fping output format: host : 1.23 2.34 - 3.45
    # "-" means lost packet
    local times_str
    times_str=$(echo "$output" | grep -oP ':\s+\K.*' | head -1)
    
    if [[ -z "$times_str" ]]; then
        echo "0|0|0|0|100"
        return
    fi
    
    # Parse times, count losses
    local total=0 lost=0
    local times=()
    for val in $times_str; do
        ((total++))
        if [[ "$val" == "-" ]]; then
            ((lost++))
        else
            times+=("$val")
        fi
    done
    
    local loss_pct
    if [[ $total -eq 0 ]]; then
        loss_pct="100"
    else
        loss_pct=$(echo "scale=1; $lost * 100 / $total" | bc)
    fi
    
    if [[ ${#times[@]} -eq 0 ]]; then
        echo "0|0|0|0|$loss_pct"
        return
    fi
    
    # Calculate avg, min, max, jitter
    local sum=0 min="${times[0]}" max="${times[0]}"
    for t in "${times[@]}"; do
        sum=$(echo "$sum + $t" | bc)
        if (( $(echo "$t < $min" | bc -l) )); then min="$t"; fi
        if (( $(echo "$t > $max" | bc -l) )); then max="$t"; fi
    done
    local avg=$(echo "scale=1; $sum / ${#times[@]}" | bc)
    
    # Jitter (standard deviation)
    local variance_sum=0
    for t in "${times[@]}"; do
        local diff=$(echo "$t - $avg" | bc)
        variance_sum=$(echo "$variance_sum + $diff * $diff" | bc)
    done
    local jitter=$(echo "scale=1; sqrt($variance_sum / ${#times[@]})" | bc)
    
    echo "${avg}|${min}|${max}|${jitter}|${loss_pct}"
}

# Evaluate thresholds
evaluate() {
    local avg="$1" jitter="$2" loss="$3"
    
    # Critical checks
    if (( $(echo "$loss >= $LOSS_CRIT" | bc -l) )); then
        echo "critical|HIGH PACKET LOSS (${loss}%)"
        return
    fi
    if (( $(echo "$avg >= $LATENCY_CRIT" | bc -l) )); then
        echo "critical|HIGH LATENCY (${avg}ms)"
        return
    fi
    if (( $(echo "$jitter >= $JITTER_CRIT" | bc -l) )); then
        echo "critical|HIGH JITTER (${jitter}ms)"
        return
    fi
    
    # Warning checks
    if (( $(echo "$loss >= $LOSS_WARN" | bc -l) )); then
        echo "warn|PACKET LOSS (${loss}%)"
        return
    fi
    if (( $(echo "$avg >= $LATENCY_WARN" | bc -l) )); then
        echo "warn|HIGH LATENCY (${avg}ms)"
        return
    fi
    if (( $(echo "$jitter >= $JITTER_WARN" | bc -l) )); then
        echo "warn|HIGH JITTER (${jitter}ms)"
        return
    fi
    
    echo "ok|OK"
}

# Grade network quality
grade() {
    local avg="$1" jitter="$2" loss="$3"
    if (( $(echo "$avg < 20 && $jitter < 2 && $loss == 0" | bc -l) )); then echo "★★★★★"
    elif (( $(echo "$avg < 50 && $jitter < 5 && $loss < 0.5" | bc -l) )); then echo "★★★★"
    elif (( $(echo "$avg < 100 && $jitter < 15 && $loss < 1" | bc -l) )); then echo "★★★"
    elif (( $(echo "$avg < 200 && $jitter < 30 && $loss < 3" | bc -l) )); then echo "★★"
    else echo "★"
    fi
}

# Trap for clean exit
cleanup() {
    echo ""
    echo "Latency Monitor stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM

# Main loop
echo -e "${CYAN}Latency Monitor v${VERSION}${NC}"
echo -e "Monitoring: ${HOST_ARRAY[*]}"
echo -e "Interval: ${INTERVAL}s | Count: ${COUNT} pings | Thresholds: lat=${LATENCY_WARN}/${LATENCY_CRIT}ms jit=${JITTER_WARN}/${JITTER_CRIT}ms loss=${LOSS_WARN}/${LOSS_CRIT}%"
echo "---"

START_TIME=$(date +%s)

while true; do
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    NOW_DISPLAY=$(date '+%Y-%m-%d %H:%M:%S')
    
    for host in "${HOST_ARRAY[@]}"; do
        host=$(echo "$host" | xargs)  # trim whitespace
        
        # Ping and parse
        result=$(ping_host "$host")
        IFS='|' read -r avg min max jitter loss <<< "$result"
        
        # Evaluate
        eval_result=$(evaluate "$avg" "$jitter" "$loss")
        IFS='|' read -r status message <<< "$eval_result"
        
        # Format output
        color="$GREEN"
        icon="✅"
        case "$status" in
            warn) color="$YELLOW"; icon="⚠️" ;;
            critical) color="$RED"; icon="🔴" ;;
        esac
        
        if ! $QUIET || [[ "$status" != "ok" ]]; then
            echo -e "[${NOW_DISPLAY}] ${host} | latency=${avg}ms jitter=${jitter}ms loss=${loss}% | ${color}${icon} ${message}${NC}"
        fi
        
        # Log to CSV
        if [[ -n "$LOGFILE" ]]; then
            echo "${NOW},${host},${avg},${min},${max},${jitter},${loss},${status}" >> "$LOGFILE"
        fi
        
        # Send alerts on non-OK or recovery
        send_alert "$host" "$status" "latency=${avg}ms jitter=${jitter}ms loss=${loss}% — ${message}"
    done
    
    # Check duration limit
    if [[ $DURATION -gt 0 ]]; then
        ELAPSED=$(( $(date +%s) - START_TIME ))
        if [[ $ELAPSED -ge $DURATION ]]; then
            echo "Duration limit reached (${DURATION}s). Stopping."
            break
        fi
    fi
    
    sleep "$INTERVAL"
done
