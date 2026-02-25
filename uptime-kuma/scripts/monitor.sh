#!/bin/bash
# Uptime Kuma Monitor Management
set -euo pipefail

KUMA_URL="${KUMA_URL:-http://localhost:3001}"
KUMA_USERNAME="${KUMA_USERNAME:-admin}"
KUMA_PASSWORD="${KUMA_PASSWORD:-}"

# Get auth token
get_token() {
  if [ -z "$KUMA_PASSWORD" ]; then
    echo "❌ KUMA_PASSWORD not set" >&2
    exit 1
  fi
  curl -s "${KUMA_URL}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${KUMA_USERNAME}\",\"password\":\"${KUMA_PASSWORD}\"}" \
    | jq -r '.token'
}

usage() {
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Commands:"
  echo "  add       Add a new monitor"
  echo "  list      List all monitors"
  echo "  pause     Pause a monitor"
  echo "  resume    Resume a monitor"
  echo "  delete    Delete a monitor"
  echo "  import    Import monitors from YAML"
  echo ""
  echo "Add Options:"
  echo "  --name NAME           Monitor name (required)"
  echo "  --url URL             URL to monitor"
  echo "  --type TYPE           Monitor type: http|port|ping|keyword|dns|docker|push"
  echo "  --interval SECONDS    Check interval (default: 60)"
  echo "  --retry COUNT         Retry count (default: 3)"
  echo "  --hostname HOST       Hostname (for port/ping/dns)"
  echo "  --port PORT           Port number (for port type)"
  echo "  --keyword TEXT        Keyword to search (for keyword type)"
  echo "  --expected-status N   Expected HTTP status (default: 200)"
  echo "  --dns-resolver IP     DNS resolver (for dns type)"
  echo "  --ssl-expiry-days N   Alert N days before SSL expiry"
}

do_add() {
  local name="" url="" type="http" interval=60 retry=3
  local hostname="" port="" keyword="" expected_status=200
  local dns_resolver="" ssl_expiry_days=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --url) url="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --interval) interval="$2"; shift 2 ;;
      --retry) retry="$2"; shift 2 ;;
      --hostname) hostname="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --keyword) keyword="$2"; shift 2 ;;
      --expected-status) expected_status="$2"; shift 2 ;;
      --dns-resolver) dns_resolver="$2"; shift 2 ;;
      --ssl-expiry-days) ssl_expiry_days="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$name" ]; then
    echo "❌ --name is required"
    exit 1
  fi

  TOKEN=$(get_token)
  
  # Build JSON payload
  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg type "$type" \
    --argjson interval "$interval" \
    --argjson retry "$retry" \
    --argjson expected_status "$expected_status" \
    '{
      name: $name,
      type: $type,
      interval: $interval,
      maxretries: $retry,
      accepted_statuscodes: [$expected_status | tostring]
    }')

  # Add type-specific fields
  case "$type" in
    http|keyword)
      payload=$(echo "$payload" | jq --arg url "$url" '. + {url: $url}')
      if [ "$type" = "keyword" ] && [ -n "$keyword" ]; then
        payload=$(echo "$payload" | jq --arg kw "$keyword" '. + {keyword: $kw}')
      fi
      ;;
    port)
      payload=$(echo "$payload" | jq --arg h "$hostname" --argjson p "${port:-80}" '. + {hostname: $h, port: $p}')
      ;;
    ping)
      payload=$(echo "$payload" | jq --arg h "$hostname" '. + {hostname: $h}')
      ;;
    dns)
      payload=$(echo "$payload" | jq --arg h "$hostname" --arg r "${dns_resolver:-8.8.8.8}" '. + {hostname: $h, dns_resolve_server: $r}')
      ;;
  esac

  # Add SSL expiry notification
  if [ -n "$ssl_expiry_days" ]; then
    payload=$(echo "$payload" | jq --argjson days "$ssl_expiry_days" '. + {expiryNotification: true, tlsExpiryNotifyDays: $days}')
  fi

  RESULT=$(curl -s "${KUMA_URL}/api/monitors" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$payload")

  if echo "$RESULT" | jq -e '.id' &>/dev/null; then
    local mid
    mid=$(echo "$RESULT" | jq -r '.id')
    echo "✅ Monitor added: ${name} (ID: ${mid})"
  else
    echo "❌ Failed: $(echo "$RESULT" | jq -r '.msg // .error // "Unknown error"')"
    exit 1
  fi
}

do_list() {
  TOKEN=$(get_token)
  
  MONITORS=$(curl -s "${KUMA_URL}/api/monitors" \
    -H "Authorization: Bearer $TOKEN")

  echo "$MONITORS" | jq -r '
    if type == "array" then
      ["ID", "Name", "Type", "Status", "URL/Host"],
      (.[] | [
        (.id | tostring),
        .name,
        .type,
        (if .active then "✅ Active" else "⏸ Paused" end),
        (.url // .hostname // "-")
      ]) | @tsv
    elif type == "object" and has("monitors") then
      ["ID", "Name", "Type", "Status", "URL/Host"],
      (.monitors[] | [
        (.id | tostring),
        .name,
        .type,
        (if .active then "✅ Active" else "⏸ Paused" end),
        (.url // .hostname // "-")
      ]) | @tsv
    else
      "No monitors found"
    end
  ' 2>/dev/null | column -t -s$'\t' || echo "No monitors found or API error"
}

do_pause() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case $1 in --id) id="$2"; shift 2 ;; *) shift ;; esac
  done
  [ -z "$id" ] && { echo "❌ --id required"; exit 1; }
  
  TOKEN=$(get_token)
  curl -s "${KUMA_URL}/api/monitors/${id}/pause" \
    -X POST \
    -H "Authorization: Bearer $TOKEN" | jq .
  echo "⏸ Monitor ${id} paused"
}

do_resume() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case $1 in --id) id="$2"; shift 2 ;; *) shift ;; esac
  done
  [ -z "$id" ] && { echo "❌ --id required"; exit 1; }
  
  TOKEN=$(get_token)
  curl -s "${KUMA_URL}/api/monitors/${id}/resume" \
    -X POST \
    -H "Authorization: Bearer $TOKEN" | jq .
  echo "✅ Monitor ${id} resumed"
}

do_delete() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case $1 in --id) id="$2"; shift 2 ;; *) shift ;; esac
  done
  [ -z "$id" ] && { echo "❌ --id required"; exit 1; }
  
  TOKEN=$(get_token)
  curl -s "${KUMA_URL}/api/monitors/${id}" \
    -X DELETE \
    -H "Authorization: Bearer $TOKEN" | jq .
  echo "🗑️ Monitor ${id} deleted"
}

do_import() {
  local config=""
  while [[ $# -gt 0 ]]; do
    case $1 in --config) config="$2"; shift 2 ;; *) shift ;; esac
  done
  [ -z "$config" ] && { echo "❌ --config required"; exit 1; }
  [ ! -f "$config" ] && { echo "❌ File not found: $config"; exit 1; }

  if ! command -v yq &>/dev/null; then
    echo "❌ yq required for YAML parsing. Install: pip install yq"
    exit 1
  fi

  local count=0
  while IFS= read -r line; do
    local name url type hostname port interval keyword
    name=$(echo "$line" | jq -r '.name')
    url=$(echo "$line" | jq -r '.url // empty')
    type=$(echo "$line" | jq -r '.type // "http"')
    hostname=$(echo "$line" | jq -r '.hostname // empty')
    port=$(echo "$line" | jq -r '.port // empty')
    interval=$(echo "$line" | jq -r '.interval // 60')
    keyword=$(echo "$line" | jq -r '.keyword // empty')

    local args=(--name "$name" --type "$type" --interval "$interval")
    [ -n "$url" ] && args+=(--url "$url")
    [ -n "$hostname" ] && args+=(--hostname "$hostname")
    [ -n "$port" ] && args+=(--port "$port")
    [ -n "$keyword" ] && args+=(--keyword "$keyword")

    do_add "${args[@]}" && ((count++)) || true
  done < <(yq -c '.monitors[]' "$config")

  echo ""
  echo "📊 Imported ${count} monitors"
}

# Main
CMD="${1:-list}"
shift 2>/dev/null || true

case "$CMD" in
  add) do_add "$@" ;;
  list) do_list ;;
  pause) do_pause "$@" ;;
  resume) do_resume "$@" ;;
  delete) do_delete "$@" ;;
  import) do_import "$@" ;;
  -h|--help) usage ;;
  *) usage; exit 1 ;;
esac
