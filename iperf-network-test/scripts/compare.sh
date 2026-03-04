#!/bin/bash
# Compare network performance across multiple servers
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: bash scripts/compare.sh server1 server2 [server3 ...]"
  exit 1
fi

PORT="${IPERF_PORT:-5201}"
DURATION=10

echo "📊 Network Comparison"
echo ""

# Header
printf "┌─────────────────────────┬────────────┬────────────┬────────────┐\n"
printf "│ %-23s │ %-10s │ %-10s │ %-10s │\n" "Server" "Download" "Upload" "Jitter"
printf "├─────────────────────────┼────────────┼────────────┼────────────┤\n"

for SERVER in "$@"; do
  # Download
  DL_JSON=$(iperf3 -c "$SERVER" -p "$PORT" -t "$DURATION" -R -J 2>/dev/null || echo '{}')
  DL_MBPS=$(echo "$DL_JSON" | jq -r '.end.sum_received.bits_per_second // 0' | awk '{printf "%.0f", $1/1000000}')

  # Upload
  UL_JSON=$(iperf3 -c "$SERVER" -p "$PORT" -t "$DURATION" -J 2>/dev/null || echo '{}')
  UL_MBPS=$(echo "$UL_JSON" | jq -r '.end.sum_sent.bits_per_second // 0' | awk '{printf "%.0f", $1/1000000}')

  # Jitter
  UDP_JSON=$(iperf3 -c "$SERVER" -p "$PORT" -u -b 50M -t 5 -J 2>/dev/null || echo '{}')
  JITTER=$(echo "$UDP_JSON" | jq -r '.end.sum.jitter_ms // "N/A"' 2>/dev/null)

  DL_STR="${DL_MBPS} Mbps"
  UL_STR="${UL_MBPS} Mbps"
  JIT_STR="${JITTER} ms"

  [ "$DL_MBPS" = "0" ] && DL_STR="FAIL"
  [ "$UL_MBPS" = "0" ] && UL_STR="FAIL"

  printf "│ %-23s │ %10s │ %10s │ %10s │\n" "$SERVER" "$DL_STR" "$UL_STR" "$JIT_STR"
done

printf "└─────────────────────────┴────────────┴────────────┴────────────┘\n"
