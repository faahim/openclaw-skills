#!/bin/bash
# Uptime Kuma Status Page Management
set -euo pipefail

KUMA_URL="${KUMA_URL:-http://localhost:3001}"
KUMA_USERNAME="${KUMA_USERNAME:-admin}"
KUMA_PASSWORD="${KUMA_PASSWORD:-}"

get_token() {
  if [ -z "$KUMA_PASSWORD" ]; then echo "❌ KUMA_PASSWORD not set" >&2; exit 1; fi
  curl -s "${KUMA_URL}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${KUMA_USERNAME}\",\"password\":\"${KUMA_PASSWORD}\"}" | jq -r '.token'
}

do_create() {
  local slug="" title="" description="" monitors=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --slug) slug="$2"; shift 2 ;;
      --title) title="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      --monitors) monitors="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$slug" ] && { echo "❌ --slug required"; exit 1; }
  [ -z "$title" ] && title="$slug"

  TOKEN=$(get_token)

  # Build monitor list
  local monitor_list="[]"
  if [ -n "$monitors" ]; then
    monitor_list=$(echo "$monitors" | tr ',' '\n' | jq -R 'tonumber' | jq -s '[.[] | {id: ., name: ""}]')
  fi

  local payload
  payload=$(jq -n \
    --arg slug "$slug" \
    --arg title "$title" \
    --arg desc "$description" \
    --argjson monitors "$monitor_list" \
    '{slug: $slug, title: $title, description: $desc, publicGroupList: [{name: "Services", monitorList: $monitors}]}')

  RESULT=$(curl -s "${KUMA_URL}/api/status-pages" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$payload")

  if echo "$RESULT" | jq -e '.slug' &>/dev/null; then
    echo "✅ Status page created!"
    echo "   URL: ${KUMA_URL}/status/${slug}"
  else
    echo "❌ Failed: $(echo "$RESULT" | jq -r '.msg // .error // "Unknown error"')"
  fi
}

do_list() {
  TOKEN=$(get_token)
  curl -s "${KUMA_URL}/api/status-pages" \
    -H "Authorization: Bearer $TOKEN" | jq -r '
    if type == "array" then
      .[] | "📊 \(.title) — /status/\(.slug)"
    else "No status pages"
    end
  ' 2>/dev/null || echo "No status pages found"
}

CMD="${1:-list}"
shift 2>/dev/null || true

case "$CMD" in
  create) do_create "$@" ;;
  list) do_list ;;
  *) echo "Usage: $0 <create|list> [options]" ;;
esac
