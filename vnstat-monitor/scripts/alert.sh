#!/bin/bash
# vnstat-monitor: Bandwidth cap alerts
set -euo pipefail

CONFIG_DIR="$HOME/.vnstat-monitor"
ALERT_LOG="${VNSTAT_ALERT_LOG:-$CONFIG_DIR/alerts.log}"
mkdir -p "$CONFIG_DIR"

# Defaults
CAP=0
UNIT="GiB"
PERIOD="monthly"
WARN_PCT=80
CRIT_PCT=95
CHECK_ONLY=false
INSTALL_CRON=false
CRON_TIME="0 8 * * *"
INTERFACE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --cap) CAP="$2"; shift 2 ;;
    --unit) UNIT="$2"; shift 2 ;;
    --period) PERIOD="$2"; shift 2 ;;
    --warn-at) WARN_PCT="$2"; shift 2 ;;
    --crit-at) CRIT_PCT="$2"; shift 2 ;;
    --check) CHECK_ONLY=true; shift ;;
    --install-cron) INSTALL_CRON=true; shift ;;
    --time) CRON_TIME="$2"; shift 2 ;;
    --interface|-i) INTERFACE="$2"; shift 2 ;;
    --help) echo "Usage: alert.sh --cap <N> --unit <GiB|TiB> [--warn-at 80] [--crit-at 95] [--check] [--install-cron --time '0 8 * * *']"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[ "$CAP" -eq 0 ] && { echo "❌ --cap is required. Example: --cap 1000 --unit GiB"; exit 1; }

command -v vnstat &>/dev/null || { echo "❌ vnstat not installed. Run: bash scripts/install.sh"; exit 1; }

# Auto-detect interface
if [ -z "$INTERFACE" ]; then
  INTERFACE=$(vnstat --iflist 2>/dev/null | grep -oP '(?:eth|ens|enp|wlan|wlp)\S+' | head -1)
  [ -z "$INTERFACE" ] && INTERFACE="eth0"
fi

# Convert cap to bytes
case "$UNIT" in
  GiB|gib) CAP_BYTES=$(echo "$CAP * 1073741824" | bc) ;;
  TiB|tib) CAP_BYTES=$(echo "$CAP * 1099511627776" | bc) ;;
  MiB|mib) CAP_BYTES=$(echo "$CAP * 1048576" | bc) ;;
  GB|gb) CAP_BYTES=$(echo "$CAP * 1000000000" | bc) ;;
  TB|tb) CAP_BYTES=$(echo "$CAP * 1000000000000" | bc) ;;
  *) echo "❌ Unknown unit: $UNIT (use GiB, TiB, MiB, GB, TB)"; exit 1 ;;
esac

# Get current month total
CURRENT_BYTES=$(vnstat -i "$INTERFACE" --json m 2>/dev/null | jq -r '.interfaces[0].traffic.month[-1].total // 0' 2>/dev/null || echo "0")

# Calculate percentages
if [ "$CAP_BYTES" -gt 0 ]; then
  USAGE_PCT=$(echo "scale=1; $CURRENT_BYTES * 100 / $CAP_BYTES" | bc 2>/dev/null || echo "0")
else
  USAGE_PCT="0"
fi

human_bytes() {
  local bytes=$1
  if [ "$bytes" -ge 1073741824 ]; then
    echo "$(echo "scale=2; $bytes / 1073741824" | bc) GiB"
  elif [ "$bytes" -ge 1048576 ]; then
    echo "$(echo "scale=2; $bytes / 1048576" | bc) MiB"
  else
    echo "$bytes B"
  fi
}

CURRENT_HUMAN=$(human_bytes "$CURRENT_BYTES")

# Project end-of-month
DAY_OF_MONTH=$(date +%-d)
DAYS_IN_MONTH=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +%-d 2>/dev/null || echo 30)
PROJECTED_BYTES=0
PROJECTED_PCT="0"
if [ "$DAY_OF_MONTH" -gt 0 ] && [ "$CURRENT_BYTES" -gt 0 ]; then
  PROJECTED_BYTES=$(echo "scale=0; $CURRENT_BYTES * $DAYS_IN_MONTH / $DAY_OF_MONTH" | bc 2>/dev/null || echo "0")
  PROJECTED_PCT=$(echo "scale=1; $PROJECTED_BYTES * 100 / $CAP_BYTES" | bc 2>/dev/null || echo "0")
fi
PROJECTED_HUMAN=$(human_bytes "$PROJECTED_BYTES")

# Determine alert level
ALERT_LEVEL="ok"
USAGE_INT=$(echo "$USAGE_PCT" | cut -d. -f1)
[ -z "$USAGE_INT" ] && USAGE_INT=0
[ "$USAGE_INT" -ge "$WARN_PCT" ] && ALERT_LEVEL="warning"
[ "$USAGE_INT" -ge "$CRIT_PCT" ] && ALERT_LEVEL="critical"

# Check mode: just report
if $CHECK_ONLY; then
  case "$ALERT_LEVEL" in
    ok) echo "✅ Current usage: $CURRENT_HUMAN / $CAP $UNIT ($USAGE_PCT%)" ;;
    warning) echo "⚠️  Current usage: $CURRENT_HUMAN / $CAP $UNIT ($USAGE_PCT%) — APPROACHING LIMIT" ;;
    critical) echo "🚨 Current usage: $CURRENT_HUMAN / $CAP $UNIT ($USAGE_PCT%) — NEAR/OVER LIMIT" ;;
  esac
  echo "📊 Projected end-of-month: $PROJECTED_HUMAN ($PROJECTED_PCT%)"
  exit 0
fi

# Install cron mode
if $INSTALL_CRON; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  CRON_CMD="$CRON_TIME cd \"$(dirname "$SCRIPT_DIR")\" && bash scripts/alert.sh --cap $CAP --unit $UNIT --warn-at $WARN_PCT --crit-at $CRIT_PCT --check >> \"$ALERT_LOG\" 2>&1"
  
  # Add to crontab (avoid duplicates)
  (crontab -l 2>/dev/null | grep -v "vnstat-monitor" || true; echo "$CRON_CMD") | crontab -
  
  echo "✅ Cron alert installed: $CRON_TIME"
  echo "   Cap: $CAP $UNIT | Warn: ${WARN_PCT}% | Critical: ${CRIT_PCT}%"
  echo "   Log: $ALERT_LOG"
  exit 0
fi

# Default: run check and log
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_LINE="[$TIMESTAMP] [$ALERT_LEVEL] $INTERFACE: $CURRENT_HUMAN / $CAP $UNIT ($USAGE_PCT%) | Projected: $PROJECTED_HUMAN ($PROJECTED_PCT%)"
echo "$LOG_LINE" | tee -a "$ALERT_LOG"

# Telegram alert for warning/critical
if [ "$ALERT_LEVEL" != "ok" ] && [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  MSG=""
  case "$ALERT_LEVEL" in
    warning) MSG="⚠️ Bandwidth Warning: $CURRENT_HUMAN / $CAP $UNIT ($USAGE_PCT%) on $INTERFACE. Projected: $PROJECTED_HUMAN" ;;
    critical) MSG="🚨 Bandwidth Critical: $CURRENT_HUMAN / $CAP $UNIT ($USAGE_PCT%) on $INTERFACE. Projected: $PROJECTED_HUMAN" ;;
  esac
  
  curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${MSG}" \
    -d "parse_mode=Markdown" > /dev/null 2>&1 || true
  
  echo "  📱 Telegram alert sent"
fi
