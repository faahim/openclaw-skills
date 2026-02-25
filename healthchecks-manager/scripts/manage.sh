#!/bin/bash
set -euo pipefail

# Healthchecks Manager — CLI management wrapper
# Usage: bash manage.sh <command> [args]

HC_URL="${HC_URL:-http://localhost:8000}"
HC_API_KEY="${HC_API_KEY:-}"
HC_DIR="${HC_INSTALL_DIR:-$HOME/healthchecks}"

# Detect compose command
if docker compose version &>/dev/null 2>&1; then
  COMPOSE="docker compose"
else
  COMPOSE="docker-compose"
fi

usage() {
  cat << 'EOF'
Healthchecks Manager

Usage: bash manage.sh <command> [options]

Service Commands:
  status          Show service status and check summary
  logs [N]        Show last N log lines (default: 50)
  restart         Restart the service
  update          Pull latest image and restart
  backup          Backup the database
  prune [N]       Prune old pings (keep last N per check, default: 100)

Check Commands:
  list            List all checks with status
  create <name> <timeout_seconds> [grace_seconds]
                  Create a new check
  delete <uuid>   Delete a check
  pause <uuid>    Pause a check
  down            List all DOWN checks
  ping <uuid>     Send a success ping
  fail <uuid>     Send a failure ping

Environment:
  HC_URL          Healthchecks URL (default: http://localhost:8000)
  HC_API_KEY      API key (required for check commands)
  HC_INSTALL_DIR  Install directory (default: ~/healthchecks)
EOF
}

require_api_key() {
  if [ -z "$HC_API_KEY" ]; then
    echo "❌ HC_API_KEY not set. Get it from ${HC_URL} → Project Settings → API Access"
    exit 1
  fi
}

api() {
  local method="$1" path="$2"
  shift 2
  curl -s -X "$method" "${HC_URL}/api/v3${path}" \
    -H "X-Api-Key: ${HC_API_KEY}" \
    -H "Content-Type: application/json" \
    "$@"
}

cmd_status() {
  echo "🏥 Healthchecks Manager Status"
  echo "=============================="
  echo ""
  
  # Service status
  cd "$HC_DIR" 2>/dev/null && $COMPOSE ps 2>/dev/null || echo "⚠️  Service directory not found at ${HC_DIR}"
  echo ""
  
  # Check summary if API key available
  if [ -n "$HC_API_KEY" ]; then
    local checks
    checks=$(api GET /checks/)
    local total up down grace new paused
    total=$(echo "$checks" | jq '.checks | length')
    up=$(echo "$checks" | jq '[.checks[] | select(.status == "up")] | length')
    down=$(echo "$checks" | jq '[.checks[] | select(.status == "down")] | length')
    grace=$(echo "$checks" | jq '[.checks[] | select(.status == "grace")] | length')
    new=$(echo "$checks" | jq '[.checks[] | select(.status == "new")] | length')
    paused=$(echo "$checks" | jq '[.checks[] | select(.status == "paused")] | length')
    
    echo "Checks: ${total} total | ✅ ${up} up | ❌ ${down} down | ⏳ ${grace} grace | 🆕 ${new} new | ⏸️ ${paused} paused"
    
    if [ "$down" -gt 0 ]; then
      echo ""
      echo "⚠️  DOWN checks:"
      echo "$checks" | jq -r '.checks[] | select(.status == "down") | "  ❌ \(.name) — last ping: \(.last_ping // "never")"'
    fi
  else
    echo "Set HC_API_KEY to see check summary"
  fi
}

cmd_list() {
  require_api_key
  api GET /checks/ | jq -r '.checks[] | "\(.status)\t\(.name)\t\(.last_ping // "never")\t\(.ping_url)"' | \
    column -t -s $'\t'
}

cmd_create() {
  require_api_key
  local name="${1:?Usage: create <name> <timeout_seconds> [grace_seconds]}"
  local timeout="${2:?Usage: create <name> <timeout_seconds> [grace_seconds]}"
  local grace="${3:-3600}"
  
  local result
  result=$(api POST /checks/ -d "{\"name\": \"${name}\", \"timeout\": ${timeout}, \"grace\": ${grace}, \"channels\": \"*\"}")
  
  local uuid ping_url
  ping_url=$(echo "$result" | jq -r '.ping_url')
  uuid=$(echo "$ping_url" | grep -oP '[^/]+$')
  
  echo "✅ Check created: ${name}"
  echo "   UUID:     ${uuid}"
  echo "   Ping URL: ${ping_url}"
  echo "   Timeout:  ${timeout}s"
  echo "   Grace:    ${grace}s"
  echo ""
  echo "Add to your cron job:"
  echo "  curl -fsS --retry 3 '${ping_url}' > /dev/null"
}

cmd_delete() {
  require_api_key
  local uuid="${1:?Usage: delete <uuid>}"
  api DELETE "/checks/${uuid}"
  echo "✅ Check ${uuid} deleted"
}

cmd_pause() {
  require_api_key
  local uuid="${1:?Usage: pause <uuid>}"
  api POST "/checks/${uuid}/pause"
  echo "✅ Check ${uuid} paused"
}

cmd_down() {
  require_api_key
  api GET /checks/ | jq -r '.checks[] | select(.status == "down") | "❌ \(.name) — last: \(.last_ping // "never") — \(.ping_url)"'
}

cmd_ping() {
  local uuid="${1:?Usage: ping <uuid>}"
  curl -fsS "${HC_URL}/ping/${uuid}"
  echo "✅ Pinged ${uuid}"
}

cmd_fail() {
  local uuid="${1:?Usage: fail <uuid>}"
  curl -fsS "${HC_URL}/ping/${uuid}/fail"
  echo "❌ Fail ping sent for ${uuid}"
}

cmd_logs() {
  local n="${1:-50}"
  cd "$HC_DIR" && $COMPOSE logs --tail="$n"
}

cmd_restart() {
  cd "$HC_DIR" && $COMPOSE restart
  echo "✅ Restarted"
}

cmd_update() {
  cd "$HC_DIR"
  $COMPOSE pull
  $COMPOSE up -d
  echo "✅ Updated to latest version"
}

cmd_backup() {
  local src="${HC_DIR}/data/hc.sqlite"
  local dst="${HC_DIR}/data/hc-backup-$(date +%Y%m%d-%H%M%S).sqlite"
  if [ -f "$src" ]; then
    cp "$src" "$dst"
    echo "✅ Backed up to ${dst}"
  else
    echo "❌ Database not found at ${src}"
    exit 1
  fi
}

cmd_prune() {
  local keep="${1:-100}"
  cd "$HC_DIR" && $COMPOSE exec healthchecks python manage.py prunepings --keep="$keep"
  echo "✅ Pruned pings (kept last ${keep} per check)"
}

# Route commands
case "${1:-help}" in
  status)   cmd_status ;;
  list)     cmd_list ;;
  create)   shift; cmd_create "$@" ;;
  delete)   shift; cmd_delete "$@" ;;
  pause)    shift; cmd_pause "$@" ;;
  down)     cmd_down ;;
  ping)     shift; cmd_ping "$@" ;;
  fail)     shift; cmd_fail "$@" ;;
  logs)     shift; cmd_logs "$@" ;;
  restart)  cmd_restart ;;
  update)   cmd_update ;;
  backup)   cmd_backup ;;
  prune)    shift; cmd_prune "$@" ;;
  *)        usage ;;
esac
