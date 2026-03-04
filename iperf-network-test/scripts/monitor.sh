#!/bin/bash
# Scheduled bandwidth monitoring — run periodically and log results
set -euo pipefail

SERVER="${IPERF_DEFAULT_SERVER:-}"
PORT="${IPERF_PORT:-5201}"
INTERVAL=3600
LOGFILE=""
DURATION=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --server|-s) SERVER="$2"; shift 2 ;;
    --interval|-i) INTERVAL="$2"; shift 2 ;;
    --logfile|-l) LOGFILE="$2"; shift 2 ;;
    --duration|-t) DURATION="$2"; shift 2 ;;
    --port|-p) PORT="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [ -z "$SERVER" ]; then
  echo "❌ No server specified. Usage: bash scripts/monitor.sh --server <host>"
  exit 1
fi

REPORTS_DIR="${IPERF_REPORTS_DIR:-./reports}"
mkdir -p "$REPORTS_DIR"
LOGFILE="${LOGFILE:-${REPORTS_DIR}/monitor-$(date +%Y%m%d).csv}"

# Write CSV header if new file
if [ ! -f "$LOGFILE" ]; then
  echo "timestamp,server,download_mbps,upload_mbps,jitter_ms,loss_pct" > "$LOGFILE"
fi

echo "📊 iperf3 Monitor"
echo "  Server:   ${SERVER}:${PORT}"
echo "  Interval: ${INTERVAL}s"
echo "  Log:      ${LOGFILE}"
echo "  Press Ctrl+C to stop"
echo ""

while true; do
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Download (reverse)
  DL_JSON=$(iperf3 -c "$SERVER" -p "$PORT" -t "$DURATION" -R -J 2>/dev/null || echo '{}')
  DL_MBPS=$(echo "$DL_JSON" | jq -r '.end.sum_received.bits_per_second // 0' | awk '{printf "%.1f", $1/1000000}')

  # Upload
  UL_JSON=$(iperf3 -c "$SERVER" -p "$PORT" -t "$DURATION" -J 2>/dev/null || echo '{}')
  UL_MBPS=$(echo "$UL_JSON" | jq -r '.end.sum_sent.bits_per_second // 0' | awk '{printf "%.1f", $1/1000000}')

  # UDP jitter
  UDP_JSON=$(iperf3 -c "$SERVER" -p "$PORT" -u -b 50M -t 5 -J 2>/dev/null || echo '{}')
  JITTER=$(echo "$UDP_JSON" | jq -r '.end.sum.jitter_ms // 0' 2>/dev/null)
  LOSS=$(echo "$UDP_JSON" | jq -r '.end.sum.lost_percent // 0' 2>/dev/null)

  # Log
  echo "${TIMESTAMP},${SERVER},${DL_MBPS},${UL_MBPS},${JITTER},${LOSS}" >> "$LOGFILE"
  echo "[${TIMESTAMP}] ⬇️ ${DL_MBPS} Mbps | ⬆️ ${UL_MBPS} Mbps | Jitter: ${JITTER}ms | Loss: ${LOSS}%"

  sleep "$INTERVAL"
done
