#!/bin/bash
# Miniflux Server Manager — Management CLI
# Usage: bash manage.sh <command> [args]

set -euo pipefail

MINIFLUX_DIR="${MINIFLUX_DIR:-$HOME/miniflux}"
COMPOSE_FILE="${MINIFLUX_DIR}/docker-compose.yml"
ENV_FILE="${MINIFLUX_DIR}/.env"

# Load environment
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

MINIFLUX_URL="${BASE_URL:-http://localhost:8070}"
API_AUTH="${ADMIN_USER:-admin}:${ADMIN_PASS:-}"

_api() {
  local method="$1" path="$2"
  shift 2
  curl -sf -u "$API_AUTH" -X "$method" "${MINIFLUX_URL}${path}" \
    -H "Content-Type: application/json" "$@"
}

cmd_status() {
  echo "=== Miniflux Status ==="
  
  # Container status
  echo ""
  echo "Containers:"
  docker compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
    docker-compose -f "$COMPOSE_FILE" ps 2>/dev/null
  
  # Health check
  echo ""
  if health=$( curl -sf "${MINIFLUX_URL}/healthcheck" 2>/dev/null ); then
    echo "Health: ✅ ${health}"
  else
    echo "Health: ❌ Unreachable"
    return 1
  fi
  
  # Feed stats
  echo ""
  local feeds=$(_api GET "/v1/feeds" 2>/dev/null)
  if [[ -n "$feeds" ]]; then
    local total=$(echo "$feeds" | jq 'length')
    local errors=$(echo "$feeds" | jq '[.[] | select(.parsing_error_count > 0)] | length')
    echo "Feeds: ${total} total, ${errors} with errors"
  fi
  
  # Unread count
  local counters=$(_api GET "/v1/feeds/counters" 2>/dev/null)
  if [[ -n "$counters" ]]; then
    local unread=$(echo "$counters" | jq '[.unreads | to_entries[].value] | add // 0')
    echo "Unread: ${unread} entries"
  fi
}

cmd_feeds() {
  echo "=== RSS Feeds ==="
  _api GET "/v1/feeds" | jq -r '.[] | "\(.id)\t\(.title)\t\(.feed_url)"' | \
    column -t -s $'\t'
}

cmd_add() {
  local url="${1:?Usage: manage.sh add <feed_url>}"
  echo "Adding feed: ${url}"
  local result=$(_api POST "/v1/feeds" -d "{\"feed_url\": \"${url}\", \"category_id\": 1}")
  local feed_id=$(echo "$result" | jq -r '.feed_id // empty')
  if [[ -n "$feed_id" ]]; then
    echo "✅ Feed added (ID: ${feed_id})"
  else
    echo "❌ Failed: $(echo "$result" | jq -r '.error_message // "Unknown error"')"
    return 1
  fi
}

cmd_import() {
  local file="${1:?Usage: manage.sh import <opml_file>}"
  [[ -f "$file" ]] || { echo "❌ File not found: $file"; return 1; }
  echo "Importing OPML from: ${file}"
  local result=$(curl -sf -u "$API_AUTH" -X POST "${MINIFLUX_URL}/v1/import" \
    -H "Content-Type: application/xml" --data-binary "@${file}")
  echo "$result" | jq .
  echo "✅ Import complete"
}

cmd_export() {
  local outfile="miniflux-export-$(date +%Y%m%d-%H%M%S).opml"
  _api GET "/v1/export" > "$outfile"
  echo "✅ Exported to ${outfile}"
}

cmd_unread() {
  echo "=== Unread Entries by Feed ==="
  local counters=$(_api GET "/v1/feeds/counters")
  local feeds=$(_api GET "/v1/feeds")
  echo "$feeds" | jq -r --argjson c "$counters" \
    '.[] | "\(.id)\t\(.title)\t\($c.unreads[.id | tostring] // 0) unread"' | \
    column -t -s $'\t' | sort -t$'\t' -k3 -rn
}

cmd_refresh() {
  echo "Refreshing all feeds..."
  _api PUT "/v1/feeds/refresh" > /dev/null
  echo "✅ Refresh triggered for all feeds"
}

cmd_backup() {
  local outfile="${MINIFLUX_DIR}/miniflux-db-$(date +%Y%m%d-%H%M%S).sql.gz"
  echo "Backing up database..."
  docker exec miniflux-db pg_dump -U miniflux miniflux | gzip > "$outfile"
  local size=$(du -h "$outfile" | cut -f1)
  echo "✅ Backup saved: ${outfile} (${size})"
}

cmd_update() {
  echo "Updating Miniflux..."
  cd "$MINIFLUX_DIR"
  docker compose pull
  docker compose up -d
  echo "✅ Miniflux updated to latest version"
  sleep 3
  cmd_status
}

cmd_logs() {
  local lines="${1:-50}"
  docker compose -f "$COMPOSE_FILE" logs miniflux --tail "$lines" 2>/dev/null || \
    docker-compose -f "$COMPOSE_FILE" logs miniflux --tail "$lines" 2>/dev/null
}

cmd_help() {
  cat << 'HELP'
Miniflux Server Manager

Usage: bash manage.sh <command> [args]

Commands:
  status              Check service health and stats
  feeds               List all subscribed feeds
  add <url>           Add a new RSS feed
  import <opml>       Import feeds from OPML file
  export              Export all feeds as OPML
  unread              Show unread count per feed
  refresh             Force refresh all feeds
  backup              Backup PostgreSQL database
  update              Update Miniflux to latest version
  logs [lines]        View recent logs (default: 50)
  help                Show this help

Environment:
  MINIFLUX_DIR        Miniflux directory (default: ~/miniflux)
HELP
}

# Main dispatch
case "${1:-help}" in
  status)   cmd_status ;;
  feeds)    cmd_feeds ;;
  add)      cmd_add "${2:-}" ;;
  import)   cmd_import "${2:-}" ;;
  export)   cmd_export ;;
  unread)   cmd_unread ;;
  refresh)  cmd_refresh ;;
  backup)   cmd_backup ;;
  update)   cmd_update ;;
  logs)     cmd_logs "${2:-50}" ;;
  help|*)   cmd_help ;;
esac
