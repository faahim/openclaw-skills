#!/usr/bin/env bash
set -euo pipefail

# Audiobookshelf Manager
# Deploy, manage, backup, and monitor Audiobookshelf via Docker

ABS_PORT="${ABS_PORT:-13378}"
ABS_DATA_DIR="${ABS_DATA_DIR:-/opt/audiobookshelf}"
ABS_HOST="${ABS_HOST:-0.0.0.0}"
ABS_IMAGE="ghcr.io/advplyr/audiobookshelf:latest"
ABS_CONTAINER="audiobookshelf"
TZ="${TZ:-UTC}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC} $*"; }
error() { echo -e "${RED}❌${NC} $*" >&2; }

usage() {
  cat <<EOF
Audiobookshelf Manager

Usage: $0 <command> [options]

Commands:
  deploy          Deploy Audiobookshelf via Docker
  stop            Stop the container
  start           Start the container
  restart         Restart the container
  remove          Remove container and optionally data
  status          Show container status
  version         Show current version
  update          Update to latest or specific version
  logs            View container logs
  
  library-add     Add a library (--name, --path, --type book|podcast)
  scan            Trigger library scan (--library or --all)
  scan-status     Show scan status
  users           List users
  user-add        Add user (--username, --password, --type user|admin)
  user-del        Delete user (--username)
  
  backup          Backup data (--output path.tar.gz)
  restore         Restore from backup (--input path.tar.gz)
  backup-cron     Setup automated backups (--schedule, --output-dir, --keep)
  
  nginx-config    Generate nginx reverse proxy config (--domain, --port)
  api-token       Get API token (--username, --password)
  api             Raw API call (--endpoint, --method, --data)

Options:
  --port PORT         Server port (default: 13378)
  --data-dir DIR      Data directory (default: /opt/audiobookshelf)
  --audiobooks DIR    Audiobooks directory
  --podcasts DIR      Podcasts directory
  --timezone TZ       Timezone (default: UTC)
  --version VER       Specific version for update
  --force             Force operation
  --lines N           Number of log lines (default: 50)
  --host HOST         Bind host (default: 0.0.0.0)

EOF
  exit 1
}

# --- Helpers ---

check_docker() {
  command -v docker &>/dev/null || { error "Docker not installed. Run: curl -fsSL https://get.docker.com | sh"; exit 1; }
}

is_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${ABS_CONTAINER}$"
}

get_api_url() {
  echo "http://localhost:${ABS_PORT}"
}

abs_api() {
  local method="${1:-GET}" endpoint="$2" data="${3:-}"
  local url="$(get_api_url)${endpoint}"
  local token_file="${ABS_DATA_DIR}/.api_token"
  
  local auth_header=""
  if [[ -f "$token_file" ]]; then
    auth_header="-H \"Authorization: Bearer $(cat "$token_file")\""
  fi
  
  if [[ -n "$data" ]]; then
    eval curl -sf -X "$method" "$url" -H "Content-Type: application/json" $auth_header -d "'$data'"
  else
    eval curl -sf -X "$method" "$url" $auth_header
  fi
}

# --- Commands ---

cmd_deploy() {
  local audiobooks="" podcasts=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --port) ABS_PORT="$2"; shift 2 ;;
      --data-dir) ABS_DATA_DIR="$2"; shift 2 ;;
      --audiobooks) audiobooks="$2"; shift 2 ;;
      --podcasts) podcasts="$2"; shift 2 ;;
      --timezone) TZ="$2"; shift 2 ;;
      --host) ABS_HOST="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  check_docker
  
  # Create directories
  mkdir -p "${ABS_DATA_DIR}"/{config,metadata}
  [[ -n "$audiobooks" ]] && mkdir -p "$audiobooks"
  [[ -n "$podcasts" ]] && mkdir -p "$podcasts"
  
  # Build volume mounts
  local volumes="-v ${ABS_DATA_DIR}/config:/config -v ${ABS_DATA_DIR}/metadata:/metadata"
  [[ -n "$audiobooks" ]] && volumes="$volumes -v ${audiobooks}:/audiobooks"
  [[ -n "$podcasts" ]] && volumes="$volumes -v ${podcasts}:/podcasts"
  
  # Stop existing container if any
  docker rm -f "$ABS_CONTAINER" 2>/dev/null || true
  
  # Pull latest image
  echo "Pulling Audiobookshelf image..."
  docker pull "$ABS_IMAGE"
  
  # Run container
  eval docker run -d \
    --name "$ABS_CONTAINER" \
    -p "${ABS_HOST}:${ABS_PORT}:80" \
    -e "TZ=${TZ}" \
    $volumes \
    --restart unless-stopped \
    "$ABS_IMAGE"
  
  # Generate docker-compose.yml for reference
  cat > "${ABS_DATA_DIR}/docker-compose.yml" <<COMPOSE
services:
  audiobookshelf:
    image: ${ABS_IMAGE}
    container_name: ${ABS_CONTAINER}
    ports:
      - "${ABS_HOST}:${ABS_PORT}:80"
    volumes:
      - ./config:/config
      - ./metadata:/metadata
${audiobooks:+      - ${audiobooks}:/audiobooks}
${podcasts:+      - ${podcasts}:/podcasts}
    environment:
      - TZ=${TZ}
    restart: unless-stopped
COMPOSE
  
  # Wait for startup
  sleep 3
  
  if is_running; then
    info "Audiobookshelf deployed successfully"
    echo "   URL: http://localhost:${ABS_PORT}"
    echo "   Data: ${ABS_DATA_DIR}"
    echo "   Config: ${ABS_DATA_DIR}/config"
    echo "   Metadata: ${ABS_DATA_DIR}/metadata"
    echo "   Status: running"
    echo ""
    echo "   Open http://localhost:${ABS_PORT} to complete setup (create admin account)."
  else
    error "Deployment failed. Check: docker logs $ABS_CONTAINER"
    exit 1
  fi
}

cmd_stop() {
  check_docker
  docker stop "$ABS_CONTAINER" 2>/dev/null && info "Audiobookshelf stopped" || error "Container not running"
}

cmd_start() {
  check_docker
  docker start "$ABS_CONTAINER" 2>/dev/null && info "Audiobookshelf started" || error "Container not found. Run deploy first."
}

cmd_restart() {
  check_docker
  docker restart "$ABS_CONTAINER" 2>/dev/null && info "Audiobookshelf restarted" || error "Container not found"
}

cmd_remove() {
  check_docker
  local remove_data=false
  [[ "${1:-}" == "--data" ]] && remove_data=true
  
  docker rm -f "$ABS_CONTAINER" 2>/dev/null && info "Container removed" || warn "Container not found"
  
  if $remove_data; then
    rm -rf "$ABS_DATA_DIR"
    info "Data directory removed: $ABS_DATA_DIR"
  fi
}

cmd_status() {
  check_docker
  if is_running; then
    local container_info
    container_info=$(docker inspect "$ABS_CONTAINER" 2>/dev/null)
    local image=$(echo "$container_info" | jq -r '.[0].Config.Image')
    local created=$(echo "$container_info" | jq -r '.[0].Created' | cut -dT -f1)
    local uptime=$(docker ps --filter "name=$ABS_CONTAINER" --format '{{.Status}}')
    
    info "Audiobookshelf is RUNNING"
    echo "   Image: $image"
    echo "   URL: http://localhost:${ABS_PORT}"
    echo "   Status: $uptime"
    echo "   Created: $created"
    echo "   Data: ${ABS_DATA_DIR}"
  else
    warn "Audiobookshelf is NOT running"
    docker ps -a --filter "name=$ABS_CONTAINER" --format "   Status: {{.Status}}" 2>/dev/null
  fi
}

cmd_version() {
  check_docker
  if is_running; then
    local ver
    ver=$(curl -sf "http://localhost:${ABS_PORT}/api/status" 2>/dev/null | jq -r '.serverVersion // "unknown"')
    echo "Audiobookshelf version: $ver"
  else
    error "Container not running"
  fi
}

cmd_update() {
  local target_version="latest"
  [[ "${1:-}" == "--version" ]] && target_version="$2"
  
  check_docker
  
  if [[ "$target_version" != "latest" ]]; then
    ABS_IMAGE="ghcr.io/advplyr/audiobookshelf:${target_version}"
  fi
  
  echo "Pulling ${ABS_IMAGE}..."
  docker pull "$ABS_IMAGE"
  
  # Get current config
  local old_config
  old_config=$(docker inspect "$ABS_CONTAINER" 2>/dev/null) || { error "Container not found"; exit 1; }
  
  # Recreate with same settings
  docker rm -f "$ABS_CONTAINER" 2>/dev/null
  
  # Re-run from docker-compose if available
  if [[ -f "${ABS_DATA_DIR}/docker-compose.yml" ]]; then
    cd "$ABS_DATA_DIR"
    if command -v docker-compose &>/dev/null; then
      docker-compose up -d
    else
      docker compose up -d
    fi
    info "Updated Audiobookshelf (via compose)"
  else
    warn "No docker-compose.yml found. Re-deploy manually."
    exit 1
  fi
}

cmd_logs() {
  local lines=50
  [[ "${1:-}" == "--lines" ]] && lines="$2"
  check_docker
  docker logs --tail "$lines" "$ABS_CONTAINER" 2>&1
}

cmd_backup() {
  local output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  [[ -z "$output" ]] && output="audiobookshelf-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  
  # Backup config and metadata
  tar -czf "$output" -C "$ABS_DATA_DIR" config metadata
  local size=$(du -sh "$output" | cut -f1)
  info "Backup created: $output ($size)"
}

cmd_restore() {
  local input=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  [[ -z "$input" ]] && { error "Usage: restore --input backup.tar.gz"; exit 1; }
  [[ ! -f "$input" ]] && { error "File not found: $input"; exit 1; }
  
  # Stop container
  docker stop "$ABS_CONTAINER" 2>/dev/null || true
  
  # Restore
  tar -xzf "$input" -C "$ABS_DATA_DIR"
  
  # Restart
  docker start "$ABS_CONTAINER" 2>/dev/null
  info "Restored from $input and restarted"
}

cmd_backup_cron() {
  local schedule="0 3 * * *" output_dir="/backups/audiobookshelf" keep=7
  while [[ $# -gt 0 ]]; do
    case $1 in
      --schedule) schedule="$2"; shift 2 ;;
      --output-dir) output_dir="$2"; shift 2 ;;
      --keep) keep="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  mkdir -p "$output_dir"
  
  local script_path
  script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run.sh"
  
  # Create backup + cleanup script
  local cron_script="${ABS_DATA_DIR}/auto-backup.sh"
  cat > "$cron_script" <<CRONSCRIPT
#!/bin/bash
export ABS_DATA_DIR="${ABS_DATA_DIR}"
bash "${script_path}" backup --output "${output_dir}/abs-\$(date +%Y%m%d-%H%M%S).tar.gz"
# Cleanup old backups (keep last ${keep})
ls -1t "${output_dir}"/abs-*.tar.gz 2>/dev/null | tail -n +$((keep + 1)) | xargs -r rm -f
CRONSCRIPT
  chmod +x "$cron_script"
  
  # Add to crontab
  (crontab -l 2>/dev/null | grep -v "auto-backup.sh"; echo "${schedule} ${cron_script}") | crontab -
  
  info "Auto-backup configured"
  echo "   Schedule: ${schedule}"
  echo "   Output: ${output_dir}"
  echo "   Retention: last ${keep} backups"
}

cmd_nginx_config() {
  local domain="" port="$ABS_PORT"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --domain) domain="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  [[ -z "$domain" ]] && { error "Usage: nginx-config --domain example.com"; exit 1; }
  
  cat <<NGINX
server {
    listen 80;
    server_name ${domain};

    client_max_body_size 0;

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
NGINX
}

cmd_api_token() {
  local username="" password=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --username) username="$2"; shift 2 ;;
      --password) password="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  [[ -z "$username" || -z "$password" ]] && { error "Usage: api-token --username admin --password pass"; exit 1; }
  
  local response
  response=$(curl -sf -X POST "http://localhost:${ABS_PORT}/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${username}\",\"password\":\"${password}\"}")
  
  local token
  token=$(echo "$response" | jq -r '.user.token // empty')
  
  if [[ -n "$token" ]]; then
    echo "$token" > "${ABS_DATA_DIR}/.api_token"
    info "API token saved to ${ABS_DATA_DIR}/.api_token"
    echo "Token: $token"
  else
    error "Login failed. Check credentials."
  fi
}

cmd_api() {
  local endpoint="" method="GET" data=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --endpoint) endpoint="$2"; shift 2 ;;
      --method) method="$2"; shift 2 ;;
      --data) data="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  [[ -z "$endpoint" ]] && { error "Usage: api --endpoint /api/libraries --method GET"; exit 1; }
  
  abs_api "$method" "$endpoint" "$data" | jq .
}

cmd_scan() {
  local library="" all=false force=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --library) library="$2"; shift 2 ;;
      --all) all=true; shift ;;
      --force) force=true; shift ;;
      *) shift ;;
    esac
  done
  
  if $all; then
    local libs
    libs=$(abs_api GET "/api/libraries" | jq -r '.libraries[].id')
    for lid in $libs; do
      abs_api POST "/api/libraries/${lid}/scan" '{"force":'$force'}'
      info "Scan started for library $lid"
    done
  elif [[ -n "$library" ]]; then
    local lid
    lid=$(abs_api GET "/api/libraries" | jq -r ".libraries[] | select(.name==\"${library}\") | .id")
    if [[ -n "$lid" ]]; then
      abs_api POST "/api/libraries/${lid}/scan" '{"force":'$force'}'
      info "Scan started for $library"
    else
      error "Library not found: $library"
    fi
  else
    error "Usage: scan --library 'Name' or scan --all"
  fi
}

# --- Main ---

[[ $# -eq 0 ]] && usage

CMD="$1"; shift

case "$CMD" in
  deploy)       cmd_deploy "$@" ;;
  stop)         cmd_stop "$@" ;;
  start)        cmd_start "$@" ;;
  restart)      cmd_restart "$@" ;;
  remove)       cmd_remove "$@" ;;
  status)       cmd_status "$@" ;;
  version)      cmd_version "$@" ;;
  update)       cmd_update "$@" ;;
  logs)         cmd_logs "$@" ;;
  backup)       cmd_backup "$@" ;;
  restore)      cmd_restore "$@" ;;
  backup-cron)  cmd_backup_cron "$@" ;;
  nginx-config) cmd_nginx_config "$@" ;;
  api-token)    cmd_api_token "$@" ;;
  api)          cmd_api "$@" ;;
  scan)         cmd_scan "$@" ;;
  library-add|user-add|user-del|users|scan-status)
    warn "This command requires API access. Run 'api-token' first, then use 'api' command."
    echo "   Example: $0 api --endpoint /api/libraries --method GET"
    ;;
  *)            error "Unknown command: $CMD"; usage ;;
esac
