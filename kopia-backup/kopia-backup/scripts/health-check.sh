#!/bin/bash
# Kopia Backup Manager — Health Check & Alert Script
# Checks repository connectivity, last snapshot age, content integrity, and storage usage.
# Optionally sends Telegram alert on issues.

set -euo pipefail

ALERT_THRESHOLD_HOURS="${ALERT_THRESHOLD_HOURS:-24}"  # Alert if no snapshot in X hours
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

ISSUES=()
REPORT=""

# Helper: add line to report
report() { REPORT+="$1\n"; }

# 1. Check repository connection
if kopia repository status &>/dev/null; then
  REPO_INFO=$(kopia repository status 2>/dev/null | head -5)
  REPO_TYPE=$(echo "$REPO_INFO" | grep -i "storage" | head -1 || echo "unknown")
  report "✅ Repository: connected ($REPO_TYPE)"
else
  report "❌ Repository: NOT CONNECTED"
  ISSUES+=("Repository not connected")
fi

# 2. Check last snapshot
if command -v kopia &>/dev/null && kopia repository status &>/dev/null; then
  LAST_SNAPSHOT=$(kopia snapshot list --all --json 2>/dev/null | jq -r 'sort_by(.startTime) | last | .startTime // empty' 2>/dev/null || echo "")
  
  if [ -n "$LAST_SNAPSHOT" ]; then
    LAST_TS=$(date -d "$LAST_SNAPSHOT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$LAST_SNAPSHOT" +%s 2>/dev/null || echo "0")
    NOW_TS=$(date +%s)
    AGE_HOURS=$(( (NOW_TS - LAST_TS) / 3600 ))
    
    if [ "$AGE_HOURS" -gt "$ALERT_THRESHOLD_HOURS" ]; then
      report "⚠️  Last snapshot: ${AGE_HOURS}h ago (threshold: ${ALERT_THRESHOLD_HOURS}h)"
      ISSUES+=("Last snapshot is ${AGE_HOURS}h old")
    else
      report "✅ Last snapshot: ${AGE_HOURS}h ago"
    fi
  else
    report "⚠️  No snapshots found"
    ISSUES+=("No snapshots found")
  fi

  # 3. Content verification (quick check)
  if kopia content verify --percent 5 &>/dev/null; then
    report "✅ Content integrity: OK (5% sample verified)"
  else
    report "❌ Content integrity: ERRORS DETECTED"
    ISSUES+=("Content verification failed")
  fi

  # 4. Storage stats
  STATS=$(kopia content stats 2>/dev/null || echo "")
  if [ -n "$STATS" ]; then
    TOTAL_SIZE=$(echo "$STATS" | grep -i "total" | grep -oP '[\d.]+ [KMGT]i?B' | head -1 || echo "unknown")
    report "📊 Storage used: ${TOTAL_SIZE:-unknown}"
  fi

  # 5. Snapshot count
  SNAP_COUNT=$(kopia snapshot list --all --json 2>/dev/null | jq 'length' 2>/dev/null || echo "?")
  report "📋 Total snapshots: $SNAP_COUNT"
fi

# Print report
echo -e "\n🔍 Kopia Backup Health Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "$REPORT"

# Send Telegram alert if issues found and credentials configured
if [ ${#ISSUES[@]} -gt 0 ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
  ALERT_MSG="🚨 Kopia Backup Alert\n\n"
  for issue in "${ISSUES[@]}"; do
    ALERT_MSG+="• $issue\n"
  done
  ALERT_MSG+="\nRun 'bash scripts/health-check.sh' for full report."
  
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=$(echo -e "$ALERT_MSG")" \
    -d "parse_mode=HTML" >/dev/null 2>&1 || true
  
  echo "📨 Alert sent to Telegram"
fi

# Exit with error if issues found
if [ ${#ISSUES[@]} -gt 0 ]; then
  exit 1
fi
