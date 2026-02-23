#!/bin/bash
# Grafana Dashboard Manager — Dashboard Management
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

cmd_import() {
  local dash_id="" file="" datasource=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id) dash_id="$2"; shift 2 ;;
      --file) file="$2"; shift 2 ;;
      --datasource) datasource="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  local dashboard_json

  if [[ -n "$dash_id" ]]; then
    # Fetch from Grafana.com
    echo "⬇️  Fetching dashboard $dash_id from Grafana.com..."
    dashboard_json=$(curl -s "https://grafana.com/api/dashboards/${dash_id}/revisions/latest/download")
    if [[ -z "$dashboard_json" || "$dashboard_json" == "null" ]]; then
      echo "❌ Failed to fetch dashboard $dash_id from Grafana.com"
      exit 1
    fi
  elif [[ -n "$file" ]]; then
    dashboard_json=$(cat "$file")
  else
    echo "Usage: $0 import --id GRAFANA_COM_ID [--datasource NAME]"
    echo "       $0 import --file PATH [--datasource NAME]"
    exit 1
  fi

  # Build import payload
  local inputs="[]"
  if [[ -n "$datasource" ]]; then
    # Auto-detect required inputs from __inputs
    local input_names
    input_names=$(echo "$dashboard_json" | jq -r '.__inputs[]?.name // empty' 2>/dev/null || true)
    if [[ -n "$input_names" ]]; then
      inputs=$(echo "$dashboard_json" | jq --arg ds "$datasource" '[.__inputs[] | {name: .name, type: .type, pluginId: .pluginId, value: $ds}]' 2>/dev/null || echo "[]")
    fi
  fi

  local payload
  payload=$(jq -n \
    --argjson dashboard "$dashboard_json" \
    --argjson inputs "$inputs" \
    '{
      dashboard: $dashboard,
      inputs: $inputs,
      overwrite: true,
      folderId: 0
    }')

  # Remove id to avoid conflicts
  payload=$(echo "$payload" | jq '.dashboard.id = null')

  local response
  response=$(api_call POST "/api/dashboards/import" "$payload")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    local title uid slug
    title=$(echo "$body" | jq -r '.title // "Unknown"')
    uid=$(echo "$body" | jq -r '.dashboardId // .uid // "unknown"')
    slug=$(echo "$body" | jq -r '.slug // ""')
    echo "✅ Dashboard '${title}' imported (uid: ${uid})"
    echo "🔗 ${GRAFANA_URL}/d/${uid}/${slug}"
  else
    echo "❌ Failed to import dashboard: $body"
    exit 1
  fi
}

cmd_export() {
  local uid=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --uid) uid="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [[ -z "$uid" ]] && { echo "Usage: $0 export --uid DASHBOARD_UID"; exit 1; }

  local response
  response=$(api_call GET "/api/dashboards/uid/${uid}")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "$body" | jq '.dashboard'
  else
    echo "❌ Failed to export dashboard: $body" >&2
    exit 1
  fi
}

cmd_list() {
  local response
  response=$(api_call GET "/api/search?type=dash-db&limit=100")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "$body" | jq -r '.[] | "[\(.uid)] \(.title) (folder: \(.folderTitle // "General"))"'
    local count
    count=$(echo "$body" | jq '. | length')
    echo "---"
    echo "Total: $count dashboard(s)"
  else
    echo "❌ Failed to list dashboards: $body"
    exit 1
  fi
}

cmd_delete() {
  local uid=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --uid) uid="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [[ -z "$uid" ]] && { echo "Usage: $0 delete --uid DASHBOARD_UID"; exit 1; }

  local response
  response=$(api_call DELETE "/api/dashboards/uid/${uid}")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "✅ Dashboard '${uid}' deleted"
  else
    echo "❌ Failed to delete dashboard: $body"
    exit 1
  fi
}

cmd_search() {
  local query=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --query) query="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  local response
  response=$(api_call GET "/api/search?type=dash-db&query=${query}&limit=50")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "$body" | jq -r '.[] | "[\(.uid)] \(.title)"'
  else
    echo "❌ Search failed: $body"
    exit 1
  fi
}

cmd_backup() {
  local dir="./grafana-backups"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dir) dir="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  mkdir -p "$dir"
  local response
  response=$(api_call GET "/api/search?type=dash-db&limit=500")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    echo "❌ Failed to list dashboards: $body"
    exit 1
  fi

  local count=0
  for uid in $(echo "$body" | jq -r '.[].uid'); do
    local dash_response
    dash_response=$(api_call GET "/api/dashboards/uid/${uid}")
    local dash_code dash_body
    dash_code=$(echo "$dash_response" | tail -1)
    dash_body=$(echo "$dash_response" | sed '$d')

    if [[ "$dash_code" == "200" ]]; then
      local title
      title=$(echo "$dash_body" | jq -r '.dashboard.title' | tr ' /' '-_')
      echo "$dash_body" | jq '.dashboard' > "${dir}/${uid}-${title}.json"
      echo "📁 Backed up: ${title}"
      count=$((count + 1))
    fi
  done
  echo "---"
  echo "✅ Backed up $count dashboard(s) to $dir"
}

cmd_restore() {
  local dir="./grafana-backups"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dir) dir="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [[ ! -d "$dir" ]] && { echo "❌ Directory not found: $dir"; exit 1; }

  local count=0
  for file in "$dir"/*.json; do
    [[ ! -f "$file" ]] && continue
    local dashboard
    dashboard=$(cat "$file")
    local payload
    payload=$(jq -n --argjson dashboard "$dashboard" '{dashboard: $dashboard, overwrite: true, folderId: 0}')
    payload=$(echo "$payload" | jq '.dashboard.id = null')

    local response
    response=$(api_call POST "/api/dashboards/db" "$payload")
    local http_code body
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "200" ]]; then
      local title
      title=$(echo "$body" | jq -r '.slug // "unknown"')
      echo "✅ Restored: $title"
      count=$((count + 1))
    else
      echo "⚠️  Failed to restore $(basename "$file"): $body"
    fi
  done
  echo "---"
  echo "✅ Restored $count dashboard(s) from $dir"
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  import) cmd_import "$@" ;;
  export) cmd_export "$@" ;;
  list) cmd_list ;;
  delete) cmd_delete "$@" ;;
  search) cmd_search "$@" ;;
  backup) cmd_backup "$@" ;;
  restore) cmd_restore "$@" ;;
  *)
    echo "Usage: $0 {import|export|list|delete|search|backup|restore} [options]"
    echo ""
    echo "Commands:"
    echo "  import   Import dashboard from Grafana.com (--id) or file (--file)"
    echo "  export   Export dashboard JSON (--uid)"
    echo "  list     List all dashboards"
    echo "  delete   Delete a dashboard (--uid)"
    echo "  search   Search dashboards (--query)"
    echo "  backup   Backup all dashboards to directory (--dir)"
    echo "  restore  Restore dashboards from backup (--dir)"
    exit 1
    ;;
esac
