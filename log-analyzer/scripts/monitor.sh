#!/bin/bash
# Log Monitor — Watch log files in real-time, alert on error spikes
# Usage: bash monitor.sh --file <logfile> [options]

set -euo pipefail

# Defaults
LOG_FILE=""
THRESHOLD=10
INTERVAL=300
ALERT_METHOD="stdout"
COOLDOWN=1800
ERROR_PATTERN="ERROR|error|FATAL|fatal|CRITICAL|CRIT|PANIC|panic|EMERGENCY|EMERG|Failed|failed"
LAST_ALERT=0
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/log-analyzer"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file) LOG_FILE="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --alert) ALERT_METHOD="$2"; shift 2 ;;
    --cooldown) COOLDOWN="$2"; shift 2 ;;
    --error-pattern) ERROR_PATTERN="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$LOG_FILE" ]]; then
  echo "Usage: bash monitor.sh --file <logfile> [options]"
  echo "  --threshold <N>      Alert if errors exceed N per interval (default: 10)"
  echo "  --interval <sec>     Check interval in seconds (default: 300)"
  echo "  --alert <method>     Alert method: stdout, telegram, webhook (default: stdout)"
  echo "  --cooldown <sec>     Min seconds between alerts (default: 1800)"
  echo "  --error-pattern <re> Custom error regex"
  exit 1
fi

mkdir -p "$STATE_DIR"

# Alert functions
send_telegram() {
  local msg="$1"
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    echo "[ALERT] Telegram not configured. Message: $msg"
    return 1
  fi
  curl -sf "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${msg}" \
    -d "parse_mode=HTML" > /dev/null 2>&1
}

send_webhook() {
  local msg="$1"
  if [[ -z "${ALERT_WEBHOOK_URL:-}" ]]; then
    echo "[ALERT] Webhook not configured. Message: $msg"
    return 1
  fi
  curl -sf -X POST "${ALERT_WEBHOOK_URL}" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"$msg\"}" > /dev/null 2>&1
}

send_alert() {
  local msg="$1"
  local now
  now=$(date +%s)
  
  # Cooldown check
  if (( now - LAST_ALERT < COOLDOWN )); then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏸ Alert suppressed (cooldown: $((COOLDOWN - (now - LAST_ALERT)))s remaining)"
    return
  fi
  
  LAST_ALERT=$now
  
  case "$ALERT_METHOD" in
    telegram)
      send_telegram "$msg"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📨 Alert sent to Telegram"
      ;;
    webhook)
      send_webhook "$msg"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📨 Alert sent to webhook"
      ;;
    stdout)
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚨 $msg"
      ;;
  esac
}

# Get line count of file
get_line_count() {
  wc -l < "$1" 2>/dev/null || echo 0
}

# Main monitoring loop
echo "╔══════════════════════════════════════════════╗"
echo "║           LOG MONITOR ACTIVE                 ║"
echo "╠══════════════════════════════════════════════╣"
echo "║ File: $(printf '%-38s' "$LOG_FILE")║"
echo "║ Threshold: $(printf '%-33s' "$THRESHOLD errors/interval")║"
echo "║ Interval: $(printf '%-34s' "${INTERVAL}s")║"
echo "║ Alert: $(printf '%-37s' "$ALERT_METHOD")║"
echo "║ Cooldown: $(printf '%-34s' "${COOLDOWN}s")║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Record initial position
LAST_LINES=$(get_line_count "$LOG_FILE")

while true; do
  sleep "$INTERVAL"
  
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ File not found: $LOG_FILE"
    continue
  fi
  
  CURRENT_LINES=$(get_line_count "$LOG_FILE")
  
  # Handle log rotation (file got smaller)
  if (( CURRENT_LINES < LAST_LINES )); then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Log rotation detected, resetting position"
    LAST_LINES=0
  fi
  
  NEW_LINES=$((CURRENT_LINES - LAST_LINES))
  
  if (( NEW_LINES <= 0 )); then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ No new entries"
    continue
  fi
  
  # Count errors in new lines
  ERROR_COUNT=$(tail -n "$NEW_LINES" "$LOG_FILE" | grep -cE "$ERROR_PATTERN" 2>/dev/null || echo 0)
  
  if (( ERROR_COUNT >= THRESHOLD )); then
    # Get top error for context
    TOP_ERROR=$(tail -n "$NEW_LINES" "$LOG_FILE" | grep -E "$ERROR_PATTERN" | \
      sed 's/[0-9]\{1,\}/N/g' | sort | uniq -c | sort -rn | head -1 | \
      sed 's/^[[:space:]]*//' | head -c 100)
    
    ALERT_MSG="🚨 <b>Log Alert: $LOG_FILE</b>
$ERROR_COUNT errors in last ${INTERVAL}s (threshold: $THRESHOLD)
Top error: $TOP_ERROR"
    
    send_alert "$ALERT_MSG"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $LOG_FILE — $NEW_LINES new lines, $ERROR_COUNT errors (OK)"
  fi
  
  LAST_LINES=$CURRENT_LINES
done
