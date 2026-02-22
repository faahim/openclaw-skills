#!/bin/bash
# HTTP Load Tester — main runner script
set -o pipefail

# Defaults
URL=""
CONCURRENCY=10
REQUESTS=""
DURATION=10
METHOD="GET"
BODY=""
CONTENT_TYPE="application/json"
HEADERS=()
TIMEOUT="${LOADTEST_TIMEOUT:-10}"
REPORT=""
JSON_OUTPUT=false
TOOL="${LOADTEST_TOOL:-auto}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    -c|--concurrency) CONCURRENCY="$2"; shift 2 ;;
    -n|--requests) REQUESTS="$2"; shift 2 ;;
    -d|--duration) DURATION="$2"; shift 2 ;;
    -m|--method) METHOD="$2"; shift 2 ;;
    -b|--body) BODY="$2"; shift 2 ;;
    --content-type) CONTENT_TYPE="$2"; shift 2 ;;
    -H|--header) HEADERS+=("$2"); shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -r|--report) REPORT="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --tool) TOOL="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$URL" ]; then
  echo "Error: --url is required"
  echo "Usage: bash run.sh --url https://example.com [-c 10] [-d 30]"
  exit 1
fi

# Auto-detect tool
detect_tool() {
  if [ "$TOOL" != "auto" ]; then
    if command -v "$TOOL" &>/dev/null; then echo "$TOOL"; return; fi
    echo "Error: Requested tool '$TOOL' not found" >&2; exit 1
  fi
  for t in hey ab wrk; do
    if command -v "$t" &>/dev/null; then echo "$t"; return; fi
  done
  echo "Error: No load testing tool found. Run: bash scripts/install.sh" >&2; exit 1
}

SELECTED_TOOL=$(detect_tool)
RAW_OUTPUT=$(mktemp)
trap "rm -f $RAW_OUTPUT" EXIT

run_ab() {
  local args=("-c" "$CONCURRENCY" "-s" "$TIMEOUT")
  if [ -n "$REQUESTS" ]; then
    args+=("-n" "$REQUESTS")
  else
    args+=("-t" "$DURATION" "-n" "999999999")
  fi
  if [ "$METHOD" != "GET" ] && [ -n "$BODY" ]; then
    local bodyfile=$(mktemp)
    echo -n "$BODY" > "$bodyfile"
    args+=("-p" "$bodyfile" "-T" "$CONTENT_TYPE")
  fi
  for h in "${HEADERS[@]+"${HEADERS[@]}"}"; do
    [ -n "$h" ] && args+=("-H" "$h")
  done
  ab "${args[@]}" "$URL" > "$RAW_OUTPUT" 2>&1 || true
  [ -n "${bodyfile:-}" ] && rm -f "$bodyfile"
}

run_hey() {
  local args=("-c" "$CONCURRENCY" "-t" "$TIMEOUT")
  if [ -n "$REQUESTS" ]; then
    args+=("-n" "$REQUESTS")
  else
    args+=("-z" "${DURATION}s")
  fi
  args+=("-m" "$METHOD")
  if [ -n "$BODY" ]; then
    args+=("-d" "$BODY" "-T" "$CONTENT_TYPE")
  fi
  for h in "${HEADERS[@]+"${HEADERS[@]}"}"; do
    [ -n "$h" ] && args+=("-H" "$h")
  done
  hey "${args[@]}" "$URL" > "$RAW_OUTPUT" 2>&1 || true
}

echo "🔥 Running load test..." >&2
echo "   Tool: $SELECTED_TOOL | Target: $URL" >&2
echo "   Concurrency: $CONCURRENCY | ${REQUESTS:+Requests: $REQUESTS}${REQUESTS:-Duration: ${DURATION}s}" >&2
echo "" >&2

case "$SELECTED_TOOL" in
  hey) run_hey ;;
  ab) run_ab ;;
  *) echo "Unsupported tool: $SELECTED_TOOL"; exit 1 ;;
esac

# Parse ab output
parse_ab() {
  TOTAL_REQS=$(grep "Complete requests:" "$RAW_OUTPUT" | awk '{print $NF}') || TOTAL_REQS=0
  RPS=$(grep "Requests per second:" "$RAW_OUTPUT" | awk '{print $4}') || RPS=0
  ERRORS=$(grep "Failed requests:" "$RAW_OUTPUT" | awk '{print $NF}') || ERRORS=0
  P50=$(grep "50%" "$RAW_OUTPUT" | awk '{print $2}') || P50=0
  P95=$(grep "95%" "$RAW_OUTPUT" | awk '{print $2}') || P95=0
  P99=$(grep "99%" "$RAW_OUTPUT" | awk '{print $2}') || P99=0
}

# Parse hey output  
parse_hey() {
  RPS=$(grep "Requests/sec:" "$RAW_OUTPUT" | awk '{print $2}') || RPS=0
  TOTAL_REQS=$(grep -A1 "Status code distribution:" "$RAW_OUTPUT" | grep -o '[0-9]*$' | awk '{s+=$1}END{print s}') || TOTAL_REQS=0
  ERRORS=0
  # hey reports latency in seconds at percentile lines
  P50=$(grep "50% in" "$RAW_OUTPUT" | awk '{printf "%.0f", $3*1000}') || P50=0
  P95=$(grep "95% in" "$RAW_OUTPUT" | awk '{printf "%.0f", $3*1000}') || P95=0
  P99=$(grep "99% in" "$RAW_OUTPUT" | awk '{printf "%.0f", $3*1000}') || P99=0
}

TOTAL_REQS=0; RPS=0; P50=0; P95=0; P99=0; ERRORS=0

case "$SELECTED_TOOL" in
  ab) parse_ab ;;
  hey) parse_hey ;;
esac

# Success rate
if [ "${TOTAL_REQS:-0}" -gt 0 ] 2>/dev/null && [ "${ERRORS:-0}" -gt 0 ] 2>/dev/null; then
  SUCCESS_RATE=$(awk "BEGIN{printf \"%.1f\", ($TOTAL_REQS - $ERRORS) * 100 / $TOTAL_REQS}")
else
  SUCCESS_RATE="100.0"
fi

if [ "$JSON_OUTPUT" = true ]; then
  cat <<EOF
{
  "url": "$URL",
  "tool": "$SELECTED_TOOL",
  "concurrency": $CONCURRENCY,
  "total_requests": ${TOTAL_REQS:-0},
  "rps": ${RPS:-0},
  "success_rate": ${SUCCESS_RATE},
  "latency": {
    "p50_ms": ${P50:-0},
    "p95_ms": ${P95:-0},
    "p99_ms": ${P99:-0}
  },
  "errors": ${ERRORS:-0}
}
EOF
else
  cat <<EOF
═══════════════════════════════════════════════════
  HTTP Load Test Report
  Target: $URL
  Tool: $SELECTED_TOOL
  Concurrency: $CONCURRENCY
═══════════════════════════════════════════════════

  Total Requests:    ${TOTAL_REQS:-0}
  Requests/sec:      ${RPS:-0}
  Success Rate:      ${SUCCESS_RATE}%

  Latency:
    p50:   ${P50:-0}ms
    p95:   ${P95:-0}ms
    p99:   ${P99:-0}ms

  Errors:            ${ERRORS:-0}
═══════════════════════════════════════════════════
EOF
fi | if [ -n "$REPORT" ]; then
  tee "$REPORT"
  echo "📄 Report saved to: $REPORT" >&2
else
  cat
fi
