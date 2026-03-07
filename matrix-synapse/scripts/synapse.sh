#!/bin/bash
# Matrix Synapse Manager — Main Script
# Manages a Matrix Synapse homeserver via Docker

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────
DOMAIN="${MATRIX_DOMAIN:-}"
DATA_DIR="${MATRIX_DATA_DIR:-$HOME/matrix-synapse}"
CONTAINER_NAME="synapse"
COMPOSE_FILE="$DATA_DIR/docker-compose.yml"
DB_TYPE="${MATRIX_DB_TYPE:-sqlite}"
ADMIN_TOKEN="${MATRIX_ADMIN_TOKEN:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
err()   { echo -e "${RED}❌${NC} $*" >&2; }
info()  { echo -e "${BLUE}ℹ️${NC}  $*"; }

# ─── Helpers ─────────────────────────────────────────────────────
check_deps() {
  local missing=()
  for cmd in docker curl jq; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Missing dependencies: ${missing[*]}"
    echo "Install them first:"
    echo "  sudo apt-get install -y ${missing[*]}"
    exit 1
  fi
  # Check docker compose
  if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
  elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
  else
    err "docker compose not found"
    exit 1
  fi
}

require_domain() {
  if [[ -z "$DOMAIN" ]]; then
    err "MATRIX_DOMAIN not set. Export it first:"
    echo "  export MATRIX_DOMAIN=\"matrix.example.com\""
    exit 1
  fi
}

require_running() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    err "Synapse is not running. Start it with: $0 start"
    exit 1
  fi
}

get_admin_token() {
  if [[ -n "$ADMIN_TOKEN" ]]; then
    echo "$ADMIN_TOKEN"
    return
  fi
  local token_file="$DATA_DIR/.admin_token"
  if [[ -f "$token_file" ]]; then
    cat "$token_file"
  else
    err "No admin token found. Register an admin user first."
    exit 1
  fi
}

api() {
  local method="$1" endpoint="$2"
  shift 2
  local token
  token=$(get_admin_token)
  curl -s -X "$method" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    "http://localhost:8008/_synapse/admin/v1${endpoint}" \
    "$@"
}

client_api() {
  local method="$1" endpoint="$2"
  shift 2
  curl -s -X "$method" \
    -H "Content-Type: application/json" \
    "http://localhost:8008/_matrix/client/r0${endpoint}" \
    "$@"
}

# ─── Commands ────────────────────────────────────────────────────

cmd_init() {
  require_domain
  local with_postgres=false with_nginx=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain) DOMAIN="$2"; shift 2 ;;
      --with-postgres) with_postgres=true; shift ;;
      --with-nginx) with_nginx=true; shift ;;
      *) shift ;;
    esac
  done

  mkdir -p "$DATA_DIR"

  # Generate Synapse config
  info "Generating Synapse configuration for $DOMAIN..."
  docker run -it --rm \
    -v "$DATA_DIR:/data" \
    -e SYNAPSE_SERVER_NAME="$DOMAIN" \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate

  # Generate docker-compose.yml
  info "Creating docker-compose.yml..."
  cat > "$COMPOSE_FILE" <<YAML
version: "3.8"

services:
  synapse:
    image: matrixdotorg/synapse:latest
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    volumes:
      - $DATA_DIR:/data
    ports:
      - "8008:8008"
      - "8448:8448"
    environment:
      - SYNAPSE_CONFIG_PATH=/data/homeserver.yaml
YAML

  if $with_postgres; then
    info "Adding PostgreSQL..."
    local db_pass
    db_pass=$(openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
    cat >> "$COMPOSE_FILE" <<YAML
    depends_on:
      - postgres

  postgres:
    image: postgres:16-alpine
    container_name: synapse-postgres
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/postgres:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: synapse
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: ${db_pass}
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=C"
YAML

    # Update homeserver.yaml for PostgreSQL
    if [[ -f "$DATA_DIR/homeserver.yaml" ]]; then
      cat >> "$DATA_DIR/homeserver.yaml" <<DBCONF

# PostgreSQL database configuration
database:
  name: psycopg2
  args:
    user: synapse
    password: ${db_pass}
    database: synapse
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10
DBCONF
      log "PostgreSQL configured (password saved in docker-compose.yml)"
    fi
  fi

  if $with_nginx; then
    info "Adding Nginx reverse proxy..."
    mkdir -p "$DATA_DIR/nginx"
    cat >> "$COMPOSE_FILE" <<YAML

  nginx:
    image: nginx:alpine
    container_name: synapse-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ${DATA_DIR}/nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ${DATA_DIR}/nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - synapse
YAML

    cat > "$DATA_DIR/nginx/nginx.conf" <<NGINX
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # Replace with your actual SSL cert paths
    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;

    client_max_body_size 50M;

    location ~ ^(/_matrix|/_synapse/client) {
        proxy_pass http://synapse:8008;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
        proxy_read_timeout 600s;
    }
}
NGINX
    log "Nginx config written to $DATA_DIR/nginx/nginx.conf"
    warn "Add your SSL certificates to $DATA_DIR/nginx/certs/"
  fi

  log "Initialization complete!"
  echo ""
  echo "Next steps:"
  echo "  1. Review config: $DATA_DIR/homeserver.yaml"
  echo "  2. Start server:  $0 start"
  echo "  3. Create admin:  $0 register admin YourPassword --admin"
}

cmd_start() {
  require_domain
  if [[ -f "$COMPOSE_FILE" ]]; then
    info "Starting Synapse via Docker Compose..."
    cd "$DATA_DIR" && $COMPOSE_CMD up -d
  else
    info "Starting Synapse container..."
    docker run -d \
      --name "$CONTAINER_NAME" \
      --restart unless-stopped \
      -v "$DATA_DIR:/data" \
      -p 8008:8008 \
      -p 8448:8448 \
      -e SYNAPSE_CONFIG_PATH=/data/homeserver.yaml \
      matrixdotorg/synapse:latest
  fi
  sleep 3
  cmd_status
}

cmd_stop() {
  if [[ -f "$COMPOSE_FILE" ]]; then
    cd "$DATA_DIR" && $COMPOSE_CMD down
  else
    docker stop "$CONTAINER_NAME" 2>/dev/null && docker rm "$CONTAINER_NAME" 2>/dev/null
  fi
  log "Synapse stopped"
}

cmd_restart() {
  cmd_stop
  cmd_start
}

cmd_status() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    err "Synapse is not running"
    return 1
  fi

  local version
  version=$(curl -s http://localhost:8008/_matrix/federation/v1/version 2>/dev/null | jq -r '.server.version // "unknown"')

  local uptime
  uptime=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER_NAME" 2>/dev/null)

  log "Synapse is running"
  echo "  Version:  $version"
  echo "  Domain:   ${DOMAIN:-unknown}"
  echo "  Started:  $uptime"
  echo "  API:      http://localhost:8008"

  # Try to get user/room counts via admin API
  if [[ -n "$(get_admin_token 2>/dev/null)" ]]; then
    local user_count room_count
    user_count=$(api GET "/users?limit=1" 2>/dev/null | jq -r '.total // "?"')
    room_count=$(api GET "/rooms?limit=1" 2>/dev/null | jq -r '.total_rooms // "?"')
    echo "  Users:    $user_count"
    echo "  Rooms:    $room_count"
  fi

  # Memory usage
  local mem
  mem=$(docker stats --no-stream --format '{{.MemUsage}}' "$CONTAINER_NAME" 2>/dev/null | cut -d'/' -f1)
  echo "  Memory:   ${mem:-unknown}"
}

cmd_register() {
  require_running
  local username="$1" password="$2" admin_flag=""
  shift 2
  [[ "${1:-}" == "--admin" ]] && admin_flag="--admin"

  info "Registering user: $username"
  docker exec -it "$CONTAINER_NAME" register_new_matrix_user \
    -u "$username" \
    -p "$password" \
    $admin_flag \
    -c /data/homeserver.yaml \
    http://localhost:8008

  # If admin, get and save access token
  if [[ -n "$admin_flag" ]]; then
    local token
    token=$(curl -s -X POST http://localhost:8008/_matrix/client/r0/login \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"m.login.password\",\"user\":\"$username\",\"password\":\"$password\"}" \
      | jq -r '.access_token // empty')

    if [[ -n "$token" ]]; then
      echo "$token" > "$DATA_DIR/.admin_token"
      chmod 600 "$DATA_DIR/.admin_token"
      log "Admin token saved to $DATA_DIR/.admin_token"
    fi
  fi

  log "User @$username:$DOMAIN registered"
}

cmd_users() {
  require_running
  info "Registered users:"
  api GET "/users?limit=100" | jq -r '.users[] | "  \(.name) \(if .admin == 1 then "(admin)" else "" end) — active: \(.last_seen_ts // "never")"'
}

cmd_deactivate() {
  require_running
  local user_id="$1"
  info "Deactivating $user_id..."
  api POST "/deactivate/$user_id" -d '{"erase": false}'
  log "User $user_id deactivated"
}

cmd_reset_password() {
  require_running
  local user_id="$1" new_pass="$2"
  api POST "/reset_password/$user_id" -d "{\"new_password\":\"$new_pass\",\"logout_devices\":true}"
  log "Password reset for $user_id"
}

cmd_rooms() {
  require_running
  info "Rooms:"
  api GET "/rooms?limit=100" | jq -r '.rooms[] | "  \(.name // .canonical_alias // .room_id) — members: \(.joined_members) — state: \(.join_rules)"'
}

cmd_create_room() {
  require_running
  local name="$1" visibility="private"
  [[ "${2:-}" == "--public" ]] && visibility="public"

  local token
  token=$(get_admin_token)

  curl -s -X POST http://localhost:8008/_matrix/client/r0/createRoom \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$name\",\"visibility\":\"$visibility\",\"preset\":\"${visibility}_chat\"}" \
    | jq -r '.room_id'

  log "Room '$name' created ($visibility)"
}

cmd_delete_room() {
  require_running
  local room_id="$1"
  info "Deleting room $room_id..."
  api DELETE "/rooms/$room_id" -d '{"purge": true}'
  log "Room $room_id deleted"
}

cmd_health() {
  require_running
  echo ""
  cmd_status
  echo ""

  # Database size
  if [[ "$DB_TYPE" == "postgres" ]]; then
    local db_size
    db_size=$(docker exec synapse-postgres psql -U synapse -t -c "SELECT pg_size_pretty(pg_database_size('synapse'));" 2>/dev/null | tr -d ' ')
    echo "  Database: ${db_size:-unknown} (PostgreSQL)"
  else
    local db_file="$DATA_DIR/homeserver.db"
    if [[ -f "$db_file" ]]; then
      local size
      size=$(du -h "$db_file" | cut -f1)
      echo "  Database: $size (SQLite)"
    fi
  fi

  # Media store size
  local media_dir="$DATA_DIR/media_store"
  if [[ -d "$media_dir" ]]; then
    local media_size
    media_size=$(du -sh "$media_dir" 2>/dev/null | cut -f1)
    echo "  Media:    $media_size"
  fi

  # Federation check
  local fed_result
  fed_result=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8008/_matrix/federation/v1/version" 2>/dev/null)
  if [[ "$fed_result" == "200" ]]; then
    echo "  Federation: ✅ OK"
  else
    echo "  Federation: ❌ Error (HTTP $fed_result)"
  fi
  echo ""
}

cmd_logs() {
  local tail_lines=100
  [[ "${1:-}" == "--tail" ]] && tail_lines="${2:-100}"
  if [[ -f "$COMPOSE_FILE" ]]; then
    cd "$DATA_DIR" && $COMPOSE_CMD logs --tail "$tail_lines" synapse
  else
    docker logs --tail "$tail_lines" "$CONTAINER_NAME"
  fi
}

cmd_backup() {
  require_running
  local backup_dir="${1:-.}"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_file="$backup_dir/matrix-backup-$timestamp.tar.gz"

  info "Creating backup..."

  # Stop for consistent backup (optional — can skip for hot backup)
  warn "Stopping Synapse for consistent backup..."
  cmd_stop

  tar -czf "$backup_file" \
    -C "$(dirname "$DATA_DIR")" \
    "$(basename "$DATA_DIR")" \
    --exclude='*/postgres' 2>/dev/null

  # If PostgreSQL, dump separately
  if docker ps -a --format '{{.Names}}' | grep -q synapse-postgres; then
    cmd_start
    sleep 2
    docker exec synapse-postgres pg_dump -U synapse synapse | gzip > "$backup_dir/matrix-db-$timestamp.sql.gz"
    log "PostgreSQL dump: $backup_dir/matrix-db-$timestamp.sql.gz"
  else
    cmd_start
  fi

  log "Backup complete: $backup_file"
  ls -lh "$backup_file"
}

cmd_restore() {
  local backup_file="$1"
  if [[ ! -f "$backup_file" ]]; then
    err "Backup file not found: $backup_file"
    exit 1
  fi

  warn "This will overwrite your current Matrix data!"
  info "Restoring from $backup_file..."

  cmd_stop 2>/dev/null || true

  tar -xzf "$backup_file" -C "$(dirname "$DATA_DIR")"

  cmd_start
  log "Restore complete"
}

cmd_purge_history() {
  require_running
  local days="${1:-90}"
  local cutoff_ms
  cutoff_ms=$(( ($(date +%s) - days * 86400) * 1000 ))

  info "Purging messages older than $days days..."

  # Get all rooms and purge each
  local rooms
  rooms=$(api GET "/rooms?limit=500" | jq -r '.rooms[].room_id')

  local count=0
  for room_id in $rooms; do
    api POST "/purge_history/$room_id" \
      -d "{\"purge_up_to_ts\": $cutoff_ms, \"delete_local_events\": true}" &>/dev/null
    count=$((count + 1))
  done

  log "Purge initiated for $count rooms (messages older than $days days)"
}

cmd_compress_state() {
  require_running
  info "Running state compressor..."
  docker exec "$CONTAINER_NAME" python -m synapse._scripts.synapse_port_db \
    --curses 2>/dev/null || warn "State compression requires manual setup. See: https://github.com/matrix-org/rust-synapse-compress-state"
}

cmd_federation_test() {
  require_domain

  echo "Federation Test for $DOMAIN"
  echo "─────────────────────────────"

  # Check .well-known
  local well_known
  well_known=$(curl -s "https://$DOMAIN/.well-known/matrix/server" 2>/dev/null)
  if [[ -n "$well_known" ]]; then
    log ".well-known/matrix/server: $well_known"
  else
    warn "No .well-known found — federation may use SRV records or direct connection"
  fi

  # Check SRV record
  local srv
  srv=$(dig +short _matrix._tcp."$DOMAIN" SRV 2>/dev/null)
  if [[ -n "$srv" ]]; then
    log "SRV record: $srv"
  else
    info "No SRV record (using .well-known or direct)"
  fi

  # Check federation endpoint
  local fed_version
  fed_version=$(curl -sk "https://$DOMAIN:8448/_matrix/federation/v1/version" 2>/dev/null)
  if [[ -n "$fed_version" ]]; then
    log "Federation endpoint responding: $(echo "$fed_version" | jq -r '.server.name + " " + .server.version' 2>/dev/null)"
  else
    warn "Federation endpoint not reachable on port 8448"
  fi

  # Use Matrix federation tester
  info "Testing via federation tester API..."
  local test_result
  test_result=$(curl -s "https://federationtester.matrix.org/api/report?server_name=$DOMAIN" 2>/dev/null | jq -r '.FederationOK // "unknown"')
  if [[ "$test_result" == "true" ]]; then
    log "Federation: ✅ PASSED"
  elif [[ "$test_result" == "false" ]]; then
    err "Federation: ❌ FAILED"
    echo "  Check: https://federationtester.matrix.org/#$DOMAIN"
  else
    warn "Federation tester unavailable"
  fi
}

cmd_db_size() {
  require_running
  if docker ps --format '{{.Names}}' | grep -q synapse-postgres; then
    docker exec synapse-postgres psql -U synapse -c "
      SELECT pg_size_pretty(pg_database_size('synapse')) AS total_size;
      SELECT relname AS table, pg_size_pretty(pg_total_relation_size(C.oid)) AS size
      FROM pg_class C LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
      WHERE nspname = 'public' ORDER BY pg_total_relation_size(C.oid) DESC LIMIT 10;
    "
  else
    local db_file="$DATA_DIR/homeserver.db"
    if [[ -f "$db_file" ]]; then
      echo "SQLite database: $(du -h "$db_file" | cut -f1)"
    fi
  fi
}

cmd_vacuum() {
  info "Vacuuming SQLite database..."
  local db_file="$DATA_DIR/homeserver.db"
  if [[ -f "$db_file" ]]; then
    cmd_stop
    sqlite3 "$db_file" "VACUUM;"
    cmd_start
    log "Vacuum complete"
  else
    warn "No SQLite database found (using PostgreSQL?)"
  fi
}

# ─── Main ────────────────────────────────────────────────────────
check_deps

case "${1:-help}" in
  init)             shift; cmd_init "$@" ;;
  start)            cmd_start ;;
  stop)             cmd_stop ;;
  restart)          cmd_restart ;;
  status)           cmd_status ;;
  register)         shift; cmd_register "$@" ;;
  users)            cmd_users ;;
  deactivate)       shift; cmd_deactivate "$@" ;;
  reset-password)   shift; cmd_reset_password "$@" ;;
  rooms)            cmd_rooms ;;
  create-room)      shift; cmd_create_room "$@" ;;
  delete-room)      shift; cmd_delete_room "$@" ;;
  health)           cmd_health ;;
  logs)             shift; cmd_logs "$@" ;;
  backup)           shift; cmd_backup "$@" ;;
  restore)          shift; cmd_restore "$@" ;;
  purge-history)    shift; cmd_purge_history "$@" ;;
  compress-state)   cmd_compress_state ;;
  federation-test)  cmd_federation_test ;;
  db-size)          cmd_db_size ;;
  vacuum)           cmd_vacuum ;;
  help|*)
    echo "Matrix Synapse Manager"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Setup:"
    echo "  init [--domain D] [--with-postgres] [--with-nginx]  Initialize server"
    echo "  start                                                Start Synapse"
    echo "  stop                                                 Stop Synapse"
    echo "  restart                                              Restart Synapse"
    echo "  status                                               Show server status"
    echo ""
    echo "Users:"
    echo "  register <user> <pass> [--admin]    Register a user"
    echo "  users                               List all users"
    echo "  deactivate <@user:domain>           Deactivate a user"
    echo "  reset-password <@user:domain> <pw>  Reset password"
    echo ""
    echo "Rooms:"
    echo "  create-room <name> [--public]       Create a room"
    echo "  rooms                               List all rooms"
    echo "  delete-room <room_id>               Delete a room"
    echo ""
    echo "Maintenance:"
    echo "  health                              Full health check"
    echo "  logs [--tail N]                     View logs"
    echo "  backup [dir]                        Backup all data"
    echo "  restore <file>                      Restore from backup"
    echo "  purge-history [days]                Purge old messages"
    echo "  compress-state                      Compress state tables"
    echo "  federation-test                     Test federation"
    echo "  db-size                             Show database size"
    echo "  vacuum                              Vacuum SQLite DB"
    echo ""
    echo "Environment:"
    echo "  MATRIX_DOMAIN       Server domain (required)"
    echo "  MATRIX_DATA_DIR     Data directory (default: ~/matrix-synapse)"
    echo "  MATRIX_DB_TYPE      postgres or sqlite (default: sqlite)"
    echo "  MATRIX_ADMIN_TOKEN  Admin API token"
    ;;
esac
