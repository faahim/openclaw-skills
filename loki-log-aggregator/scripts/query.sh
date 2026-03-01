#!/bin/bash
# Loki Log Aggregator — Log Query Tool
# Query logs from Loki using LogQL via HTTP API

set -euo pipefail

LOKI_URL="${LOKI_URL:-http://localhost:3100}"
QUERY="${1:-}"
LIMIT=100
SINCE=""
TAIL=false
OUTPUT="text"

if [ -z "$QUERY" ]; then
  cat <<EOF
Usage: query.sh '<LogQL query>' [options]

Options:
  --limit N     Max results (default: 100)
  --since TIME  Time range: 1h, 24h, 7d, etc. (default: 1h)
  --tail        Stream logs in real-time
  --json        Output as JSON
  --labels      List all label names
  --values KEY  List values for a label

Examples:
  query.sh '{job="systemd"}'
  query.sh '{job="systemd"} |= "error"' --since 24h
  query.sh '{job="nginx"} | json | status >= 500' --limit 20
  query.sh --labels
  query.sh --values job
EOF
  exit 0
fi

# Handle special commands
if [[ "$QUERY" == "--labels" ]]; then
  echo "📋 Available labels:"
  curl -sf "${LOKI_URL}/loki/api/v1/labels" | jq -r '.data[]' 2>/dev/null || \
    curl -sf "${LOKI_URL}/loki/api/v1/labels" | python3 -c "import sys,json; [print(l) for l in json.load(sys.stdin)['data']]" 2>/dev/null || \
    echo "❌ Could not fetch labels. Is Loki running?"
  exit 0
fi

if [[ "$QUERY" == "--values" ]]; then
  LABEL="${2:?Usage: query.sh --values <label-name>}"
  echo "📋 Values for label '${LABEL}':"
  curl -sf "${LOKI_URL}/loki/api/v1/label/${LABEL}/values" | jq -r '.data[]' 2>/dev/null || \
    echo "❌ Could not fetch values for '${LABEL}'"
  exit 0
fi

shift # Remove query from args

# Parse options
while [[ $# -gt 0 ]]; do
  case $1 in
    --limit) LIMIT="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --tail) TAIL=true; shift ;;
    --json) OUTPUT="json"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Calculate time range
NOW_NS=$(date +%s)000000000
if [ -n "$SINCE" ]; then
  # Parse duration (1h, 24h, 7d, 30m, etc.)
  NUM=$(echo "$SINCE" | sed 's/[^0-9]//g')
  UNIT=$(echo "$SINCE" | sed 's/[0-9]//g')
  case "$UNIT" in
    m) SECONDS=$((NUM * 60)) ;;
    h) SECONDS=$((NUM * 3600)) ;;
    d) SECONDS=$((NUM * 86400)) ;;
    *) SECONDS=$((NUM * 3600)) ;; # default to hours
  esac
  START_NS=$(( ($(date +%s) - SECONDS) ))000000000
else
  START_NS=$(( ($(date +%s) - 3600) ))000000000  # default 1h
fi

if $TAIL; then
  # Tail mode — use WebSocket or polling
  echo "🔴 Tailing logs (Ctrl+C to stop)..."
  echo "   Query: ${QUERY}"
  echo ""

  LAST_TS="$START_NS"
  while true; do
    ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))" 2>/dev/null || echo "$QUERY")
    RESULT=$(curl -sf "${LOKI_URL}/loki/api/v1/query_range?query=${ENCODED}&start=${LAST_TS}&limit=50&direction=forward" 2>/dev/null)

    if [ -n "$RESULT" ]; then
      if command -v jq &>/dev/null; then
        echo "$RESULT" | jq -r '.data.result[]?.values[]? | "\(.[0]) \(.[1])"' 2>/dev/null | while read -r ts line; do
          TS_SEC=${ts%000000000}
          DATE=$(date -d "@$TS_SEC" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$TS_SEC" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$ts")
          echo "[${DATE}] ${line}"
          LAST_TS="$ts"
        done
      else
        echo "$RESULT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for stream in data.get('data', {}).get('result', []):
    for ts, line in stream.get('values', []):
        print(f'[{ts}] {line}')
" 2>/dev/null
      fi
    fi
    sleep 2
  done
else
  # Regular query
  ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))" 2>/dev/null || echo "$QUERY")
  RESULT=$(curl -sf "${LOKI_URL}/loki/api/v1/query_range?query=${ENCODED}&start=${START_NS}&end=${NOW_NS}&limit=${LIMIT}&direction=backward")

  if [ -z "$RESULT" ]; then
    echo "❌ No response from Loki at ${LOKI_URL}. Is it running?"
    exit 1
  fi

  if [[ "$OUTPUT" == "json" ]]; then
    if command -v jq &>/dev/null; then
      echo "$RESULT" | jq .
    else
      echo "$RESULT"
    fi
  else
    # Pretty text output
    if command -v jq &>/dev/null; then
      COUNT=$(echo "$RESULT" | jq '[.data.result[]?.values[]?] | length')
      echo "📊 Query: ${QUERY}"
      echo "   Results: ${COUNT} (limit: ${LIMIT})"
      echo ""

      echo "$RESULT" | jq -r '
        .data.result[]? |
        .stream as $labels |
        .values[]? |
        "\(.[0]) \($labels | to_entries | map("\(.key)=\(.value)") | join(",")) \(.[1])"
      ' 2>/dev/null | sort | while read -r ts labels line; do
        TS_SEC=${ts%000000000}
        DATE=$(date -d "@$TS_SEC" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$TS_SEC" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$ts")
        echo "[${DATE}] {${labels}} ${line}"
      done
    else
      python3 -c "
import sys, json
from datetime import datetime
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
total = sum(len(s.get('values', [])) for s in results)
print(f'📊 Query: ${QUERY}')
print(f'   Results: {total} (limit: ${LIMIT})')
print()
for stream in results:
    labels = ','.join(f'{k}={v}' for k, v in stream.get('stream', {}).items())
    for ts, line in sorted(stream.get('values', [])):
        ts_sec = int(ts) // 1_000_000_000
        dt = datetime.fromtimestamp(ts_sec).strftime('%Y-%m-%d %H:%M:%S')
        print(f'[{dt}] {{{labels}}} {line}')
" <<< "$RESULT" 2>/dev/null || echo "$RESULT"
    fi
  fi
fi
