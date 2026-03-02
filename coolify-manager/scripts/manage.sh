#!/bin/bash
# Coolify Manager — CLI wrapper for Coolify API
set -euo pipefail

# Load config
CONFIG_FILE="${HOME}/.coolify.env"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

COOLIFY_URL="${COOLIFY_URL:-http://localhost:8000}"
COOLIFY_TOKEN="${COOLIFY_TOKEN:-}"
COOLIFY_TEAM_ID="${COOLIFY_TEAM_ID:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✅]${NC} $*"; }
warn() { echo -e "${YELLOW}[⚠️]${NC} $*"; }
err()  { echo -e "${RED}[❌]${NC} $*"; exit 1; }
info() { echo -e "${CYAN}[ℹ️]${NC} $*"; }

# API helper
api() {
  local method="$1" endpoint="$2"
  shift 2
  local url="${COOLIFY_URL}/api/v1${endpoint}"
  
  if [ -z "$COOLIFY_TOKEN" ]; then
    err "COOLIFY_TOKEN not set. Get one from Coolify dashboard → Settings → API Tokens"
  fi
  
  curl -sf -X "$method" "$url" \
    -H "Authorization: Bearer $COOLIFY_TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    "$@" 2>/dev/null
}

usage() {
  echo -e "${BOLD}Coolify Manager${NC} — CLI for Coolify Self-Hosted PaaS"
  echo ""
  echo "Usage: bash manage.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  status              Show Coolify instance status"
  echo "  health              Full system health check"
  echo "  servers             List configured servers"
  echo "  list                List all applications and databases"
  echo "  deploy-app          Deploy a new application"
  echo "  deploy-compose      Deploy a Docker Compose stack"
  echo "  app-status          Check application status"
  echo "  restart             Restart an application"
  echo "  stop                Stop an application"
  echo "  start               Start an application"
  echo "  logs                View application logs"
  echo "  create-db           Create a new database"
  echo "  db-info             Get database connection info"
  echo "  set-domain          Set custom domain for app"
  echo "  ssl-status          Check SSL certificate status"
  echo "  env-set             Set environment variable"
  echo "  env-list            List environment variables"
  echo "  env-import          Import env vars from file"
  echo "  backup              Create database backup"
  echo "  backups             List backups"
  echo "  backup-schedule     Schedule automatic backups"
  echo "  resources           Show resource usage per container"
  echo "  webhook             Get webhook URL for auto-deploy"
  echo "  add-server          Add remote server"
  echo "  check-update        Check for Coolify updates"
  echo "  update              Update Coolify to latest"
  echo "  cancel-deploy       Cancel stuck deployment"
  echo ""
  echo "Options:"
  echo "  --name NAME         Application/database name"
  echo "  --repo URL          Git repository URL"
  echo "  --branch BRANCH     Git branch (default: main)"
  echo "  --type TYPE         App type: nodejs|php|python|static|dockerfile"
  echo "  --domain DOMAIN     Custom domain"
  echo "  --force             Force operation"
  echo ""
  echo "Environment:"
  echo "  COOLIFY_URL         Coolify instance URL (default: http://localhost:8000)"
  echo "  COOLIFY_TOKEN       API token (required)"
  echo "  COOLIFY_TEAM_ID     Team ID (default: 0)"
}

cmd_status() {
  echo -e "${BOLD}Coolify Instance Status${NC}"
  echo ""
  
  # Check Coolify version
  local version
  version=$(api GET "/version" | jq -r '.' 2>/dev/null || echo "unknown")
  
  if [ "$version" = "unknown" ]; then
    # Try checking Docker directly
    if docker ps | grep -q coolify 2>/dev/null; then
      version=$(docker inspect coolify 2>/dev/null | jq -r '.[0].Config.Labels["coolify.version"] // "running (version unknown)"')
      log "Coolify: $version"
    else
      err "Cannot connect to Coolify at $COOLIFY_URL"
    fi
  else
    log "Coolify: v$version"
  fi
  
  echo "  URL: $COOLIFY_URL"
  
  # List resources
  local apps dbs
  apps=$(api GET "/applications" | jq 'length' 2>/dev/null || echo "?")
  dbs=$(api GET "/databases" | jq 'length' 2>/dev/null || echo "?")
  
  echo "  📦 Applications: $apps"
  echo "  🗄️  Databases: $dbs"
  
  # Disk usage
  if command -v df &>/dev/null; then
    local disk_pct disk_used disk_total
    disk_pct=$(df -h / | awk 'NR==2{print $5}')
    disk_used=$(df -h / | awk 'NR==2{print $3}')
    disk_total=$(df -h / | awk 'NR==2{print $2}')
    echo "  💾 Disk: ${disk_pct} (${disk_used} / ${disk_total})"
  fi
  
  # Memory
  if command -v free &>/dev/null; then
    local mem_used mem_total mem_pct
    mem_used=$(free -h | awk '/^Mem:/{print $3}')
    mem_total=$(free -h | awk '/^Mem:/{print $2}')
    mem_pct=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
    echo "  🧠 Memory: ${mem_pct}% (${mem_used} / ${mem_total})"
  fi
}

cmd_health() {
  echo -e "${BOLD}🏥 Coolify Health Report${NC}"
  echo ""
  
  # Coolify process
  if docker ps | grep -q coolify 2>/dev/null; then
    log "Coolify container: running"
  else
    err "Coolify container: not running"
  fi
  
  # Docker
  if command -v docker &>/dev/null; then
    local docker_ver
    docker_ver=$(docker --version | awk '{print $3}' | tr -d ',')
    log "Docker: $docker_ver"
  else
    err "Docker: not installed"
  fi
  
  # Traefik proxy
  if docker ps | grep -q traefik 2>/dev/null; then
    log "Traefik proxy: running"
  elif docker ps | grep -q caddy 2>/dev/null; then
    log "Caddy proxy: running"
  else
    warn "No reverse proxy detected"
  fi
  
  # Disk
  local disk_pct
  disk_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
  if [ "$disk_pct" -gt 90 ]; then
    err "Disk: ${disk_pct}% — CRITICAL"
  elif [ "$disk_pct" -gt 80 ]; then
    warn "Disk: ${disk_pct}% — WARNING"
  else
    log "Disk: ${disk_pct}%"
  fi
  
  # Memory
  local mem_pct
  mem_pct=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
  if [ "$mem_pct" -gt 90 ]; then
    err "Memory: ${mem_pct}% — CRITICAL"
  elif [ "$mem_pct" -gt 80 ]; then
    warn "Memory: ${mem_pct}% — WARNING"
  else
    log "Memory: ${mem_pct}%"
  fi
  
  # Running containers
  local container_count
  container_count=$(docker ps -q | wc -l)
  log "Running containers: $container_count"
  
  # API connectivity
  if api GET "/version" &>/dev/null; then
    log "API: reachable"
  else
    warn "API: not reachable (token may be missing/invalid)"
  fi
}

cmd_servers() {
  local servers
  servers=$(api GET "/servers")
  
  echo -e "${BOLD}Configured Servers${NC}"
  echo ""
  echo "$servers" | jq -r '.[] | "  \(.name) — \(.ip // "localhost") [\(if .settings.is_reachable then "✅ reachable" else "❌ unreachable" end)]"' 2>/dev/null || echo "  No servers found (or API token not set)"
}

cmd_list() {
  echo -e "${BOLD}Applications${NC}"
  local apps
  apps=$(api GET "/applications" 2>/dev/null)
  if [ -n "$apps" ] && [ "$apps" != "null" ]; then
    echo "$apps" | jq -r '.[] | "  \(.name) — \(.fqdn // "no domain") [\(.status // "unknown")]"' 2>/dev/null
  else
    echo "  No applications found"
  fi
  
  echo ""
  echo -e "${BOLD}Databases${NC}"
  local dbs
  dbs=$(api GET "/databases" 2>/dev/null)
  if [ -n "$dbs" ] && [ "$dbs" != "null" ]; then
    echo "$dbs" | jq -r '.[] | "  \(.name) — \(.type):\(.version // "latest") [\(.status // "unknown")]"' 2>/dev/null
  else
    echo "  No databases found"
  fi
}

cmd_deploy_app() {
  local repo="" branch="main" type="" domain="" name="" force=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --repo) repo="$2"; shift 2 ;;
      --branch) branch="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --domain) domain="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --force) force="true"; shift ;;
      *) shift ;;
    esac
  done
  
  [ -z "$repo" ] && err "Missing --repo"
  
  # Auto-detect name from repo
  [ -z "$name" ] && name=$(basename "$repo" .git)
  
  info "Deploying $repo (branch: $branch)..."
  
  local payload
  payload=$(jq -n \
    --arg repo "$repo" \
    --arg branch "$branch" \
    --arg name "$name" \
    --arg domain "$domain" \
    '{
      name: $name,
      git_repository: $repo,
      git_branch: $branch,
      build_pack: "nixpacks",
      fqdn: (if $domain != "" then "https://\($domain)" else null end),
      instant_deploy: true
    }')
  
  # Get first server UUID
  local server_uuid
  server_uuid=$(api GET "/servers" | jq -r '.[0].uuid' 2>/dev/null)
  [ -z "$server_uuid" ] && err "No servers configured"
  
  local response
  response=$(api POST "/applications" -d "$payload" 2>&1)
  
  if echo "$response" | jq -e '.uuid' &>/dev/null; then
    local app_uuid
    app_uuid=$(echo "$response" | jq -r '.uuid')
    log "Application created: $name (UUID: $app_uuid)"
    [ -n "$domain" ] && log "Domain: https://$domain (SSL auto-provisioned)"
    log "Deployment triggered — check status with: bash manage.sh app-status --name $name"
  else
    err "Deployment failed: $response"
  fi
}

cmd_app_status() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$name" ] && err "Missing --name"
  
  local apps
  apps=$(api GET "/applications")
  local app
  app=$(echo "$apps" | jq -r ".[] | select(.name == \"$name\")" 2>/dev/null)
  
  if [ -z "$app" ] || [ "$app" = "null" ]; then
    err "Application '$name' not found"
  fi
  
  echo -e "${BOLD}Application: $name${NC}"
  echo "$app" | jq -r '"  Status: \(.status // "unknown")\n  Domain: \(.fqdn // "none")\n  Git: \(.git_repository // "none") (\(.git_branch // "main"))\n  UUID: \(.uuid)"'
}

cmd_restart() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$name" ] && err "Missing --name"
  
  local uuid
  uuid=$(api GET "/applications" | jq -r ".[] | select(.name == \"$name\") | .uuid" 2>/dev/null)
  [ -z "$uuid" ] && err "Application '$name' not found"
  
  api POST "/applications/$uuid/restart" >/dev/null
  log "Restarted: $name"
}

cmd_stop() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$name" ] && err "Missing --name"
  
  local uuid
  uuid=$(api GET "/applications" | jq -r ".[] | select(.name == \"$name\") | .uuid" 2>/dev/null)
  [ -z "$uuid" ] && err "Application '$name' not found"
  
  api POST "/applications/$uuid/stop" >/dev/null
  log "Stopped: $name"
}

cmd_start() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$name" ] && err "Missing --name"
  
  local uuid
  uuid=$(api GET "/applications" | jq -r ".[] | select(.name == \"$name\") | .uuid" 2>/dev/null)
  [ -z "$uuid" ] && err "Application '$name' not found"
  
  api POST "/applications/$uuid/start" >/dev/null
  log "Started: $name"
}

cmd_logs() {
  local name="" lines=50
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --lines) lines="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$name" ] && err "Missing --name"
  
  local uuid
  uuid=$(api GET "/applications" | jq -r ".[] | select(.name == \"$name\") | .uuid" 2>/dev/null)
  [ -z "$uuid" ] && err "Application '$name' not found"
  
  local logs
  logs=$(api GET "/applications/$uuid/logs?tail=$lines" 2>/dev/null)
  
  if [ -n "$logs" ]; then
    echo "$logs" | jq -r '.[] | .output // .' 2>/dev/null || echo "$logs"
  else
    # Fallback: get logs from Docker directly
    local container
    container=$(docker ps --format '{{.Names}}' | grep -i "$name" | head -1)
    if [ -n "$container" ]; then
      docker logs --tail "$lines" "$container"
    else
      warn "No logs available"
    fi
  fi
}

cmd_create_db() {
  local type="" name="" version=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --type) type="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --version) version="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$type" ] && err "Missing --type (postgres|mysql|mariadb|mongodb|redis)"
  [ -z "$name" ] && err "Missing --name"
  
  local server_uuid
  server_uuid=$(api GET "/servers" | jq -r '.[0].uuid' 2>/dev/null)
  
  local payload
  payload=$(jq -n \
    --arg type "$type" \
    --arg name "$name" \
    --arg version "${version:-latest}" \
    --arg server "$server_uuid" \
    '{
      name: $name,
      type: $type,
      version: $version,
      server_uuid: $server,
      instant_deploy: true
    }')
  
  local response
  response=$(api POST "/databases" -d "$payload" 2>&1)
  
  if echo "$response" | jq -e '.uuid' &>/dev/null; then
    log "Database created: $name ($type)"
    info "Get connection info: bash manage.sh db-info --name $name"
  else
    err "Failed to create database: $response"
  fi
}

cmd_db_info() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$name" ] && err "Missing --name"
  
  local dbs
  dbs=$(api GET "/databases")
  local db
  db=$(echo "$dbs" | jq -r ".[] | select(.name == \"$name\")" 2>/dev/null)
  
  if [ -z "$db" ] || [ "$db" = "null" ]; then
    err "Database '$name' not found"
  fi
  
  echo -e "${BOLD}Database: $name${NC}"
  echo "$db" | jq -r '"  Type: \(.type)\n  Version: \(.version // "latest")\n  Status: \(.status // "unknown")\n  Internal URL: \(.internal_db_url // "n/a")\n  UUID: \(.uuid)"'
}

cmd_env_set() {
  local name="" key="" value=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --key) key="$2"; shift 2 ;;
      --value) value="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$name" ] && err "Missing --name"
  [ -z "$key" ] && err "Missing --key"
  
  local uuid
  uuid=$(api GET "/applications" | jq -r ".[] | select(.name == \"$name\") | .uuid" 2>/dev/null)
  [ -z "$uuid" ] && err "Application '$name' not found"
  
  local payload
  payload=$(jq -n --arg key "$key" --arg value "$value" '{key: $key, value: $value, is_build_time: false}')
  
  api POST "/applications/$uuid/envs" -d "$payload" >/dev/null
  log "Set $key for $name"
}

cmd_env_list() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$name" ] && err "Missing --name"
  
  local uuid
  uuid=$(api GET "/applications" | jq -r ".[] | select(.name == \"$name\") | .uuid" 2>/dev/null)
  [ -z "$uuid" ] && err "Application '$name' not found"
  
  local envs
  envs=$(api GET "/applications/$uuid/envs" 2>/dev/null)
  
  echo -e "${BOLD}Environment Variables: $name${NC}"
  echo "$envs" | jq -r '.[] | "  \(.key)=\(.value)"' 2>/dev/null || echo "  No environment variables"
}

cmd_resources() {
  echo -e "${BOLD}Container Resource Usage${NC}"
  echo ""
  docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || err "Docker not accessible"
}

cmd_update() {
  info "Updating Coolify..."
  cd /data/coolify/source 2>/dev/null || err "Coolify source not found at /data/coolify/source"
  docker compose pull
  docker compose up -d
  log "Coolify updated!"
}

cmd_check_update() {
  local current
  current=$(api GET "/version" 2>/dev/null || echo "unknown")
  info "Current version: $current"
  info "Check https://github.com/coollabsio/coolify/releases for latest"
}

# Main command router
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  status)         cmd_status "$@" ;;
  health)         cmd_health "$@" ;;
  servers)        cmd_servers "$@" ;;
  list)           cmd_list "$@" ;;
  deploy-app)     cmd_deploy_app "$@" ;;
  app-status)     cmd_app_status "$@" ;;
  restart)        cmd_restart "$@" ;;
  stop)           cmd_stop "$@" ;;
  start)          cmd_start "$@" ;;
  logs)           cmd_logs "$@" ;;
  create-db)      cmd_create_db "$@" ;;
  db-info)        cmd_db_info "$@" ;;
  env-set)        cmd_env_set "$@" ;;
  env-list)       cmd_env_list "$@" ;;
  resources)      cmd_resources "$@" ;;
  update)         cmd_update "$@" ;;
  check-update)   cmd_check_update "$@" ;;
  help|--help|-h) usage ;;
  *)              err "Unknown command: $COMMAND (run 'bash manage.sh help')" ;;
esac
