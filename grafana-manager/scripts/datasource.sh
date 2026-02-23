#!/bin/bash
# Grafana Dashboard Manager — Data Source Management
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY:-}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"

auth_header() {
  if [[ -n "$GRAFANA_API_KEY" ]]; then
    echo "Authorization: Bearer $GRAFANA_API_KEY"
  else
    echo "BASIC_AUTH"
  fi
}

api_call() {
  local method="$1" endpoint="$2" data="${3:-}"
  local auth
  auth=$(auth_header)
  local args=(-s -w "\n%{http_code}" -H "Content-Type: application/json")
  if [[ "$auth" == "BASIC_AUTH" ]]; then
    args+=(-u "${GRAFANA_USER}:${GRAFANA_PASS}")
  else
    args+=(-H "$auth")
  fi
  args+=(-X "$method" "${GRAFANA_URL}${endpoint}")
  [[ -n "$data" ]] && args+=(-d "$data")
  curl "${args[@]}"
}

cmd_add() {
  local name="" type="" url="" database="" user="" password="" access="proxy"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --url) url="$2"; shift 2 ;;
      --database) database="$2"; shift 2 ;;
      --user) user="$2"; shift 2 ;;
      --password) password="$2"; shift 2 ;;
      --access) access="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [[ -z "$name" || -z "$type" || -z "$url" ]] && {
    echo "Usage: $0 add --name NAME --type TYPE --url URL [--database DB] [--user USER] [--password PASS]"
    exit 1
  }

  local json_data
  json_data=$(jq -n \
    --arg name "$name" \
    --arg type "$type" \
    --arg url "$url" \
    --arg access "$access" \
    --arg database "$database" \
    --arg user "$user" \
    --arg password "$password" \
    '{
      name: $name,
      type: $type,
      url: $url,
      access: $access,
      jsonData: {},
      secureJsonData: {}
    } + (if $database != "" then {database: $database} else {} end)
      + (if $user != "" then {user: $user} else {} end)
      + (if $password != "" then {secureJsonData: {password: $password}} else {} end)')

  local response
  response=$(api_call POST "/api/datasources" "$json_data")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    local id
    id=$(echo "$body" | jq -r '.datasource.id // .id // "unknown"')
    echo "✅ Data source '$name' added (id: $id)"
  else
    echo "❌ Failed to add data source: $body"
    exit 1
  fi
}

cmd_list() {
  local response
  response=$(api_call GET "/api/datasources")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "$body" | jq -r '.[] | "[\(.id)] \(.name) (\(.type)) → \(.url)"'
    local count
    count=$(echo "$body" | jq '. | length')
    echo "---"
    echo "Total: $count data source(s)"
  else
    echo "❌ Failed to list data sources: $body"
    exit 1
  fi
}

cmd_delete() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [[ -z "$name" ]] && { echo "Usage: $0 delete --name NAME"; exit 1; }

  local response
  response=$(api_call DELETE "/api/datasources/name/${name}")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "✅ Data source '$name' deleted"
  else
    echo "❌ Failed to delete data source '$name': $body"
    exit 1
  fi
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  add) cmd_add "$@" ;;
  list) cmd_list ;;
  delete) cmd_delete "$@" ;;
  *)
    echo "Usage: $0 {add|list|delete} [options]"
    echo ""
    echo "Commands:"
    echo "  add     Add a data source (--name, --type, --url, --database, --user, --password)"
    echo "  list    List all data sources"
    echo "  delete  Delete a data source (--name)"
    exit 1
    ;;
esac
