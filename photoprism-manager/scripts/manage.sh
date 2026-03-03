#!/bin/bash
# PhotoPrism Manager — Management Script
set -euo pipefail

DATA_DIR="${PHOTOPRISM_DATA_DIR:-/opt/photoprism}"
COMPOSE_FILE="$DATA_DIR/docker-compose.yml"
CONTAINER="photoprism"

usage() {
  cat <<EOF
PhotoPrism Manager — Management Commands

Usage:
  $(basename "$0") status                     Show PhotoPrism status
  $(basename "$0") import DIR [--move]         Import photos from directory
  $(basename "$0") index [--full]              Index/re-index photos
  $(basename "$0") backup DIR                  Backup database & config
  $(basename "$0") restore FILE               Restore from backup
  $(basename "$0") password NEWPASS            Change admin password
  $(basename "$0") config                      Show current configuration
  $(basename "$0") update                      Update to latest version
  $(basename "$0") cleanup                     Remove orphaned files
  $(basename "$0") optimize                    Optimize database
  $(basename "$0") logs [-f] [--tail N]        View container logs
  $(basename "$0") restart                     Restart PhotoPrism
  $(basename "$0") stop                        Stop PhotoPrism
  $(basename "$0") start                       Start PhotoPrism
  $(basename "$0") nginx-config DOMAIN         Generate Nginx reverse proxy config
  $(basename "$0") cron-setup --interval TIME  Set up scheduled indexing
  $(basename "$0") uninstall                   Remove PhotoPrism completely
EOF
  exit 1
}

check_running() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "❌ PhotoPrism container is not running"
    echo "   Start it: cd $DATA_DIR && docker compose up -d"
    exit 1
  fi
}

cmd_status() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "❌ PhotoPrism is not running"
    echo "   Config: $COMPOSE_FILE"
    [ -f "$COMPOSE_FILE" ] && echo "   Start: cd $DATA_DIR && docker compose up -d"
    return
  fi

  local port=$(docker port "$CONTAINER" 2342/tcp 2>/dev/null | head -1 | cut -d: -f2)
  local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER" 2>/dev/null)
  local status_json

  # Try API
  status_json=$(curl -s "http://localhost:${port:-2342}/api/v1/config" 2>/dev/null || echo "{}")

  echo "📊 PhotoPrism Status"
  echo "   Container: $(docker inspect --format='{{.State.Status}}' $CONTAINER 2>/dev/null || echo 'unknown')"
  echo "   Started: $uptime"
  echo "   Port: ${port:-2342}"
  echo "   URL: http://localhost:${port:-2342}"

  # Disk usage
  local storage_size=$(du -sh "$DATA_DIR/storage" 2>/dev/null | cut -f1 || echo "unknown")
  local photos_dir=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/photoprism/originals"}}{{.Source}}{{end}}{{end}}' "$CONTAINER" 2>/dev/null)
  local photos_size=$(du -sh "$photos_dir" 2>/dev/null | cut -f1 || echo "unknown")

  echo "   Storage: $storage_size (cache/thumbnails)"
  echo "   Photos: $photos_size (originals at $photos_dir)"

  # Photo counts from API
  if [ "$status_json" != "{}" ]; then
    local count=$(echo "$status_json" | jq -r '.count.all // "unknown"' 2>/dev/null || echo "unknown")
    local videos=$(echo "$status_json" | jq -r '.count.videos // "unknown"' 2>/dev/null || echo "unknown")
    echo "   Photos: $count"
    echo "   Videos: $videos"
  fi
}

cmd_import() {
  check_running
  local import_dir="$1"
  local move_flag=""

  if [ "${2:-}" = "--move" ]; then
    move_flag="--move"
  fi

  if [ ! -d "$import_dir" ]; then
    echo "❌ Directory not found: $import_dir"
    exit 1
  fi

  local file_count=$(find "$import_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.heic" -o -iname "*.heif" -o -iname "*.raw" -o -iname "*.cr2" -o -iname "*.nef" -o -iname "*.arw" -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.webm" -o -iname "*.webp" -o -iname "*.tiff" -o -iname "*.bmp" \) 2>/dev/null | wc -l)
  local total_size=$(du -sh "$import_dir" 2>/dev/null | cut -f1)

  echo "📸 Importing photos from $import_dir"
  echo "   Found $file_count media files ($total_size)"

  # Copy files to import directory
  local import_dest="$DATA_DIR/import/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$import_dest"

  if [ -n "$move_flag" ]; then
    echo "   Moving files to import directory..."
    mv "$import_dir"/* "$import_dest/" 2>/dev/null || true
  else
    echo "   Copying files to import directory..."
    cp -r "$import_dir"/* "$import_dest/" 2>/dev/null || true
  fi

  # Trigger import via CLI
  echo "   Triggering PhotoPrism import..."
  docker exec "$CONTAINER" photoprism import

  echo "   ✅ Import complete!"
  echo "   🔍 Run 'bash scripts/manage.sh index' to classify photos"
}

cmd_index() {
  check_running
  local full_flag=""

  if [ "${1:-}" = "--full" ]; then
    full_flag="--cleanup"
    echo "🔍 Starting full re-index (this may take a while)..."
  else
    echo "🔍 Starting quick index (new photos only)..."
  fi

  docker exec "$CONTAINER" photoprism index $full_flag

  echo "✅ Indexing complete!"
}

cmd_backup() {
  local backup_dir="$1"
  mkdir -p "$backup_dir"

  local timestamp=$(date +%Y-%m-%d_%H%M%S)
  local backup_file="$backup_dir/photoprism-backup-${timestamp}.tar.gz"

  echo "💾 Creating backup..."

  # Database backup
  local db_backup="$DATA_DIR/backup-db-${timestamp}.sql"
  if docker ps --format '{{.Names}}' | grep -q "photoprism-mariadb"; then
    echo "   Backing up MariaDB database..."
    docker exec photoprism-mariadb mariadb-dump -u photoprism -pphotoprism_db_pass photoprism > "$db_backup" 2>/dev/null
  else
    echo "   SQLite database (included in storage)"
  fi

  # Create tarball
  echo "   Compressing..."
  tar -czf "$backup_file" \
    -C "$DATA_DIR" \
    docker-compose.yml \
    storage/config \
    storage/sidecar \
    ${db_backup:+$(basename "$db_backup")} \
    2>/dev/null || true

  # Cleanup temp
  [ -f "$db_backup" ] && rm -f "$db_backup"

  local size=$(du -sh "$backup_file" | cut -f1)
  echo "✅ Backup created: $backup_file ($size)"
}

cmd_restore() {
  local backup_file="$1"

  if [ ! -f "$backup_file" ]; then
    echo "❌ Backup file not found: $backup_file"
    exit 1
  fi

  echo "⚠️  This will overwrite current config and sidecar data."
  echo "   Backup file: $backup_file"
  echo ""

  # Stop containers
  echo "   Stopping PhotoPrism..."
  cd "$DATA_DIR" && docker compose down 2>/dev/null || true

  # Extract
  echo "   Extracting backup..."
  tar -xzf "$backup_file" -C "$DATA_DIR"

  # Restore database if SQL dump exists
  if ls "$DATA_DIR"/backup-db-*.sql 1>/dev/null 2>&1; then
    echo "   Starting MariaDB for restore..."
    cd "$DATA_DIR" && docker compose up -d mariadb
    sleep 5
    local sql_file=$(ls -1 "$DATA_DIR"/backup-db-*.sql | head -1)
    docker exec -i photoprism-mariadb mariadb -u photoprism -pphotoprism_db_pass photoprism < "$sql_file"
    rm -f "$sql_file"
  fi

  # Start everything
  echo "   Starting PhotoPrism..."
  cd "$DATA_DIR" && docker compose up -d

  echo "✅ Restore complete!"
}

cmd_password() {
  check_running
  local new_pass="$1"

  if [ ${#new_pass} -lt 8 ]; then
    echo "❌ Password must be at least 8 characters"
    exit 1
  fi

  docker exec "$CONTAINER" photoprism passwd --password "$new_pass"
  echo "✅ Admin password updated"
}

cmd_update() {
  echo "🔄 Updating PhotoPrism..."

  cd "$DATA_DIR"

  # Get current image ID
  local old_id=$(docker images --format '{{.ID}}' photoprism/photoprism:latest 2>/dev/null)

  # Pull latest
  echo "   Pulling latest image..."
  docker compose pull

  local new_id=$(docker images --format '{{.ID}}' photoprism/photoprism:latest 2>/dev/null)

  if [ "$old_id" = "$new_id" ]; then
    echo "   ✅ Already on latest version"
    return
  fi

  # Restart with new image
  echo "   Restarting with new version..."
  docker compose up -d

  echo "✅ PhotoPrism updated!"
}

cmd_cleanup() {
  check_running
  echo "🧹 Running cleanup..."
  docker exec "$CONTAINER" photoprism cleanup
  echo "✅ Cleanup complete"
}

cmd_optimize() {
  check_running
  echo "⚡ Optimizing database..."
  docker exec "$CONTAINER" photoprism optimize
  echo "✅ Optimization complete"
}

cmd_logs() {
  local follow=""
  local tail="100"

  while [[ $# -gt 0 ]]; do
    case $1 in
      -f) follow="--follow"; shift ;;
      --tail) tail="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  cd "$DATA_DIR"
  docker compose logs $follow --tail "$tail" photoprism
}

cmd_restart() {
  echo "🔄 Restarting PhotoPrism..."
  cd "$DATA_DIR" && docker compose restart
  echo "✅ Restarted"
}

cmd_stop() {
  echo "⏹️  Stopping PhotoPrism..."
  cd "$DATA_DIR" && docker compose down
  echo "✅ Stopped"
}

cmd_start() {
  echo "▶️  Starting PhotoPrism..."
  cd "$DATA_DIR" && docker compose up -d
  echo "✅ Started"
}

cmd_config() {
  echo "📋 PhotoPrism Configuration"
  echo "   Data dir: $DATA_DIR"
  echo "   Compose: $COMPOSE_FILE"
  echo ""
  if [ -f "$COMPOSE_FILE" ]; then
    echo "--- docker-compose.yml ---"
    cat "$COMPOSE_FILE"
  else
    echo "❌ No compose file found at $COMPOSE_FILE"
  fi
}

cmd_nginx_config() {
  local domain="$1"
  local port=$(docker port "$CONTAINER" 2342/tcp 2>/dev/null | head -1 | cut -d: -f2 || echo "2342")

  local config_file="/etc/nginx/sites-available/photoprism"

  cat <<NGINX
# PhotoPrism Nginx Reverse Proxy — $domain
# Save to: $config_file
# Enable: sudo ln -s $config_file /etc/nginx/sites-enabled/
# Test: sudo nginx -t && sudo systemctl reload nginx

server {
    listen 80;
    server_name ${domain};

    client_max_body_size 500M;

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINX
}

cmd_cron_setup() {
  local interval="${1:-6h}"
  local hours="${interval%h}"

  if ! [[ "$hours" =~ ^[0-9]+$ ]]; then
    echo "❌ Invalid interval. Use format: 6h, 12h, 24h"
    exit 1
  fi

  local cron_expr="0 */${hours} * * *"
  local cron_cmd="cd $DATA_DIR && docker compose exec -T photoprism photoprism index >> /var/log/photoprism-index.log 2>&1"

  (crontab -l 2>/dev/null | grep -v "photoprism index"; echo "$cron_expr $cron_cmd") | crontab -

  echo "✅ Cron job added: index every ${hours} hours"
  echo "   Schedule: $cron_expr"
  echo "   Log: /var/log/photoprism-index.log"
}

cmd_uninstall() {
  echo "⚠️  This will remove PhotoPrism containers and images."
  echo "   Your photos in the originals directory will NOT be deleted."
  echo ""

  cd "$DATA_DIR" && docker compose down --rmi all --volumes 2>/dev/null || true

  echo "✅ PhotoPrism containers and images removed"
  echo "   Config remains at: $DATA_DIR"
  echo "   To fully remove: rm -rf $DATA_DIR"
}

# Parse arguments
ACTION="${1:-}"
shift 2>/dev/null || true

case "$ACTION" in
  status) cmd_status ;;
  import) cmd_import "${1:?'Import directory required'}" "${2:-}" ;;
  index) cmd_index "${1:-}" ;;
  backup) cmd_backup "${1:?'Backup directory required'}" ;;
  restore) cmd_restore "${1:?'Backup file required'}" ;;
  password) cmd_password "${1:?'New password required'}" ;;
  config) cmd_config ;;
  update) cmd_update ;;
  cleanup) cmd_cleanup ;;
  optimize) cmd_optimize ;;
  logs) cmd_logs "$@" ;;
  restart) cmd_restart ;;
  stop) cmd_stop ;;
  start) cmd_start ;;
  nginx-config) cmd_nginx_config "${1:?'Domain required'}" ;;
  cron-setup) cmd_cron_setup "${2:-6h}" ;;
  uninstall) cmd_uninstall ;;
  *) usage ;;
esac
