#!/bin/bash
# NetBird VPN Health Check
# Monitors peer connectivity and alerts on issues

set -euo pipefail

CRON_MODE=false
ALERT_TYPE=""
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --cron) CRON_MODE=true; shift ;;
    --alert) ALERT_TYPE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

send_alert() {
  local message="$1"
  case "$ALERT_TYPE" in
    telegram)
      if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          -d "chat_id=${TELEGRAM_CHAT_ID}" \
          -d "text=${message}" \
          -d "parse_mode=HTML" > /dev/null 2>&1
      fi
      ;;
  esac
}

check_health() {
  # Check if netbird is running
  if ! command -v netbird &>/dev/null; then
    log "❌ NetBird is not installed"
    send_alert "🔴 NetBird VPN: Not installed on $(hostname)"
    return 1
  fi

  local status_output
  status_output=$(sudo netbird status --detail 2>/dev/null) || {
    log "❌ NetBird daemon is not running"
    send_alert "🔴 NetBird VPN: Daemon not running on $(hostname)"
    return 1
  }

  # Check management connection
  if echo "$status_output" | grep -q "Management: Connected"; then
    log "✅ Management server: Connected"
  else
    log "❌ Management server: Disconnected"
    send_alert "🔴 NetBird VPN: Management disconnected on $(hostname)"
  fi

  # Check signal connection
  if echo "$status_output" | grep -q "Signal: Connected"; then
    log "✅ Signal server: Connected"
  else
    log "⚠️  Signal server: Disconnected"
  fi

  # Parse peers
  local total_peers=0 connected_peers=0 relayed_peers=0
  local issues=""

  while IFS= read -r line; do
    if echo "$line" | grep -qE "^\s+[a-zA-Z].*Connected"; then
      ((total_peers++)) || true
      ((connected_peers++)) || true

      if echo "$line" | grep -qi "relayed"; then
        ((relayed_peers++)) || true
        local peer_name
        peer_name=$(echo "$line" | awk '{print $1}')
        log "⚠️  $peer_name — Connected (relayed, higher latency)"
      else
        local peer_name latency
        peer_name=$(echo "$line" | awk '{print $1}')
        latency=$(echo "$line" | grep -oP '\d+ms' | head -1 || echo "N/A")
        log "✅ $peer_name — Connected ($latency)"
      fi
    elif echo "$line" | grep -qE "^\s+[a-zA-Z].*Disconnected"; then
      ((total_peers++)) || true
      local peer_name
      peer_name=$(echo "$line" | awk '{print $1}')
      log "❌ $peer_name — Disconnected"
      issues+="$peer_name (disconnected), "
    fi
  done <<< "$status_output"

  # Summary
  echo ""
  log "📊 Summary: $connected_peers/$total_peers peers connected ($relayed_peers relayed)"

  # Alert on issues
  if [[ -n "$issues" ]]; then
    send_alert "⚠️ NetBird VPN on $(hostname): $connected_peers/$total_peers peers connected. Issues: ${issues%, }"
  fi

  # Log to file in cron mode
  if $CRON_MODE; then
    local log_dir="/var/log/netbird-health"
    sudo mkdir -p "$log_dir" 2>/dev/null || true
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) peers=$connected_peers/$total_peers relayed=$relayed_peers issues=${issues:-none}" | \
      sudo tee -a "$log_dir/health.log" > /dev/null 2>/dev/null || true
  fi
}

check_health
