#!/bin/bash
# Gradual ramp-up load test — find the breaking point
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

URL=""
START=10
END=200
STEP=10
STEP_DURATION=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    --start) START="$2"; shift 2 ;;
    --end) END="$2"; shift 2 ;;
    --step) STEP="$2"; shift 2 ;;
    --step-duration) STEP_DURATION="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$URL" ]; then
  echo "Error: --url is required"
  exit 1
fi

echo "🔥 Ramp-Up Load Test: $URL"
echo "   Range: $START → $END (step: $STEP, ${STEP_DURATION}s each)"
echo ""
printf "%-12s %-10s %-10s %-10s\n" "Concurrency" "RPS" "p95" "Errors"
printf "%-12s %-10s %-10s %-10s\n" "───────────" "──────" "──────" "──────"

PREV_RPS=0
BREAKING_POINT=""

for c in $(seq "$START" "$STEP" "$END"); do
  RESULT=$(bash "$SCRIPT_DIR/run.sh" --url "$URL" -c "$c" -d "$STEP_DURATION" --json 2>/dev/null)
  
  RPS=$(echo "$RESULT" | jq -r '.rps' 2>/dev/null || echo "0")
  P95=$(echo "$RESULT" | jq -r '.latency.p95_ms' 2>/dev/null || echo "0")
  ERRS=$(echo "$RESULT" | jq -r '.errors' 2>/dev/null || echo "0")
  SR=$(echo "$RESULT" | jq -r '.success_rate' 2>/dev/null || echo "100")
  
  # Detect degradation
  MARKER=""
  if [ -n "$PREV_RPS" ] && [ "$PREV_RPS" != "0" ]; then
    RPS_INT=$(printf "%.0f" "$RPS" 2>/dev/null || echo "0")
    PREV_INT=$(printf "%.0f" "$PREV_RPS" 2>/dev/null || echo "0")
    if [ "$RPS_INT" -lt "$PREV_INT" ] 2>/dev/null || [ "$(echo "$SR < 99" | bc 2>/dev/null)" = "1" ]; then
      MARKER=" ← DEGRADATION"
      if [ -z "$BREAKING_POINT" ]; then
        BREAKING_POINT=$((c - STEP))
      fi
    fi
  fi
  
  printf "%-12s %-10s %-10s %-10s%s\n" "$c" "${RPS}" "${P95}ms" "${ERRS}" "$MARKER"
  PREV_RPS="$RPS"
done

echo ""
if [ -n "$BREAKING_POINT" ]; then
  echo "⚠️  Recommended max concurrency: ~$BREAKING_POINT"
else
  echo "✅ No degradation detected up to $END concurrent connections"
fi
