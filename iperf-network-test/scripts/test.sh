#!/bin/bash
# Run iperf3 test with configurable options
set -euo pipefail

# Defaults
SERVER="${IPERF_DEFAULT_SERVER:-}"
PORT="${IPERF_PORT:-5201}"
DURATION="${IPERF_DURATION:-10}"
PARALLEL=1
UDP=false
BANDWIDTH="0"
REVERSE=false
BIDIR=false
WINDOW=""
INTERVAL=1
REPORT=false
REPORTS_DIR="${IPERF_REPORTS_DIR:-./reports}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --server|-s) SERVER="$2"; shift 2 ;;
    --port|-p) PORT="$2"; shift 2 ;;
    --duration|-t) DURATION="$2"; shift 2 ;;
    --parallel|-P) PARALLEL="$2"; shift 2 ;;
    --udp|-u) UDP=true; shift ;;
    --bandwidth|-b) BANDWIDTH="$2"; shift 2 ;;
    --reverse|-R) REVERSE=true; shift ;;
    --bidir) BIDIR=true; shift ;;
    --window|-w) WINDOW="$2"; shift 2 ;;
    --interval|-i) INTERVAL="$2"; shift 2 ;;
    --report) REPORT=true; shift ;;
    --help|-h)
      echo "Usage: bash scripts/test.sh --server <host> [options]"
      echo ""
      echo "Options:"
      echo "  --server, -s    Target iperf3 server (required)"
      echo "  --port, -p      Server port (default: 5201)"
      echo "  --duration, -t  Test duration in seconds (default: 10)"
      echo "  --parallel, -P  Number of parallel streams (default: 1)"
      echo "  --udp, -u       Use UDP instead of TCP"
      echo "  --bandwidth, -b UDP target bandwidth (e.g., 100M)"
      echo "  --reverse, -R   Reverse mode (server sends to client)"
      echo "  --bidir         Bidirectional test"
      echo "  --window, -w    TCP window size (e.g., 256K)"
      echo "  --interval, -i  Report interval in seconds (default: 1)"
      echo "  --report        Save JSON report to reports/"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$SERVER" ]; then
  echo "❌ No server specified."
  echo "   Usage: bash scripts/test.sh --server <host>"
  echo "   Or set: export IPERF_DEFAULT_SERVER=your-server.com"
  exit 1
fi

# Build iperf3 command
CMD="iperf3 -c $SERVER -p $PORT -t $DURATION -P $PARALLEL -i $INTERVAL"

$UDP && CMD="$CMD -u -b $BANDWIDTH"
$REVERSE && CMD="$CMD -R"
$BIDIR && CMD="$CMD --bidir"
[ -n "$WINDOW" ] && CMD="$CMD -w $WINDOW"

PROTO="TCP"
$UDP && PROTO="UDP"

echo "🔗 ${PROTO} Test: → ${SERVER}:${PORT}"
echo "⏱️  Duration: ${DURATION}s | Streams: ${PARALLEL}"
$BIDIR && echo "↔️  Bidirectional mode"
$REVERSE && echo "⬇️  Reverse mode (server → client)"
echo ""

if $REPORT; then
  mkdir -p "$REPORTS_DIR"
  REPORT_FILE="${REPORTS_DIR}/test-$(date +%Y-%m-%d-%H%M%S).json"
  $CMD -J > "$REPORT_FILE" 2>&1
  echo "💾 JSON report saved: $REPORT_FILE"
  echo ""
  # Print summary from JSON
  if command -v jq &>/dev/null; then
    SENT=$(jq -r '.end.sum_sent.bits_per_second // 0' "$REPORT_FILE" | awk '{printf "%.1f", $1/1000000}')
    RECV=$(jq -r '.end.sum_received.bits_per_second // 0' "$REPORT_FILE" | awk '{printf "%.1f", $1/1000000}')
    echo "📋 Summary: Sent ${SENT} Mbps | Received ${RECV} Mbps"
  fi
else
  $CMD
fi
