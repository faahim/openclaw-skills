#!/usr/bin/env bash
# Network Latency Monitor — Continuous ping monitoring with alerts
# Usage: bash monitor.sh --host 8.8.8.8 [--host 1.1.1.1] [--interval 60] [--threshold 100]

set -euo pipefail

# Defaults
HOSTS=()
HOST_NAMES=()
INTERVAL=60
PING_COUNT=5
THRESHOLD=100
LOSS_THRESHOLD=5
DATA_DIR="./data"
ALERT_CMD=""
CONFIG=""
ONCE=false
RETENTION_DAYS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --host HOST          Host to monitor (repeatable)
  --interval SECS      Seconds between checks (default: 60)
  --ping-count N       Pings per check (default: 5)
  --threshold MS       Latency alert threshold in ms (default: 100)
  --loss-threshold PCT Packet loss alert threshold (default: 5)
  --data-dir DIR       Data storage directory (default: ./data)
  --alert-cmd CMD      Command to run on alert (vars: \$HOST, \$NAME, \$AVG_MS, \$MAX_MS, \$LOSS_PCT, \$THRESHOLD)
  --config FILE        Config file path
  --once               Run one check and exit (for cron)
  --help               Show this help
EOF
  exit 0
}

# Parse simple YAML-like config
parse_config() {
  local file="$1"
  local in_hosts=false
  local current_name="" current_addr="" current_threshold=""

  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    if [[ "$line" =~ ^hosts: ]]; then
      in_hosts=true
      continue
    fi

    if $in_hosts; then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.*) ]]; then
        # Save previous host if exists
        if [[ -n "$current_addr" ]]; then
          HOSTS+=("$current_addr")
          HOST_NAMES+=("${current_name:-$current_addr}")
        fi
        current_name="${BASH_REMATCH[1]}"
        current_addr=""
        current_threshold=""
      elif [[ "$line" =~ ^[[:space:]]*address:[[:space:]]*(.*) ]]; then
        current_addr="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^[[:space:]]*threshold_ms:[[:space:]]*(.*) ]]; then
        current_threshold="${BASH_REMATCH[1]}"
      elif [[ ! "$line" =~ ^[[:space:]] ]]; then
        # End of hosts block
        if [[ -n "$current_addr" ]]; then
          HOSTS+=("$current_addr")
          HOST_NAMES+=("${current_name:-$current_addr}")
        fi
        in_hosts=false
      fi
    fi

    # Top-level config
    if ! $in_hosts; then
      if [[ "$line" =~ ^interval:[[:space:]]*(.*) ]]; then
        INTERVAL="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^ping_count:[[:space:]]*(.*) ]]; then
        PING_COUNT="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^loss_threshold_pct:[[:space:]]*(.*) ]]; then
        LOSS_THRESHOLD="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^data_dir:[[:space:]]*(.*) ]]; then
        DATA_DIR="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^alert_cmd:[[:space:]]*(.*) ]]; then
        ALERT_CMD="${BASH_REMATCH[1]}"
        ALERT_CMD="${ALERT_CMD%\"}"
        ALERT_CMD="${ALERT_CMD#\"}"
      elif [[ "$line" =~ ^retention_days:[[:space:]]*(.*) ]]; then
        RETENTION_DAYS="${BASH_REMATCH[1]}"
      fi
    fi
  done < "$file"

  # Save last host
  if [[ -n "$current_addr" ]]; then
    HOSTS+=("$current_addr")
    HOST_NAMES+=("${current_name:-$current_addr}")
  fi
}

# Parse CLI args
while [[ $# -gt 0 ]]; do
  case $1 in
    --host) HOSTS+=("$2"); HOST_NAMES+=("$2"); shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --ping-count) PING_COUNT="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --loss-threshold) LOSS_THRESHOLD="$2"; shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    --alert-cmd) ALERT_CMD="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --once) ONCE=true; shift ;;
    --help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Load config file if specified
if [[ -n "$CONFIG" ]]; then
  if [[ ! -f "$CONFIG" ]]; then
    echo "Error: Config file not found: $CONFIG"
    exit 1
  fi
  parse_config "$CONFIG"
fi

# Environment variable overrides
INTERVAL="${NLM_INTERVAL:-$INTERVAL}"
THRESHOLD="${NLM_THRESHOLD:-$THRESHOLD}"
LOSS_THRESHOLD="${NLM_LOSS_THRESHOLD:-$LOSS_THRESHOLD}"
DATA_DIR="${NLM_DATA_DIR:-$DATA_DIR}"

if [[ ${#HOSTS[@]} -eq 0 ]]; then
  echo "Error: No hosts specified. Use --host or --config."
  exit 1
fi

# Ensure data directories exist
for host in "${HOSTS[@]}"; do
  mkdir -p "$DATA_DIR/$host"
done

# Check a single host
check_host() {
  local host="$1"
  local name="$2"
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local today
  today=$(date -u +%Y-%m-%d)
  local csv_file="$DATA_DIR/$host/$today.csv"

  # Add CSV header if new file
  if [[ ! -f "$csv_file" ]]; then
    echo "timestamp,host,avg_ms,min_ms,max_ms,loss_pct,ping_count" > "$csv_file"
  fi

  # Run ping
  local ping_output
  ping_output=$(ping -c "$PING_COUNT" -W 5 "$host" 2>&1) || true

  # Parse ping statistics
  local avg_ms=0 min_ms=0 max_ms=0 loss_pct=100

  # Extract packet loss
  if echo "$ping_output" | grep -q "packet loss"; then
    loss_pct=$(echo "$ping_output" | grep "packet loss" | sed -E 's/.*[[:space:]]([0-9.]+)%[[:space:]]*packet loss.*/\1/')
  fi

  # Extract rtt stats (format: min/avg/max/mdev)
  if echo "$ping_output" | grep -q "rtt\|round-trip"; then
    local rtt_line
    rtt_line=$(echo "$ping_output" | grep -E "rtt|round-trip" | sed -E 's/.*= ([0-9.]+)\/([0-9.]+)\/([0-9.]+)\/([0-9.]+).*/\1 \2 \3/')
    min_ms=$(echo "$rtt_line" | awk '{print $1}')
    avg_ms=$(echo "$rtt_line" | awk '{print $2}')
    max_ms=$(echo "$rtt_line" | awk '{print $3}')
  fi

  # Log to CSV
  echo "$timestamp,$host,$avg_ms,$min_ms,$max_ms,$loss_pct,$PING_COUNT" >> "$csv_file"

  # Display status
  local status_icon="✅"
  local status_color="$GREEN"
  local alert=false

  if (( $(echo "$loss_pct >= $LOSS_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
    status_icon="❌"
    status_color="$RED"
    alert=true
  elif (( $(echo "$avg_ms > $THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
    status_icon="⚠️"
    status_color="$YELLOW"
    alert=true
  fi

  printf "[%s] %s (%s) | avg=%sms | min=%sms | max=%sms | loss=%s%% | %b%s%b\n" \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$host" "$name" "$avg_ms" "$min_ms" "$max_ms" "$loss_pct" \
    "$status_color" "$status_icon" "$NC"

  # Fire alert if needed
  if $alert && [[ -n "$ALERT_CMD" ]]; then
    export HOST="$host" NAME="$name" AVG_MS="$avg_ms" MAX_MS="$max_ms" LOSS_PCT="$loss_pct" THRESHOLD="$THRESHOLD"
    eval "$ALERT_CMD" 2>/dev/null || true
  fi

  # Telegram alert
  if $alert && [[ -n "${NLM_TELEGRAM_BOT_TOKEN:-}" ]] && [[ -n "${NLM_TELEGRAM_CHAT_ID:-}" ]]; then
    local msg="🚨 Network Alert: $name ($host)%0ALatency: ${avg_ms}ms (threshold: ${THRESHOLD}ms)%0APacket Loss: ${loss_pct}%"
    curl -s "https://api.telegram.org/bot${NLM_TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${NLM_TELEGRAM_CHAT_ID}&text=${msg}" > /dev/null 2>&1 || true
  fi
}

# Data retention cleanup
cleanup_old_data() {
  if [[ "$RETENTION_DAYS" -gt 0 ]]; then
    find "$DATA_DIR" -name "*.csv" -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
  fi
}

# Main loop
echo "Network Latency Monitor — Monitoring ${#HOSTS[@]} host(s) every ${INTERVAL}s"
echo "Data directory: $DATA_DIR"
echo "Thresholds: latency=${THRESHOLD}ms, loss=${LOSS_THRESHOLD}%"
echo "───────────────────────────────────────────────────"

while true; do
  for i in "${!HOSTS[@]}"; do
    check_host "${HOSTS[$i]}" "${HOST_NAMES[$i]}"
  done

  # Periodic cleanup (every 100 iterations-ish, check once)
  cleanup_old_data

  if $ONCE; then
    break
  fi

  sleep "$INTERVAL"
done
