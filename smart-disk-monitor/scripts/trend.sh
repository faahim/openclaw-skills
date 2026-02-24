#!/bin/bash
# SMART Disk Health Trend Analyzer
# Usage: bash trend.sh /path/to/smart-history.jsonl /dev/sda [--days 30]

set -euo pipefail

LOG_FILE="${1:-}"
DISK="${2:-}"
DAYS="${3:-30}"

if [[ -z "$LOG_FILE" || -z "$DISK" ]]; then
  echo "Usage: bash trend.sh <log-file.jsonl> <disk> [days]"
  exit 1
fi

if [[ ! -f "$LOG_FILE" ]]; then
  echo "❌ Log file not found: $LOG_FILE"
  exit 1
fi

CUTOFF=$(date -u -d "-${DAYS} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-${DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)

echo "═══════════════════════════════════════════════"
echo "  SMART Trend Analysis: $DISK (last $DAYS days)"
echo "═══════════════════════════════════════════════"

# Filter entries for this disk within date range
ENTRIES=$(jq -c --arg disk "$DISK" --arg cutoff "$CUTOFF" \
  'select(.disk == $disk and .timestamp >= $cutoff)' "$LOG_FILE")

COUNT=$(echo "$ENTRIES" | wc -l)
if [[ $COUNT -lt 2 ]]; then
  echo "⚠️  Not enough data points ($COUNT). Need at least 2 entries."
  exit 0
fi

echo "  Data points: $COUNT"
echo ""

# Temperature trend
TEMPS=$(echo "$ENTRIES" | jq -r '.temperature // empty' | grep -E '^[0-9]+$')
if [[ -n "$TEMPS" ]]; then
  MIN=$(echo "$TEMPS" | sort -n | head -1)
  MAX=$(echo "$TEMPS" | sort -n | tail -1)
  AVG=$(echo "$TEMPS" | awk '{s+=$1; n++} END {printf "%.0f", s/n}')
  FIRST=$(echo "$TEMPS" | head -1)
  LAST=$(echo "$TEMPS" | tail -1)
  DELTA=$((LAST - FIRST))
  [[ $DELTA -gt 0 ]] && ARROW="↗ +${DELTA}°C" || { [[ $DELTA -lt 0 ]] && ARROW="↘ ${DELTA}°C" || ARROW="→ stable"; }

  echo "Temperature:"
  echo "  Min: ${MIN}°C | Avg: ${AVG}°C | Max: ${MAX}°C | Trend: $ARROW"
  echo ""
fi

# Reallocated sectors trend
REALLOCS=$(echo "$ENTRIES" | jq -r '.reallocated // empty' | grep -E '^[0-9]+$')
if [[ -n "$REALLOCS" ]]; then
  FIRST=$(echo "$REALLOCS" | head -1)
  LAST=$(echo "$REALLOCS" | tail -1)
  DELTA=$((LAST - FIRST))
  [[ $DELTA -gt 0 ]] && ARROW="↗ +$DELTA ⚠️ GROWING" || ARROW="→ stable"

  echo "Reallocated Sectors:"
  echo "  Current: $LAST | ${DAYS}d ago: $FIRST | Trend: $ARROW"
  echo ""
fi

# Wear level trend (SSD)
WEARS=$(echo "$ENTRIES" | jq -r '.wear_level // empty' | grep -E '^[0-9]+$')
if [[ -n "$WEARS" ]]; then
  FIRST=$(echo "$WEARS" | head -1)
  LAST=$(echo "$WEARS" | tail -1)
  DELTA=$((LAST - FIRST))
  if [[ $DELTA -lt 0 ]]; then
    RATE_PER_MONTH=$(echo "scale=1; $DELTA * 30 / $DAYS" | bc 2>/dev/null || echo "?")
    [[ "$LAST" -gt 0 && "$RATE_PER_MONTH" != "?" && "$RATE_PER_MONTH" != "0" ]] && \
      LIFE_MONTHS=$(echo "scale=0; $LAST / (0 - $RATE_PER_MONTH)" | bc 2>/dev/null || echo "?") || LIFE_MONTHS="?"
    ARROW="↘ ${RATE_PER_MONTH}%/month"
  else
    ARROW="→ stable"
    LIFE_MONTHS="?"
  fi

  echo "Wear Level (SSD):"
  echo "  Current: ${LAST}% | ${DAYS}d ago: ${FIRST}% | Rate: $ARROW"
  [[ "$LIFE_MONTHS" != "?" ]] && echo "  Estimated life remaining: ~$((LIFE_MONTHS / 12)) years"
  echo ""
fi

echo "═══════════════════════════════════════════════"
