#!/bin/bash
# Manage changedetection.io watches via API
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

cmd_add() {
  local url="" interval=1800 tag="" title="" css="" xpath="" browser=false wait_s=0 ignore_texts=() ignore_regexes=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --url) url="$2"; shift 2 ;;
      --interval) interval="$2"; shift 2 ;;
      --tag) tag="$2"; shift 2 ;;
      --title) title="$2"; shift 2 ;;
      --css-filter) css="$2"; shift 2 ;;
      --xpath) xpath="$2"; shift 2 ;;
      --browser) browser=true; shift ;;
      --wait) wait_s="$2"; shift 2 ;;
      --ignore-text) ignore_texts+=("$2"); shift 2 ;;
      --ignore-regex) ignore_regexes+=("$2"); shift 2 ;;
      *) echo "Unknown: $1"; exit 1 ;;
    esac
  done

  [ -z "$url" ] && { echo "❌ --url required"; exit 1; }

  # Build JSON payload
  local minutes=$((interval / 60))
  local json
  json=$(jq -n \
    --arg url "$url" \
    --arg tag "$tag" \
    --arg title "$title" \
    --arg css "$css" \
    --arg xpath "$xpath" \
    --argjson minutes "$minutes" \
    '{
      url: $url,
      time_between_check: {minutes: $minutes},
      tags: (if $tag != "" then [$tag] else [] end),
      title: (if $title != "" then $title else $url end),
      include_filters: (
        if $css != "" then [$css]
        elif $xpath != "" then [$xpath]
        else [] end
      )
    }')

  # Add fetch_backend for browser mode
  if [ "$browser" = true ]; then
    json=$(echo "$json" | jq '. + {fetch_backend: "html_webdriver"}')
  fi

  # Add ignore text
  if [ ${#ignore_texts[@]} -gt 0 ]; then
    local ignore_joined
    ignore_joined=$(printf '%s\n' "${ignore_texts[@]}")
    json=$(echo "$json" | jq --arg ign "$ignore_joined" '. + {ignore_text: ($ign | split("\n"))}')
  fi

  local result
  result=$(api POST "/watch" -d "$json")

  local uuid
  uuid=$(echo "$result" | jq -r '.uuid // "unknown"')
  echo "✅ Added watch: $url (every ${minutes}m${tag:+, tag: $tag})"
  echo "🔑 Watch UUID: $uuid"
}

cmd_list() {
  local tag_filter=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --tag) tag_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local watches
  watches=$(api GET "/watch")

  if [ -n "$tag_filter" ]; then
    echo "$watches" | jq -r --arg tag "$tag_filter" '
      to_entries[] |
      select(.value.tags // [] | contains([$tag])) |
      "\(.key)\t\(.value.url)\t\(.value.last_changed // "never")"
    ' | column -t -s $'\t'
  else
    echo "$watches" | jq -r '
      to_entries[] |
      "\(.key)\t\(.value.url)\t\(.value.last_changed // "never")\t\(.value.tags // [] | join(","))"
    ' | column -t -s $'\t'
  fi
}

cmd_history() {
  local uuid=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --uuid) uuid="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$uuid" ] && { echo "❌ --uuid required"; exit 1; }

  api GET "/watch/${uuid}/history" | jq .
}

cmd_pause() {
  local uuid="" tag=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --uuid) uuid="$2"; shift 2 ;;
      --tag) tag="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -n "$uuid" ]; then
    api PUT "/watch/${uuid}" -d '{"paused": true}' >/dev/null
    echo "⏸️  Paused: $uuid"
  elif [ -n "$tag" ]; then
    api GET "/watch" | jq -r --arg tag "$tag" '
      to_entries[] | select(.value.tags // [] | contains([$tag])) | .key
    ' | while read -r u; do
      api PUT "/watch/${u}" -d '{"paused": true}' >/dev/null
      echo "⏸️  Paused: $u"
    done
  else
    echo "❌ --uuid or --tag required"; exit 1
  fi
}

cmd_resume() {
  local uuid="" tag=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --uuid) uuid="$2"; shift 2 ;;
      --tag) tag="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -n "$uuid" ]; then
    api PUT "/watch/${uuid}" -d '{"paused": false}' >/dev/null
    echo "▶️  Resumed: $uuid"
  elif [ -n "$tag" ]; then
    api GET "/watch" | jq -r --arg tag "$tag" '
      to_entries[] | select(.value.tags // [] | contains([$tag])) | .key
    ' | while read -r u; do
      api PUT "/watch/${u}" -d '{"paused": false}' >/dev/null
      echo "▶️  Resumed: $u"
    done
  fi
}

cmd_delete() {
  local uuid=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --uuid) uuid="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$uuid" ] && { echo "❌ --uuid required"; exit 1; }

  api DELETE "/watch/${uuid}" >/dev/null
  echo "🗑️  Deleted: $uuid"
}

cmd_recheck() {
  local uuid=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --uuid) uuid="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$uuid" ] && { echo "❌ --uuid required"; exit 1; }

  api POST "/watch/${uuid}/recheck" >/dev/null
  echo "🔄 Recheck triggered: $uuid"
}

cmd_bulk_add() {
  local file=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --file) file="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$file" ] && { echo "❌ --file required"; exit 1; }
  [ ! -f "$file" ] && { echo "❌ File not found: $file"; exit 1; }

  local count=0
  while IFS='|' read -r url interval tag; do
    [ -z "$url" ] && continue
    [[ "$url" == \#* ]] && continue
    cmd_add --url "$url" --interval "${interval:-1800}" ${tag:+--tag "$tag"}
    ((count++))
  done < "$file"
  echo ""
  echo "📊 Added $count watches"
}

cmd_export() {
  local tag="" format="json"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --tag) tag="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local watches
  watches=$(api GET "/watch")

  if [ -n "$tag" ]; then
    watches=$(echo "$watches" | jq --arg tag "$tag" '
      to_entries | map(select(.value.tags // [] | contains([$tag]))) | from_entries
    ')
  fi

  if [ "$format" = "json" ]; then
    echo "$watches" | jq .
  else
    echo "$watches" | jq -r 'to_entries[] | "\(.value.url)\t\(.value.time_between_check.minutes // 30)m\t\(.value.last_changed // "never")"'
  fi
}

# Main dispatcher
ACTION="${1:-help}"
shift || true

case "$ACTION" in
  add) cmd_add "$@" ;;
  list) cmd_list "$@" ;;
  history) cmd_history "$@" ;;
  pause) cmd_pause "$@" ;;
  resume) cmd_resume "$@" ;;
  delete) cmd_delete "$@" ;;
  recheck) cmd_recheck "$@" ;;
  bulk-add) cmd_bulk_add "$@" ;;
  export) cmd_export "$@" ;;
  *)
    echo "Usage: watch.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  add       Add a URL to watch"
    echo "  list      List all watches"
    echo "  history   Get change history for a watch"
    echo "  pause     Pause a watch (--uuid or --tag)"
    echo "  resume    Resume a watch"
    echo "  delete    Delete a watch"
    echo "  recheck   Trigger immediate recheck"
    echo "  bulk-add  Import URLs from file"
    echo "  export    Export watches as JSON"
    ;;
esac
