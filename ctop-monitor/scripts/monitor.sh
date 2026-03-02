#!/bin/bash
# Continuous container resource monitoring with threshold alerts
set -euo pipefail

# Defaults
CPU_WARN=${CTOP_CPU_WARN:-80}
CPU_CRIT=${CTOP_CPU_CRIT:-95}
MEM_WARN=${CTOP_MEM_WARN:-85}
MEM_CRIT=${CTOP_MEM_CRIT:-95}
INTERVAL=30
ALERT_METHOD=""
ACTION=""
COOLDOWN=300
ONCE=false
FILTER=""
CONFIG=""
LAST_RESTART=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --cpu-warn PCT      CPU warning threshold (default: 80)
  --cpu-crit PCT      CPU critical threshold (default: 95)
  --mem-warn PCT      Memory warning threshold (default: 85)
  --mem-crit PCT      Memory critical threshold (default: 95)
  --interval SECS     Check interval in seconds (default: 30)
  --alert METHOD      Alert method: telegram, webhook, stdout (default: stdout)
  --action ACTION     Action on critical: restart, stop, none (default: none)
  --cooldown SECS     Seconds between auto-restart attempts (default: 300)
  --filter LABEL      Filter containers by label (e.g., com.docker.compose.project=myapp)
  --config FILE       Load config from YAML file
  --once              Run one check and exit (for cron)
  -h, --help          Show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --cpu-warn)   CPU_WARN="$2"; shift 2 ;;
    --cpu-crit)   CPU_CRIT="$2"; shift 2 ;;
    --mem-warn)   MEM_WARN="$2"; shift 2 ;;
    --mem-crit)   MEM_CRIT="$2"; shift 2 ;;
    --interval)   INTERVAL="$2"; shift 2 ;;
    --alert)      ALERT_METHOD="$2"; shift 2 ;;
    --action)     ACTION="$2"; shift 2 ;;
    --cooldown)   COOLDOWN="$2"; shift 2 ;;
    --filter)     FILTER="$2"; shift 2 ;;
    --config)     CONFIG="$2"; shift 2 ;;
    --once)       ONCE=true; shift ;;
    -h|--help)    usage ;;
    *)            echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Load config file if provided
if [[ -n "$CONFIG" && -f "$CONFIG" ]]; then
  if command -v yq &>/dev/null; then
    CPU_WARN=$(yq '.thresholds.cpu_warn // 80' "$CONFIG")
    CPU_CRIT=$(yq '.thresholds.cpu_crit // 95' "$CONFIG")
    MEM_WARN=$(yq '.thresholds.mem_warn // 85' "$CONFIG")
    MEM_CRIT=$(yq '.thresholds.mem_crit // 95' "$CONFIG")
    INTERVAL=$(yq '.logging.interval // 30' "$CONFIG")
  fi
fi

send_alert() {
  local level="$1"  # WARNING or CRITICAL
  local message="$2"
  local timestamp
  timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

  case "$ALERT_METHOD" in
    telegram)
      if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        local icon="⚠️"
        [[ "$level" == "CRITICAL" ]] && icon="🚨"
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          -d "chat_id=${TELEGRAM_CHAT_ID}" \
          -d "text=${icon} ${level}: ${message}" \
          -d "parse_mode=HTML" >/dev/null 2>&1
      fi
      ;;
    webhook)
      if [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -s -X POST "$WEBHOOK_URL" \
          -H "Content-Type: application/json" \
          -d "{\"level\":\"$level\",\"message\":\"$message\",\"timestamp\":\"$timestamp\"}" >/dev/null 2>&1
      fi
      ;;
  esac

  # Always log to stdout
  local icon="⚠️"
  [[ "$level" == "CRITICAL" ]] && icon="🚨"
  echo "[$timestamp] $icon $level: $message"
}

can_restart() {
  local container="$1"
  local now
  now=$(date +%s)
  for entry in "${LAST_RESTART[@]:-}"; do
    local name="${entry%%:*}"
    local ts="${entry##*:}"
    if [[ "$name" == "$container" ]] && (( now - ts < COOLDOWN )); then
      return 1
    fi
  done
  return 0
}

do_action() {
  local container="$1"
  local reason="$2"

  case "$ACTION" in
    restart)
      if can_restart "$container"; then
        echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ❌ $container: $reason — restarting container"
        docker restart "$container" --time 10 >/dev/null 2>&1
        LAST_RESTART+=("${container}:$(date +%s)")
        echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ✅ $container: restarted successfully"
        send_alert "CRITICAL" "$container restarted — $reason"
      else
        echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ⏳ $container: restart skipped (cooldown)"
      fi
      ;;
    stop)
      echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] 🛑 $container: $reason — stopping container"
      docker stop "$container" >/dev/null 2>&1
      send_alert "CRITICAL" "$container stopped — $reason"
      ;;
  esac
}

check_containers() {
  local docker_filter=""
  [[ -n "$FILTER" ]] && docker_filter="--filter label=$FILTER"

  # Get container stats (one-shot, no streaming)
  local stats
  stats=$(docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}' $docker_filter 2>/dev/null)

  if [[ -z "$stats" ]]; then
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ℹ️  No running containers found"
    return
  fi

  local alerts=0

  while IFS=$'\t' read -r name cpu_raw mem_raw mem_usage net_io block_io; do
    # Strip % signs
    local cpu_pct=${cpu_raw//%/}
    local mem_pct=${mem_raw//%/}

    # Remove any whitespace
    cpu_pct=$(echo "$cpu_pct" | tr -d ' ')
    mem_pct=$(echo "$mem_pct" | tr -d ' ')

    # Check CPU thresholds
    if (( $(echo "$cpu_pct >= $CPU_CRIT" | bc -l 2>/dev/null || echo 0) )); then
      send_alert "CRITICAL" "$name CPU at ${cpu_pct}% (threshold: ${CPU_CRIT}%)"
      do_action "$name" "CPU at ${cpu_pct}%"
      ((alerts++))
    elif (( $(echo "$cpu_pct >= $CPU_WARN" | bc -l 2>/dev/null || echo 0) )); then
      send_alert "WARNING" "$name CPU at ${cpu_pct}% (threshold: ${CPU_WARN}%)"
      ((alerts++))
    fi

    # Check memory thresholds
    if (( $(echo "$mem_pct >= $MEM_CRIT" | bc -l 2>/dev/null || echo 0) )); then
      send_alert "CRITICAL" "$name memory at ${mem_pct}% (threshold: ${MEM_CRIT}%)"
      do_action "$name" "Memory at ${mem_pct}%"
      ((alerts++))
    elif (( $(echo "$mem_pct >= $MEM_WARN" | bc -l 2>/dev/null || echo 0) )); then
      send_alert "WARNING" "$name memory at ${mem_pct}% (threshold: ${MEM_WARN}%)"
      ((alerts++))
    fi
  done <<< "$stats"

  if [[ $alerts -eq 0 ]]; then
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ✅ All containers within thresholds"
  fi
}

# Pre-flight checks
if ! command -v docker &>/dev/null; then
  echo "❌ Docker not found. Install Docker first."
  exit 1
fi

if ! docker info &>/dev/null 2>&1; then
  echo "❌ Cannot connect to Docker daemon. Is it running?"
  exit 1
fi

echo "=== Ctop Container Monitor ==="
echo "CPU warn: ${CPU_WARN}% | crit: ${CPU_CRIT}%"
echo "MEM warn: ${MEM_WARN}% | crit: ${MEM_CRIT}%"
echo "Interval: ${INTERVAL}s | Alert: ${ALERT_METHOD:-stdout}"
[[ -n "$ACTION" ]] && echo "Action on critical: $ACTION (cooldown: ${COOLDOWN}s)"
[[ -n "$FILTER" ]] && echo "Filter: $FILTER"
echo "---"

if $ONCE; then
  check_containers
else
  trap 'echo ""; echo "Monitor stopped."; exit 0' INT TERM
  while true; do
    check_containers
    sleep "$INTERVAL"
  done
fi
