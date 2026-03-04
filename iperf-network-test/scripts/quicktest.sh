#!/bin/bash
# Quick bandwidth test against public iperf3 servers
set -euo pipefail

# Public iperf3 servers (tested regularly)
SERVERS=(
  "bouygues.iperf.fr"
  "iperf.he.net"
  "speedtest.wtnet.de"
  "iperf.scottlinux.com"
)

echo "🌐 iperf3 Quick Network Test"
echo "=============================="

# Try servers until one works
SERVER=""
for s in "${SERVERS[@]}"; do
  if timeout 3 bash -c "echo >/dev/tcp/$s/5201" 2>/dev/null; then
    SERVER="$s"
    break
  fi
done

if [ -z "$SERVER" ]; then
  echo "❌ No public iperf3 servers reachable."
  echo "   Check your internet connection or specify a server:"
  echo "   bash scripts/test.sh --server your-server.com"
  exit 1
fi

echo "Server: $SERVER (public)"
echo ""

# TCP Download test (reverse = server sends to us)
echo "⬇️  Testing download..."
DL_RESULT=$(iperf3 -c "$SERVER" -R -t 10 -J 2>/dev/null || echo '{}')
DL_MBPS=$(echo "$DL_RESULT" | jq -r '.end.sum_received.bits_per_second // 0' 2>/dev/null | awk '{printf "%.1f", $1/1000000}')

# TCP Upload test
echo "⬆️  Testing upload..."
UL_RESULT=$(iperf3 -c "$SERVER" -t 10 -J 2>/dev/null || echo '{}')
UL_MBPS=$(echo "$UL_RESULT" | jq -r '.end.sum_sent.bits_per_second // 0' 2>/dev/null | awk '{printf "%.1f", $1/1000000}')

# UDP jitter test
echo "📊 Testing jitter..."
UDP_RESULT=$(iperf3 -c "$SERVER" -u -b 50M -t 5 -J 2>/dev/null || echo '{}')
JITTER=$(echo "$UDP_RESULT" | jq -r '.end.sum.jitter_ms // "N/A"' 2>/dev/null)
LOSS=$(echo "$UDP_RESULT" | jq -r '.end.sum.lost_percent // "N/A"' 2>/dev/null)

echo ""
echo "📋 Results"
echo "────────────────────────"
echo "⬇️  Download: ${DL_MBPS} Mbits/sec"
echo "⬆️  Upload:   ${UL_MBPS} Mbits/sec"
echo "📊 Jitter:   ${JITTER} ms"
echo "📦 Loss:     ${LOSS}%"
echo ""

# Save result
REPORTS_DIR="${IPERF_REPORTS_DIR:-./reports}"
mkdir -p "$REPORTS_DIR"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "${TIMESTAMP},${SERVER},${DL_MBPS},${UL_MBPS},${JITTER},${LOSS}" >> "${REPORTS_DIR}/quicktest.csv"
echo "💾 Saved to ${REPORTS_DIR}/quicktest.csv"
