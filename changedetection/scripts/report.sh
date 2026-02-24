#!/bin/bash
# Generate change detection report
set -euo pipefail

BASE_URL="${CHANGEDETECTION_URL:-http://localhost:5000}"
API_KEY="${CHANGEDETECTION_API_KEY:-}"

api() {
  local method="$1" endpoint="$2"
  shift 2
  local headers=(-H "Content-Type: application/json")
  [ -n "$API_KEY" ] && headers+=(-H "x-api-key: $API_KEY")
  curl -s -X "$method" "${BASE_URL}/api/v1${endpoint}" "${headers[@]}" "$@"
}

FORMAT="${1:-summary}"

watches=$(api GET "/watch")
total=$(echo "$watches" | jq 'length')
changed=$(echo "$watches" | jq '[to_entries[] | select(.value.last_changed != null and .value.last_changed != 0)] | length')
paused=$(echo "$watches" | jq '[to_entries[] | select(.value.paused == true)] | length')

echo "📊 Changedetection Report"
echo "========================="
echo "Total watches: $total"
echo "With changes:  $changed"
echo "Paused:        $paused"
echo ""

if [ "$FORMAT" = "detail" ]; then
  echo "Recent changes:"
  echo "$watches" | jq -r '
    to_entries |
    sort_by(.value.last_changed // 0) |
    reverse |
    .[:10][] |
    "  \(.value.last_changed // "never") | \(.value.url) | \(.value.tags // [] | join(","))"
  '
fi
