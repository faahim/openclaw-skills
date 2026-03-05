#!/bin/bash
# Quick terminal health check — no Docker/web UI required
# Uses smartctl directly to report drive health

set -euo pipefail

echo "Drive Health Report — $(date -u '+%Y-%m-%d %H:%M') UTC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WARNINGS=0
FAILURES=0

for dev in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
  [ -b "$dev" ] || continue

  MODEL=$(lsblk -d -n -o MODEL "$dev" 2>/dev/null | xargs || echo "Unknown")
  SIZE=$(lsblk -d -n -o SIZE "$dev" 2>/dev/null | xargs || echo "?")

  # Get S.M.A.R.T health
  HEALTH=$(sudo smartctl -H "$dev" 2>/dev/null | grep -i "result\|status" | head -1 || echo "")
  TEMP=$(sudo smartctl -A "$dev" 2>/dev/null | grep -i "temperature" | head -1 | awk '{print $(NF-1)}' || echo "?")

  # Get overall health percentage (for SSDs: wear leveling / media wearout)
  WEAR=$(sudo smartctl -A "$dev" 2>/dev/null | grep -iE "wear_leveling|media_wearout|percentage_used" | head -1 | awk '{print $NF}' || echo "")

  if echo "$HEALTH" | grep -qi "passed\|ok"; then
    STATUS="✅ PASSED"
  elif echo "$HEALTH" | grep -qi "failed"; then
    STATUS="❌ FAILED"
    ((FAILURES++))
  else
    STATUS="⚠️  UNKNOWN"
    ((WARNINGS++))
  fi

  HEALTH_PCT=""
  if [ -n "$WEAR" ] && [ "$WEAR" != "?" ]; then
    HEALTH_PCT="Health: ${WEAR}%"
  fi

  TEMP_STR=""
  if [ -n "$TEMP" ] && [ "$TEMP" != "?" ]; then
    TEMP_STR="Temp: ${TEMP}°C"

    # Warn on high temperature
    if [ "$TEMP" -gt 55 ] 2>/dev/null; then
      TEMP_STR="Temp: ${TEMP}°C ⚠️ HIGH"
      ((WARNINGS++))
    fi
  fi

  printf "%-12s %-25s %s  %s  %s\n" "$dev" "$MODEL ($SIZE)" "$STATUS" "$TEMP_STR" "$HEALTH_PCT"
done

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo "❌ CRITICAL: $FAILURES drive(s) reporting failure — BACK UP DATA IMMEDIATELY"
elif [ "$WARNINGS" -gt 0 ]; then
  echo "⚠️  Warnings: $WARNINGS — Check drives above"
else
  echo "✅ All drives healthy"
fi
