#!/bin/bash
# Nextcloud Manager — Install, configure, and manage Nextcloud via Docker
# Usage: bash nextcloud-manager.sh <command> [options]

set -euo pipefail

VERSION="1.0.0"
NC_DIR="${NEXTCLOUD_DATA_DIR:-$HOME/.nextcloud}"
NC_PREFIX="${NEXTCLOUD_PREFIX:-nextcloud}"
COMPOSE_FILE="$NC_DIR/docker-compose.yml"
ENV_FILE="$NC_DIR/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_err()  { echo -e "${RED}❌ $1${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# ─── OCC helper (runs Nextcloud occ commands inside container) ───
occ() {
  docker exec -u www-data "${NC_PREFIX}-nextcloud-1" php occ "$@" 2>/dev/null || \
  docker exec -u www-data "${NC_PREFIX}_nextcloud_1" php occ "$@" 2>/dev/null
}

# ─── PREFLIGHT ───
cmd_preflight() {
  echo "🔍 Checking prerequisites..."
  local ok=true

  # Docker
  if command -v docker &>/dev/null; then
    log_ok "Docker $(docker --version | grep -oP '\d+\.\d+\.\d+')"
  else
    log_err "Docker not installed. Install: https://docs.docker.com/engine/install/"
    ok=false
  fi

  # Docker Compose
  if docker compose version &>/dev/null; then
    log_ok "Docker Compose $(docker compose version --short 2>/dev/null)"
  elif docker-compose --version &>/dev/null; then
    log_warn "Using legacy docker-compose. Consider upgrading to Docker Compose v2."
  else
    log_err "Docker Compose not found."
    ok=false
  fi

  # Ports
  for port in 80 443 8080; do
    if ! ss -tlnp 2>/dev/null | grep -q ":${port} " && \
       ! netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
      log_ok "Port $port available"
    else
      log_warn "Port $port in use"
    fi
  done

  # Disk space
  local avail_gb
  avail_gb=$(df -BG "$HOME" | awk 'NR==2 {gsub("G",""); print $4}')
  if [ "$avail_gb" -ge 10 ]; then
    log_ok "Disk space: ${avail_gb}GB available"
  else
    log_warn "Low disk: ${avail_gb}GB available (recommend 10GB+)"
  fi

  # Memory
  local mem_gb
  mem_gb=$(free -g 2>/dev/null | awk '/Mem:/ {print $2}' || echo "unknown")
  if [ "$mem_gb" != "unknown" ] && [ "$mem_gb" -ge 2 ]; then
    log_ok "Memory: ${mem_gb}GB RAM"
  elif [ "$mem_gb" != "unknown" ]; then
    log_warn "Memory: ${mem_gb}GB RAM (recommend 2GB+)"
  fi

  $ok && log_ok "All prerequisites met!" || log_err "Some prerequisites missing."
}

# ─── INSTALL ───
cmd_install() {
  local domain="localhost"
  local port="8080"
  local db="postgres"
  local cache="redis"
  local ssl=""
  local admin_user="admin"
  local admin_pass=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --domain) domain="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --db) db="$2"; shift 2 ;;
      --cache) cache="$2"; shift 2 ;;
      --ssl) ssl="$2"; shift 2 ;;
      --admin-user) admin_user="$2"; shift 2 ;;
      --admin-pass) admin_pass="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "$admin_pass" ] && admin_pass=$(openssl rand -base64 16)

  echo "🚀 Installing Nextcloud..."
  echo "   Domain: $domain"
  echo "   Port: $port"
  echo "   Database: $db"
  echo "   Cache: $cache"
  echo "   Admin: $admin_user"

  mkdir -p "$NC_DIR"

  # Generate passwords
  local db_pass
  db_pass=$(openssl rand -base64 24)
  local redis_pass
  redis_pass=$(openssl rand -base64 24)

  # Write .env
  cat > "$ENV_FILE" <<EOF
NEXTCLOUD_DOMAIN=$domain
NEXTCLOUD_PORT=$port
DB_PASSWORD=$db_pass
REDIS_PASSWORD=$redis_pass
NEXTCLOUD_ADMIN_USER=$admin_user
NEXTCLOUD_ADMIN_PASSWORD=$admin_pass
EOF

  # Generate docker-compose.yml
  cat > "$COMPOSE_FILE" <<YAML
services:
  nextcloud:
    image: nextcloud:29-apache
    container_name: ${NC_PREFIX}-nextcloud-1
    restart: unless-stopped
    ports:
      - "${port}:80"
    volumes:
      - nextcloud_data:/var/www/html
      - ${NC_DIR}/custom_apps:/var/www/html/custom_apps
      - ${NC_DIR}/config:/var/www/html/config
      - ${NC_DIR}/data:/var/www/html/data
    environment:
      - NEXTCLOUD_ADMIN_USER=${admin_user}
      - NEXTCLOUD_ADMIN_PASSWORD=\${NEXTCLOUD_ADMIN_PASSWORD}
      - NEXTCLOUD_TRUSTED_DOMAINS=${domain}
YAML

  if [ "$db" = "postgres" ]; then
    cat >> "$COMPOSE_FILE" <<YAML
      - POSTGRES_HOST=db
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD=\${DB_PASSWORD}
    depends_on:
      db:
        condition: service_healthy
YAML
    if [ "$cache" = "redis" ]; then
      cat >> "$COMPOSE_FILE" <<YAML
      redis:
        condition: service_started
YAML
    fi

    cat >> "$COMPOSE_FILE" <<YAML

  db:
    image: postgres:16-alpine
    container_name: ${NC_PREFIX}-db-1
    restart: unless-stopped
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD=\${DB_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nextcloud"]
      interval: 10s
      timeout: 5s
      retries: 5
YAML
  elif [ "$db" = "sqlite" ]; then
    # No db service needed
    :
  fi

  if [ "$cache" = "redis" ]; then
    cat >> "$COMPOSE_FILE" <<YAML

  redis:
    image: redis:7-alpine
    container_name: ${NC_PREFIX}-redis-1
    restart: unless-stopped
    command: redis-server --requirepass \${REDIS_PASSWORD}
YAML
  fi

  cat >> "$COMPOSE_FILE" <<YAML

volumes:
  nextcloud_data:
YAML

  if [ "$db" = "postgres" ]; then
    echo "  postgres_data:" >> "$COMPOSE_FILE"
  fi

  # Create directories
  mkdir -p "$NC_DIR"/{custom_apps,config,data}

  # Start
  cd "$NC_DIR"
  docker compose --env-file "$ENV_FILE" up -d

  echo ""
  log_ok "Nextcloud installing... (first start takes 1-2 minutes)"
  log_info "URL: http://${domain}:${port}"
  log_info "Admin: $admin_user"
  log_info "Password: $admin_pass"
  log_info "Config: $NC_DIR"
  echo ""
  log_warn "Save your admin password! It won't be shown again."

  # Wait for ready
  echo -n "Waiting for Nextcloud to start..."
  for i in $(seq 1 60); do
    if curl -sf "http://localhost:${port}/status.php" &>/dev/null; then
      echo ""
      log_ok "Nextcloud is ready!"
      break
    fi
    echo -n "."
    sleep 2
  done
}

# ─── STATUS ───
cmd_status() {
  if [ ! -f "$COMPOSE_FILE" ]; then
    log_err "Nextcloud not installed. Run: bash nextcloud-manager.sh install"
    exit 1
  fi

  source "$ENV_FILE"
  local port="${NEXTCLOUD_PORT:-8080}"
  local domain="${NEXTCLOUD_DOMAIN:-localhost}"

  # Check if running
  cd "$NC_DIR"
  if ! docker compose ps --status running 2>/dev/null | grep -q nextcloud; then
    log_err "Nextcloud is not running"
    echo "Start with: cd $NC_DIR && docker compose up -d"
    exit 1
  fi

  # Get version
  local version
  version=$(occ --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")

  # Get user count
  local users
  users=$(occ user:list --output=json 2>/dev/null | jq 'length' || echo "?")

  # Get storage
  local storage_used
  storage_used=$(du -sh "$NC_DIR/data" 2>/dev/null | cut -f1 || echo "?")

  echo "📊 Nextcloud Status"
  echo "━━━━━━━━━━━━━━━━━━━━━━"
  log_ok "Nextcloud $version running at http://${domain}:${port}"

  # DB type
  local db_type="SQLite"
  docker compose ps 2>/dev/null | grep -q "db" && db_type="PostgreSQL"
  echo -e "   📦 Database: $db_type"

  # Cache
  docker compose ps 2>/dev/null | grep -q "redis" && echo -e "   🔄 Cache: Redis"

  echo -e "   💾 Storage: $storage_used used"
  echo -e "   👥 Users: $users"

  # SSL check
  if [ "$domain" != "localhost" ]; then
    local ssl_expiry
    ssl_expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    [ -n "$ssl_expiry" ] && echo -e "   🔒 SSL: expires $ssl_expiry"
  fi
}

# ─── USER MANAGEMENT ───
cmd_user() {
  local action="${1:-list}"
  shift || true

  case "$action" in
    create)
      local username="" display_name="" email="" quota="" groups=""
      while [[ $# -gt 0 ]]; do
        case $1 in
          --username) username="$2"; shift 2 ;;
          --display-name) display_name="$2"; shift 2 ;;
          --email) email="$2"; shift 2 ;;
          --quota) quota="$2"; shift 2 ;;
          --groups) groups="$2"; shift 2 ;;
          *) shift ;;
        esac
      done
      [ -z "$username" ] && { log_err "Username required (--username)"; exit 1; }

      local pass
      pass=$(openssl rand -base64 12)
      echo "$pass" | occ user:add --password-from-env "$username" --display-name "${display_name:-$username}"
      [ -n "$email" ] && occ user:setting "$username" settings email "$email"
      [ -n "$quota" ] && occ user:setting "$username" files quota "$quota"
      if [ -n "$groups" ]; then
        IFS=',' read -ra grps <<< "$groups"
        for g in "${grps[@]}"; do
          occ group:add "$g" 2>/dev/null || true
          occ group:adduser "$g" "$username"
        done
      fi
      log_ok "Created user: $username (password: $pass)"
      ;;

    list)
      echo "👥 Nextcloud Users"
      echo "━━━━━━━━━━━━━━━━━━"
      occ user:list --output=json | jq -r 'to_entries[] | "  \(.key) — \(.value)"'
      ;;

    disable)
      local username=""
      while [[ $# -gt 0 ]]; do
        case $1 in --username) username="$2"; shift 2 ;; *) shift ;; esac
      done
      occ user:disable "$username"
      log_ok "Disabled user: $username"
      ;;

    enable)
      local username=""
      while [[ $# -gt 0 ]]; do
        case $1 in --username) username="$2"; shift 2 ;; *) shift ;; esac
      done
      occ user:enable "$username"
      log_ok "Enabled user: $username"
      ;;

    reset-password)
      local username=""
      while [[ $# -gt 0 ]]; do
        case $1 in --username) username="$2"; shift 2 ;; *) shift ;; esac
      done
      local new_pass
      new_pass=$(openssl rand -base64 12)
      echo "$new_pass" | occ user:resetpassword --password-from-env "$username"
      log_ok "Password reset for $username: $new_pass"
      ;;

    *)
      echo "Usage: nextcloud-manager.sh user {create|list|disable|enable|reset-password}"
      ;;
  esac
}

# ─── APP MANAGEMENT ───
cmd_app() {
  local action="${1:-list}"
  shift || true

  case "$action" in
    list)
      if [[ "${1:-}" == "--available" ]]; then
        echo "📦 Available Apps"
        occ app:list --output=json | jq -r '.disabled | keys[]' | head -30
      else
        echo "📦 Installed Apps"
        occ app:list --output=json | jq -r '.enabled | keys[]'
      fi
      ;;

    install)
      for app in "$@"; do
        echo -n "Installing $app... "
        occ app:install "$app" && log_ok "$app installed" || log_err "Failed to install $app"
      done
      ;;

    update)
      if [[ "${1:-}" == "--all" ]]; then
        occ app:update --all
        log_ok "All apps updated"
      else
        occ app:update "$@"
      fi
      ;;

    disable)
      local name=""
      while [[ $# -gt 0 ]]; do
        case $1 in --name) name="$2"; shift 2 ;; *) name="$1"; shift ;; esac
      done
      occ app:disable "$name"
      log_ok "Disabled app: $name"
      ;;

    *)
      echo "Usage: nextcloud-manager.sh app {list|install|update|disable}"
      ;;
  esac
}

# ─── BACKUP ───
cmd_backup() {
  local action="${1:-create}"
  shift || true

  case "$action" in
    create)
      local output="${NC_DIR}/backups"
      local compress=false
      local s3_endpoint=""

      while [[ $# -gt 0 ]]; do
        case $1 in
          --output) output="$2"; shift 2 ;;
          --compress) compress=true; shift ;;
          --s3-endpoint) s3_endpoint="$2"; shift 2 ;;
          *) shift ;;
        esac
      done

      local timestamp
      timestamp=$(date +%Y-%m-%d_%H%M%S)
      local backup_dir="$output/$timestamp"

      echo "📦 Creating backup..."

      # Enable maintenance mode
      occ maintenance:mode --on 2>/dev/null || true

      if [[ "$output" == s3://* ]]; then
        # S3 backup
        local tmpdir
        tmpdir=$(mktemp -d)
        _do_backup "$tmpdir"
        if $compress; then
          tar -czf "$tmpdir/nextcloud-backup-$timestamp.tar.gz" -C "$tmpdir" data config db
          aws s3 cp "$tmpdir/nextcloud-backup-$timestamp.tar.gz" "${output}/nextcloud-backup-$timestamp.tar.gz" ${s3_endpoint:+--endpoint-url "$s3_endpoint"}
        else
          aws s3 sync "$tmpdir" "${output}/$timestamp/" ${s3_endpoint:+--endpoint-url "$s3_endpoint"}
        fi
        rm -rf "$tmpdir"
      else
        mkdir -p "$backup_dir"
        _do_backup "$backup_dir"
        if $compress; then
          tar -czf "${backup_dir}.tar.gz" -C "$output" "$timestamp"
          rm -rf "$backup_dir"
          log_ok "Backup saved to ${backup_dir}.tar.gz"
        else
          log_ok "Backup saved to $backup_dir"
        fi
      fi

      # Disable maintenance mode
      occ maintenance:mode --off 2>/dev/null || true
      ;;

    schedule)
      local cron_expr="" output="${NC_DIR}/backups" keep=7 compress=false

      while [[ $# -gt 0 ]]; do
        case $1 in
          --cron) cron_expr="$2"; shift 2 ;;
          --output) output="$2"; shift 2 ;;
          --keep) keep="$2"; shift 2 ;;
          --compress) compress=true; shift ;;
          *) shift ;;
        esac
      done

      local script_path
      script_path=$(readlink -f "$0")
      local cron_cmd="$cron_expr $script_path backup create --output $output"
      $compress && cron_cmd="$cron_cmd --compress"

      # Add cleanup of old backups
      cron_cmd="$cron_cmd && find $output -maxdepth 1 -mtime +$keep -delete"

      (crontab -l 2>/dev/null | grep -v "nextcloud-manager.*backup"; echo "$cron_cmd") | crontab -
      log_ok "Backup scheduled: $cron_expr (keeping $keep days)"
      ;;

    restore)
      local from=""
      while [[ $# -gt 0 ]]; do
        case $1 in --from) from="$2"; shift 2 ;; *) shift ;; esac
      done

      [ -z "$from" ] && { log_err "Specify backup with --from"; exit 1; }

      echo "⚠️  Restoring from: $from"
      echo "   This will replace current data!"
      read -rp "   Continue? (y/N) " confirm
      [ "$confirm" != "y" ] && exit 0

      occ maintenance:mode --on

      # If tar.gz, extract first
      local restore_dir="$from"
      if [[ "$from" == *.tar.gz ]]; then
        restore_dir=$(mktemp -d)
        tar -xzf "$from" -C "$restore_dir"
      fi

      # Restore files
      [ -d "$restore_dir/data" ] && rsync -a "$restore_dir/data/" "$NC_DIR/data/"
      [ -d "$restore_dir/config" ] && rsync -a "$restore_dir/config/" "$NC_DIR/config/"

      # Restore database
      if [ -f "$restore_dir/db/nextcloud.sql" ]; then
        docker exec -i "${NC_PREFIX}-db-1" psql -U nextcloud nextcloud < "$restore_dir/db/nextcloud.sql"
      fi

      occ maintenance:mode --off
      occ files:scan --all
      log_ok "Restore complete!"
      ;;

    *)
      echo "Usage: nextcloud-manager.sh backup {create|schedule|restore}"
      ;;
  esac
}

_do_backup() {
  local dest="$1"
  mkdir -p "$dest"/{data,config,db}

  # Copy data
  rsync -a "$NC_DIR/data/" "$dest/data/" 2>/dev/null || cp -r "$NC_DIR/data/"* "$dest/data/" 2>/dev/null || true

  # Copy config
  rsync -a "$NC_DIR/config/" "$dest/config/" 2>/dev/null || cp -r "$NC_DIR/config/"* "$dest/config/" 2>/dev/null || true

  # Dump database
  if docker ps --format '{{.Names}}' | grep -q "${NC_PREFIX}-db"; then
    docker exec "${NC_PREFIX}-db-1" pg_dump -U nextcloud nextcloud > "$dest/db/nextcloud.sql" 2>/dev/null || true
  fi

  log_info "Backed up: data, config, database"
}

# ─── HEALTH ───
cmd_health() {
  local fix=false
  [[ "${1:-}" == "--fix" ]] && fix=true

  source "$ENV_FILE" 2>/dev/null || true
  local port="${NEXTCLOUD_PORT:-8080}"
  local issues=0

  echo "🏥 Nextcloud Health Report"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Web server
  local start_ms end_ms
  start_ms=$(date +%s%3N)
  if curl -sf "http://localhost:${port}/status.php" &>/dev/null; then
    end_ms=$(date +%s%3N)
    log_ok "Web server: responding ($((end_ms - start_ms))ms)"
  else
    log_err "Web server: not responding"
    ((issues++))
  fi

  # Database
  if docker exec "${NC_PREFIX}-db-1" pg_isready -U nextcloud &>/dev/null; then
    log_ok "Database: connected"
  elif docker ps --format '{{.Names}}' | grep -q "${NC_PREFIX}-db"; then
    log_err "Database: container running but not accepting connections"
    ((issues++))
  else
    log_warn "Database: SQLite mode (no separate DB container)"
  fi

  # Redis
  if docker exec "${NC_PREFIX}-redis-1" redis-cli ping &>/dev/null; then
    log_ok "Redis cache: connected"
  elif docker ps --format '{{.Names}}' | grep -q "${NC_PREFIX}-redis"; then
    log_warn "Redis: container running but not responding"
  fi

  # Cron
  local last_cron
  last_cron=$(occ config:app:get core lastcron 2>/dev/null || echo "0")
  if [ "$last_cron" != "0" ]; then
    local now
    now=$(date +%s)
    local diff=$(( (now - last_cron) / 60 ))
    if [ "$diff" -lt 15 ]; then
      log_ok "Cron jobs: last run ${diff} min ago"
    else
      log_warn "Cron jobs: last run ${diff} min ago (should be <15 min)"
      if $fix; then
        occ background:cron
        log_info "Fixed: set background jobs to cron mode"
      fi
    fi
  fi

  # Disk space
  local used
  used=$(du -sh "$NC_DIR/data" 2>/dev/null | cut -f1 || echo "unknown")
  local avail
  avail=$(df -h "$NC_DIR" | awk 'NR==2 {print $4}')
  log_ok "Disk space: $used used, $avail available"

  # Security scan via occ
  local warnings
  warnings=$(occ check 2>&1 | grep -c "warning" || echo "0")
  if [ "$warnings" -gt 0 ]; then
    log_warn "Security: $warnings warnings"
    occ check 2>&1 | grep "warning" | sed 's/^/   /'
  else
    log_ok "Security: no warnings"
  fi

  echo ""
  if [ "$issues" -eq 0 ]; then
    log_ok "All checks passed!"
  else
    log_err "$issues issue(s) found"
  fi
}

# ─── TUNE ───
cmd_tune() {
  local upload_limit=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --upload-limit) upload_limit="$2"; shift 2 ;;
      --cache) shift 2 ;;
      --file-locking) shift ;;
      *) shift ;;
    esac
  done

  echo "⚡ Tuning Nextcloud..."

  # PHP memory
  occ config:system:set memory_limit --value 512M 2>/dev/null || true
  log_ok "PHP memory limit: 512MB"

  # Upload limit
  local ul="${upload_limit:-16G}"
  docker exec "${NC_PREFIX}-nextcloud-1" bash -c "
    echo 'upload_max_filesize=${ul}' > /usr/local/etc/php/conf.d/uploads.ini
    echo 'post_max_size=${ul}' >> /usr/local/etc/php/conf.d/uploads.ini
  " 2>/dev/null && log_ok "Upload limit: $ul"

  # OPcache
  docker exec "${NC_PREFIX}-nextcloud-1" bash -c "
    cat > /usr/local/etc/php/conf.d/opcache-recommended.ini <<'EOF'
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=1
opcache.save_comments=1
EOF
  " 2>/dev/null && log_ok "OPcache optimized"

  # Background jobs via cron
  occ background:cron 2>/dev/null && log_ok "Background jobs: cron mode"

  # Redis file locking
  source "$ENV_FILE" 2>/dev/null || true
  if [ -n "${REDIS_PASSWORD:-}" ]; then
    occ config:system:set redis host --value redis 2>/dev/null
    occ config:system:set redis port --value 6379 --type integer 2>/dev/null
    occ config:system:set redis password --value "$REDIS_PASSWORD" 2>/dev/null
    occ config:system:set memcache.local --value '\OC\Memcache\Redis' 2>/dev/null
    occ config:system:set memcache.locking --value '\OC\Memcache\Redis' 2>/dev/null
    log_ok "Redis caching + file locking enabled"
  fi

  # Default phone region
  occ config:system:set default_phone_region --value US 2>/dev/null
  log_ok "Default phone region: US"

  echo ""
  log_ok "Tuning complete! Restart recommended:"
  echo "   cd $NC_DIR && docker compose restart nextcloud"
}

# ─── CONFIG ───
cmd_config() {
  local action="${1:-get}"
  shift || true

  case "$action" in
    set)
      local key="" value=""
      while [[ $# -gt 0 ]]; do
        case $1 in
          --key) key="$2"; shift 2 ;;
          --value) value="$2"; shift 2 ;;
          *) shift ;;
        esac
      done
      if [ "$key" = "trusted_domains" ]; then
        IFS=',' read -ra domains <<< "$value"
        local i=0
        for d in "${domains[@]}"; do
          occ config:system:set trusted_domains "$i" --value "$d"
          ((i++))
        done
        log_ok "Trusted domains updated"
      else
        occ config:system:set "$key" --value "$value"
        log_ok "Set $key = $value"
      fi
      ;;

    get)
      local key=""
      while [[ $# -gt 0 ]]; do
        case $1 in --key) key="$2"; shift 2 ;; *) shift ;; esac
      done
      if [ -n "$key" ]; then
        occ config:system:get "$key"
      else
        occ config:list system
      fi
      ;;
  esac
}

# ─── MAINTENANCE ───
cmd_maintenance() {
  local action="${1:-status}"
  shift || true

  case "$action" in
    on)  occ maintenance:mode --on; log_ok "Maintenance mode ON" ;;
    off) occ maintenance:mode --off; log_ok "Maintenance mode OFF" ;;
    db-repair)
      occ db:add-missing-indices
      occ db:convert-filecache-bigint
      log_ok "Database maintenance complete"
      ;;
    files-scan)
      if [[ "${1:-}" == "--all" ]]; then
        occ files:scan --all
      else
        occ files:scan "$@"
      fi
      log_ok "File scan complete"
      ;;
    *)
      echo "Usage: nextcloud-manager.sh maintenance {on|off|db-repair|files-scan}"
      ;;
  esac
}

# ─── UPGRADE ───
cmd_upgrade() {
  local action="${1:-check}"
  shift || true

  case "$action" in
    check)
      local current
      current=$(occ --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
      echo "Current version: $current"
      occ update:check 2>/dev/null || echo "Check manually at https://nextcloud.com/changelog"
      ;;

    run)
      local backup_first=false
      [[ "${1:-}" == "--backup-first" ]] && backup_first=true

      if $backup_first; then
        echo "Creating pre-upgrade backup..."
        cmd_backup create --compress
      fi

      echo "⬆️  Upgrading Nextcloud..."
      cd "$NC_DIR"
      docker compose pull nextcloud
      docker compose up -d nextcloud
      sleep 10
      occ upgrade
      occ db:add-missing-indices
      log_ok "Upgrade complete!"
      cmd_status
      ;;
  esac
}

# ─── LOGS ───
cmd_logs() {
  local tail=50
  while [[ $# -gt 0 ]]; do
    case $1 in --tail) tail="$2"; shift 2 ;; *) shift ;; esac
  done
  cd "$NC_DIR"
  docker compose logs --tail "$tail" nextcloud
}

# ─── MAIN ROUTER ───
case "${1:-help}" in
  preflight)    shift; cmd_preflight "$@" ;;
  install)      shift; cmd_install "$@" ;;
  status)       shift; cmd_status "$@" ;;
  user)         shift; cmd_user "$@" ;;
  app)          shift; cmd_app "$@" ;;
  backup)       shift; cmd_backup "$@" ;;
  health)       shift; cmd_health "$@" ;;
  tune)         shift; cmd_tune "$@" ;;
  config)       shift; cmd_config "$@" ;;
  maintenance)  shift; cmd_maintenance "$@" ;;
  upgrade)      shift; cmd_upgrade "$@" ;;
  logs)         shift; cmd_logs "$@" ;;
  cron)
    shift
    case "${1:-}" in
      enable)
        # Add Nextcloud cron to system crontab
        cron_line="*/5 * * * * docker exec -u www-data ${NC_PREFIX}-nextcloud-1 php cron.php"
        (crontab -l 2>/dev/null | grep -v "nextcloud.*cron.php"; echo "$cron_line") | crontab -
        log_ok "Nextcloud cron enabled (every 5 min)"
        ;;
      *) echo "Usage: nextcloud-manager.sh cron enable" ;;
    esac
    ;;
  version) echo "Nextcloud Manager v$VERSION" ;;
  help|*)
    cat <<EOF
Nextcloud Manager v$VERSION

Usage: nextcloud-manager.sh <command> [options]

Commands:
  preflight              Check prerequisites
  install                Install Nextcloud via Docker
  status                 Show instance status
  user <action>          Manage users (create/list/disable/enable/reset-password)
  app <action>           Manage apps (list/install/update/disable)
  backup <action>        Backup/restore (create/schedule/restore)
  health [--fix]         Run health checks
  tune                   Apply performance optimizations
  config <action>        Get/set configuration
  maintenance <action>   Maintenance mode and repairs
  upgrade <action>       Check for and apply upgrades
  logs [--tail N]        Show container logs
  cron enable            Enable system cron for background jobs
  version                Show version

Examples:
  nextcloud-manager.sh install --domain cloud.example.com --db postgres --cache redis
  nextcloud-manager.sh user create --username alice --email alice@example.com --quota 10G
  nextcloud-manager.sh backup create --output /backups --compress
  nextcloud-manager.sh health --fix
EOF
    ;;
esac
