#!/bin/bash
# Speedtest Monitor — Track internet speed, log history, alert on degradation
set -euo pipefail

# Defaults
INTERVAL=3600
MIN_DOWNLOAD=0
MIN_UPLOAD=0
MAX_PING=0
ALERT_TYPE="none"
LOG_FILE="./speedtest.csv"
SERVER=""
JSON_OUTPUT=false
ONCE=false
REPORT=false
ALERT_COOLDOWN=3600  # Don't re-alert within 1 hour
LAST_ALERT_FILE="/tmp/speedtest-monitor-last-alert"

usage() {
  cat <<EOF
Speedtest Monitor — Track internet speed over time

Usage: bash run.sh [OPTIONS]

Options:
  --once              Run single test and exit
  --interval N        Seconds between tests (default: 3600)
  --min-download N    Alert if download below N Mbps
  --min-upload N      Alert if upload below N Mbps
  --max-ping N        Alert if ping above N ms
  --alert TYPE        Alert type: telegram, webhook, log (default: none)
  --log FILE          CSV log file path (default: ./speedtest.csv)
  --server ID         Specific speedtest server ID
  --json              Output results as JSON
  --report            Generate report from existing log
  -h, --help          Show this help

Environment:
  TELEGRAM_BOT_TOKEN  Telegram bot token (for --alert telegram)
  TELEGRAM_CHAT_ID    Telegram chat ID
  SPEEDTEST_WEBHOOK_URL  Webhook URL (for --alert webhook)
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --once) ONCE=true; shift ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --min-download) MIN_DOWNLOAD="$2"; shift 2 ;;
    --min-upload) MIN_UPLOAD="$2"; shift 2 ;;
    --max-ping) MAX_PING="$2"; shift 2 ;;
    --alert) ALERT_TYPE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --server) SERVER="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --report) REPORT=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Check dependencies
check_deps() {
  if ! command -v speedtest-cli &>/dev/null; then
    echo "ERROR: speedtest-cli not found. Install: pip3 install speedtest-cli"
    exit 1
  fi
  for cmd in jq bc curl; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "WARNING: $cmd not found. Some features may not work."
    fi
  done
}

# Initialize CSV log
init_log() {
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "timestamp,download_mbps,upload_mbps,ping_ms,server,status" > "$LOG_FILE"
  fi
}

# Run speedtest
run_test() {
  local server_flag=""
  [[ -n "$SERVER" ]] && server_flag="--server $SERVER"

  local result
  result=$(speedtest-cli --json $server_flag 2>/dev/null) || {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Speedtest failed — network error or timeout"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),0,0,0,unknown,error" >> "$LOG_FILE"
    return 1
  }

  # Parse results
  local download upload ping server_name timestamp
  download=$(echo "$result" | jq -r '.download' | awk '{printf "%.1f", $1/1000000}')
  upload=$(echo "$result" | jq -r '.upload' | awk '{printf "%.1f", $1/1000000}')
  ping=$(echo "$result" | jq -r '.ping')
  server_name=$(echo "$result" | jq -r '.server.sponsor + " (" + .server.name + ")"')
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Log to CSV
  echo "${timestamp},${download},${upload},${ping},\"${server_name}\",ok" >> "$LOG_FILE"

  # Check thresholds
  local status="✅"
  local alerts=""

  if [[ $(echo "$MIN_DOWNLOAD > 0" | bc -l) -eq 1 ]] && [[ $(echo "$download < $MIN_DOWNLOAD" | bc -l) -eq 1 ]]; then
    status="❌"
    alerts="${alerts}Download ${download} Mbps (threshold: ${MIN_DOWNLOAD} Mbps) "
  fi

  if [[ $(echo "$MIN_UPLOAD > 0" | bc -l) -eq 1 ]] && [[ $(echo "$upload < $MIN_UPLOAD" | bc -l) -eq 1 ]]; then
    status="❌"
    alerts="${alerts}Upload ${upload} Mbps (threshold: ${MIN_UPLOAD} Mbps) "
  fi

  if [[ $(echo "$MAX_PING > 0" | bc -l) -eq 1 ]] && [[ $(echo "$ping > $MAX_PING" | bc -l) -eq 1 ]]; then
    status="❌"
    alerts="${alerts}Ping ${ping} ms (threshold: ${MAX_PING} ms) "
  fi

  # Output
  if [[ "$JSON_OUTPUT" == true ]]; then
    echo "{\"timestamp\":\"${timestamp}\",\"download_mbps\":${download},\"upload_mbps\":${upload},\"ping_ms\":${ping},\"server\":\"${server_name}\",\"status\":\"$([ "$status" = "✅" ] && echo ok || echo degraded)\"}"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${status} Download: ${download} Mbps | Upload: ${upload} Mbps | Ping: ${ping} ms | Server: ${server_name}"
  fi

  # Send alerts if thresholds breached
  if [[ -n "$alerts" ]] && [[ "$ALERT_TYPE" != "none" ]]; then
    send_alert "$alerts" "$download" "$upload" "$ping"
  fi
}

# Send alert (with cooldown)
send_alert() {
  local alerts="$1" download="$2" upload="$3" ping="$4"

  # Check cooldown
  if [[ -f "$LAST_ALERT_FILE" ]]; then
    local last_alert
    last_alert=$(cat "$LAST_ALERT_FILE")
    local now
    now=$(date +%s)
    if [[ $((now - last_alert)) -lt $ALERT_COOLDOWN ]]; then
      return 0  # Still in cooldown
    fi
  fi

  local message="🚨 SPEED ALERT: ${alerts}"

  case "$ALERT_TYPE" in
    telegram)
      if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] && [[ -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          -d chat_id="${TELEGRAM_CHAT_ID}" \
          -d text="${message}" \
          -d parse_mode="HTML" >/dev/null 2>&1
        echo "$message"
      else
        echo "WARNING: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set"
      fi
      ;;
    webhook)
      if [[ -n "${SPEEDTEST_WEBHOOK_URL:-}" ]]; then
        curl -s -X POST "${SPEEDTEST_WEBHOOK_URL}" \
          -H "Content-Type: application/json" \
          -d "{\"text\":\"${message}\",\"download\":${download},\"upload\":${upload},\"ping\":${ping}}" >/dev/null 2>&1
        echo "$message"
      else
        echo "WARNING: SPEEDTEST_WEBHOOK_URL not set"
      fi
      ;;
    log)
      echo "$message"
      ;;
  esac

  date +%s > "$LAST_ALERT_FILE"
}

# Generate report from log
generate_report() {
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "No log file found at $LOG_FILE"
    exit 1
  fi

  local total avg_dl avg_ul avg_ping min_dl max_dl min_ul max_ul min_ping max_ping degradations
  total=$(tail -n +2 "$LOG_FILE" | wc -l)

  if [[ $total -eq 0 ]]; then
    echo "No test results in log."
    exit 0
  fi

  avg_dl=$(tail -n +2 "$LOG_FILE" | awk -F',' '{sum+=$2; n++} END {printf "%.1f", sum/n}')
  avg_ul=$(tail -n +2 "$LOG_FILE" | awk -F',' '{sum+=$3; n++} END {printf "%.1f", sum/n}')
  avg_ping=$(tail -n +2 "$LOG_FILE" | awk -F',' '{sum+=$4; n++} END {printf "%.1f", sum/n}')
  min_dl=$(tail -n +2 "$LOG_FILE" | awk -F',' 'NR==1||$2<min{min=$2} END {printf "%.1f", min}')
  max_dl=$(tail -n +2 "$LOG_FILE" | awk -F',' 'NR==1||$2>max{max=$2} END {printf "%.1f", max}')
  min_ul=$(tail -n +2 "$LOG_FILE" | awk -F',' 'NR==1||$3<min{min=$3} END {printf "%.1f", min}')
  max_ul=$(tail -n +2 "$LOG_FILE" | awk -F',' 'NR==1||$3>max{max=$3} END {printf "%.1f", max}')
  min_ping=$(tail -n +2 "$LOG_FILE" | awk -F',' 'NR==1||$4<min{min=$4} END {printf "%.1f", min}')
  max_ping=$(tail -n +2 "$LOG_FILE" | awk -F',' 'NR==1||$4>max{max=$4} END {printf "%.1f", max}')
  degradations=$(tail -n +2 "$LOG_FILE" | awk -F',' '$NF ~ /error|degraded/ {n++} END {print n+0}')

  cat <<EOF
=== Internet Speed Report ===
Tests run: $total
Avg Download: ${avg_dl} Mbps (min: ${min_dl}, max: ${max_dl})
Avg Upload: ${avg_ul} Mbps (min: ${min_ul}, max: ${max_ul})
Avg Ping: ${avg_ping} ms (min: ${min_ping}, max: ${max_ping})
Degradation events: $degradations
Log file: $LOG_FILE
EOF
}

# Main
check_deps

if [[ "$REPORT" == true ]]; then
  generate_report
  exit 0
fi

init_log

if [[ "$ONCE" == true ]]; then
  run_test
  exit 0
fi

echo "Speedtest Monitor started — testing every ${INTERVAL}s"
echo "Log: $LOG_FILE"
[[ $MIN_DOWNLOAD -gt 0 ]] && echo "Alert if download < ${MIN_DOWNLOAD} Mbps"
[[ $MIN_UPLOAD -gt 0 ]] && echo "Alert if upload < ${MIN_UPLOAD} Mbps"
[[ $MAX_PING -gt 0 ]] && echo "Alert if ping > ${MAX_PING} ms"
echo "---"

while true; do
  run_test || true
  sleep "$INTERVAL"
done
