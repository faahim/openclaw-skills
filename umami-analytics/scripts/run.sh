#!/bin/bash
# Umami Analytics Manager — Main Script
set -euo pipefail

UMAMI_DIR="${UMAMI_DIR:-$HOME/.umami}"
UMAMI_URL="${UMAMI_URL:-http://localhost:3000}"
UMAMI_USER="${UMAMI_USER:-admin}"
UMAMI_PASSWORD="${UMAMI_PASSWORD:-umami}"
UMAMI_PORT="${UMAMI_PORT:-3000}"
UMAMI_DB_PASSWORD="${UMAMI_DB_PASSWORD:-$(openssl rand -hex 16 2>/dev/null || echo 'umami-db-secret')}"

ACTION="${1:-help}"
shift || true

# ─── Helpers ───────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { echo "❌ $*" >&2; exit 1; }

get_token() {
  local token
  token=$(curl -sf -X POST "$UMAMI_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$UMAMI_USER\",\"password\":\"$UMAMI_PASSWORD\"}" | jq -r '.token')
  [[ "$token" != "null" && -n "$token" ]] || err "Auth failed. Check UMAMI_URL, UMAMI_USER, UMAMI_PASSWORD."
  echo "$token"
}

api() {
  local method="$1" endpoint="$2"
  shift 2
  local token
  token=$(get_token)
  curl -sf -X "$method" "$UMAMI_URL/api$endpoint" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    "$@"
}

compose_cmd() {
  if docker compose version &>/dev/null 2>&1; then
    docker compose -f "$UMAMI_DIR/docker-compose.yml" "$@"
  else
    docker-compose -f "$UMAMI_DIR/docker-compose.yml" "$@"
  fi
}

# ─── Parse named args ─────────────────────────────────────
declare -A ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --*) key="${1#--}"; ARGS["$key"]="${2:-true}"; shift 2 || shift ;;
    *) shift ;;
  esac
done

# ─── Commands ─────────────────────────────────────────────

cmd_deploy() {
  local port="${ARGS[port]:-$UMAMI_PORT}"
  local domain="${ARGS[domain]:-localhost}"

  mkdir -p "$UMAMI_DIR"

  # Generate docker-compose.yml
  cat > "$UMAMI_DIR/docker-compose.yml" <<YAML
version: '3'
services:
  umami:
    image: ghcr.io/umami-software/umami:postgresql-latest
    container_name: umami
    ports:
      - "${port}:3000"
    environment:
      DATABASE_URL: postgresql://umami:${UMAMI_DB_PASSWORD}@umami-db:5432/umami
      DATABASE_TYPE: postgresql
      APP_SECRET: $(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | base64 | tr -d '\n')
    depends_on:
      umami-db:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/api/heartbeat || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3

  umami-db:
    image: postgres:15-alpine
    container_name: umami-db
    environment:
      POSTGRES_DB: umami
      POSTGRES_USER: umami
      POSTGRES_PASSWORD: ${UMAMI_DB_PASSWORD}
    volumes:
      - umami-db-data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U umami"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  umami-db-data:
YAML

  # Save config
  cat > "$UMAMI_DIR/.env" <<ENV
UMAMI_URL=http://${domain}:${port}
UMAMI_PORT=${port}
UMAMI_DB_PASSWORD=${UMAMI_DB_PASSWORD}
ENV

  log "🚀 Deploying Umami on port $port..."
  compose_cmd up -d

  # Wait for healthy
  log "⏳ Waiting for Umami to be ready..."
  local attempts=0
  while ! curl -sf "http://localhost:$port/api/heartbeat" &>/dev/null; do
    sleep 2
    attempts=$((attempts + 1))
    [[ $attempts -lt 30 ]] || err "Umami failed to start after 60s. Check: docker logs umami"
  done

  echo ""
  echo "✅ Umami deployed successfully!"
  echo "   URL: http://${domain}:${port}"
  echo "   Login: admin / umami"
  echo "   ⚠️  Change the default password immediately!"
  echo ""
  echo "   Config saved to: $UMAMI_DIR/.env"
}

cmd_status() {
  compose_cmd ps 2>/dev/null || echo "Umami is not deployed. Run: bash scripts/run.sh deploy"
}

cmd_logs() {
  local lines="${ARGS[lines]:-50}"
  compose_cmd logs --tail="$lines" -f 2>/dev/null || echo "Umami is not running."
}

cmd_restart() {
  log "🔄 Restarting Umami..."
  compose_cmd restart
  log "✅ Umami restarted."
}

cmd_stop() {
  log "🛑 Stopping Umami..."
  compose_cmd down
  log "✅ Umami stopped."
}

cmd_add_site() {
  local name="${ARGS[name]:-}" domain="${ARGS[domain]:-}"
  [[ -n "$name" ]] || err "Missing --name"
  [[ -n "$domain" ]] || err "Missing --domain"

  local result
  result=$(api POST "/websites" -d "{\"name\":\"$name\",\"domain\":\"$domain\"}")
  local website_id
  website_id=$(echo "$result" | jq -r '.id // .websiteId // empty')

  if [[ -n "$website_id" ]]; then
    echo "✅ Website added: $name ($domain)"
    echo "📊 Tracking script:"
    echo "   <script async src=\"$UMAMI_URL/script.js\" data-website-id=\"$website_id\"></script>"
  else
    echo "❌ Failed to add website. Response: $result"
  fi
}

cmd_get_script() {
  local domain="${ARGS[domain]:-}"
  [[ -n "$domain" ]] || err "Missing --domain"

  local websites
  websites=$(api GET "/websites")
  local site
  site=$(echo "$websites" | jq -r ".data[] | select(.domain==\"$domain\")")

  if [[ -n "$site" ]]; then
    local id name
    id=$(echo "$site" | jq -r '.id')
    name=$(echo "$site" | jq -r '.name')
    echo "📊 Tracking script for $name ($domain):"
    echo "   <script async src=\"$UMAMI_URL/script.js\" data-website-id=\"$id\"></script>"
  else
    err "Website $domain not found. Add it first: bash scripts/run.sh add-site --name 'Name' --domain '$domain'"
  fi
}

cmd_stats() {
  local domain="${ARGS[domain]:-}"
  local from="${ARGS[from]:-$(date -u +%Y-%m-%d)}"
  local to="${ARGS[to]:-$(date -u +%Y-%m-%d)}"

  local start_ms end_ms
  start_ms=$(date -d "$from" +%s000 2>/dev/null || date -j -f "%Y-%m-%d" "$from" +%s000 2>/dev/null)
  end_ms=$(date -d "$to 23:59:59" +%s999 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$to 23:59:59" +%s999 2>/dev/null)

  local websites
  websites=$(api GET "/websites" | jq -r '.data // .[]')

  echo "📊 Umami Stats — $from$([ "$from" != "$to" ] && echo " to $to" || true)"
  echo "┌──────────────────────┬──────────┬────────┬──────────┬──────────┐"
  printf "│ %-20s │ %8s │ %6s │ %8s │ %8s │\n" "Site" "Visitors" "Views" "Bounced" "Avg Time"
  echo "├──────────────────────┼──────────┼────────┼──────────┼──────────┤"

  echo "$websites" | jq -c '.' | while read -r site; do
    local id site_domain site_name
    id=$(echo "$site" | jq -r '.id')
    site_domain=$(echo "$site" | jq -r '.domain')
    site_name=$(echo "$site" | jq -r '.name')

    # Filter by domain if specified
    if [[ -n "$domain" && "$site_domain" != "$domain" ]]; then
      continue
    fi

    local stats
    stats=$(api GET "/websites/$id/stats?startAt=$start_ms&endAt=$end_ms" 2>/dev/null || echo '{}')

    local visitors views bounces avg_time bounce_rate
    visitors=$(echo "$stats" | jq -r '.visitors.value // 0')
    views=$(echo "$stats" | jq -r '.pageviews.value // 0')
    bounces=$(echo "$stats" | jq -r '.bounces.value // 0')
    avg_time=$(echo "$stats" | jq -r '.totaltime.value // 0')

    if [[ $visitors -gt 0 ]]; then
      bounce_rate=$(awk "BEGIN {printf \"%.1f%%\", ($bounces/$visitors)*100}")
      local mins secs
      mins=$((avg_time / visitors / 60))
      secs=$((avg_time / visitors % 60))
      avg_time="${mins}m ${secs}s"
    else
      bounce_rate="0.0%"
      avg_time="0m 0s"
    fi

    local display_name="${site_name:0:20}"
    printf "│ %-20s │ %8s │ %6s │ %8s │ %8s │\n" "$display_name" "$visitors" "$views" "$bounce_rate" "$avg_time"
  done

  echo "└──────────────────────┴──────────┴────────┴──────────┴──────────┘"
}

cmd_top_pages() {
  local domain="${ARGS[domain]:-}" limit="${ARGS[limit]:-10}"
  [[ -n "$domain" ]] || err "Missing --domain"

  local websites
  websites=$(api GET "/websites")
  local id
  id=$(echo "$websites" | jq -r ".data[] | select(.domain==\"$domain\") | .id")
  [[ -n "$id" ]] || err "Website $domain not found."

  local start_ms end_ms
  start_ms=$(date -d "$(date +%Y-%m-%d)" +%s000 2>/dev/null || date +%s000)
  end_ms=$(date +%s999)

  local pages
  pages=$(api GET "/websites/$id/metrics?startAt=$start_ms&endAt=$end_ms&type=url")

  echo "📄 Top Pages — $domain"
  echo "$pages" | jq -r ".[0:$limit][] | \"  \\(.y) views — \\(.x)\""
}

cmd_top_referrers() {
  local domain="${ARGS[domain]:-}"
  [[ -n "$domain" ]] || err "Missing --domain"

  local websites
  websites=$(api GET "/websites")
  local id
  id=$(echo "$websites" | jq -r ".data[] | select(.domain==\"$domain\") | .id")
  [[ -n "$id" ]] || err "Website $domain not found."

  local start_ms end_ms
  start_ms=$(date -d "$(date +%Y-%m-%d)" +%s000 2>/dev/null || date +%s000)
  end_ms=$(date +%s999)

  local referrers
  referrers=$(api GET "/websites/$id/metrics?startAt=$start_ms&endAt=$end_ms&type=referrer")

  echo "🔗 Top Referrers — $domain"
  echo "$referrers" | jq -r '.[0:10][] | "  \(.y) visits — \(.x)"'
}

cmd_backup() {
  local output="${ARGS[output]:-$UMAMI_DIR/backup-$(date +%Y%m%d-%H%M%S).sql.gz}"
  local schedule="${ARGS[schedule]:-}"

  if [[ -n "$schedule" ]]; then
    local cron_entry="$schedule cd $(pwd) && bash scripts/run.sh backup --output $output"
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    log "✅ Backup scheduled: $schedule"
    log "   Output: $output"
    return
  fi

  log "💾 Backing up Umami database..."
  docker exec umami-db pg_dump -U umami umami | gzip > "$output"
  local size
  size=$(du -h "$output" | cut -f1)
  log "✅ Backup saved: $output ($size)"
}

cmd_restore() {
  local input="${ARGS[input]:-}"
  [[ -n "$input" ]] || err "Missing --input"
  [[ -f "$input" ]] || err "File not found: $input"

  log "⚠️  This will REPLACE all Umami data. Ctrl+C to cancel (5s)..."
  sleep 5

  log "📥 Restoring from $input..."
  gunzip -c "$input" | docker exec -i umami-db psql -U umami umami
  log "✅ Database restored. Restarting Umami..."
  compose_cmd restart umami
  log "✅ Restore complete."
}

cmd_update() {
  local version="${ARGS[version]:-latest}"
  log "🔄 Updating Umami to $version..."

  # Pull new image
  if [[ "$version" == "latest" ]]; then
    docker pull ghcr.io/umami-software/umami:postgresql-latest
  else
    docker pull "ghcr.io/umami-software/umami:postgresql-v$version"
    sed -i "s|ghcr.io/umami-software/umami:postgresql-.*|ghcr.io/umami-software/umami:postgresql-v$version|" "$UMAMI_DIR/docker-compose.yml"
  fi

  compose_cmd up -d
  log "✅ Umami updated to $version."
}

cmd_check_update() {
  local current
  current=$(docker inspect umami --format='{{.Config.Image}}' 2>/dev/null || echo "not deployed")
  echo "Current: $current"
  echo "Check latest: https://github.com/umami-software/umami/releases"
}

cmd_change_password() {
  local user="${ARGS[user]:-admin}" new_pass="${ARGS[new-password]:-}"
  [[ -n "$new_pass" ]] || err "Missing --new-password"

  # Get user list, find user ID
  local users
  users=$(api GET "/admin/users")
  local user_id
  user_id=$(echo "$users" | jq -r ".[] | select(.username==\"$user\") | .id")
  [[ -n "$user_id" ]] || err "User $user not found."

  api POST "/admin/users/$user_id" -d "{\"password\":\"$new_pass\"}" > /dev/null
  echo "✅ Password changed for $user."
}

cmd_token() {
  get_token
}

cmd_share() {
  local domain="${ARGS[domain]:-}"
  [[ -n "$domain" ]] || err "Missing --domain"

  local websites
  websites=$(api GET "/websites")
  local id
  id=$(echo "$websites" | jq -r ".data[] | select(.domain==\"$domain\") | .id")
  [[ -n "$id" ]] || err "Website $domain not found."

  local share_id
  share_id=$(openssl rand -hex 8)
  echo "📊 Public dashboard: $UMAMI_URL/share/$share_id"
  echo "   (Note: Enable sharing in Umami UI for site $domain)"
}

cmd_proxy_config() {
  local type="${ARGS[type]:-nginx}" domain="${ARGS[domain]:-}"
  [[ -n "$domain" ]] || err "Missing --domain"

  local port="${UMAMI_PORT:-3000}"

  case "$type" in
    nginx)
      cat <<NGINX
# Nginx config for Umami — $domain
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX
      ;;
    caddy)
      cat <<CADDY
# Caddyfile for Umami — $domain
$domain {
    reverse_proxy 127.0.0.1:$port
}
CADDY
      ;;
    *) err "Unknown proxy type: $type (use nginx or caddy)" ;;
  esac
}

cmd_report() {
  local period="${ARGS[period]:-week}"
  local telegram="${ARGS[telegram]:-false}"

  # Calculate date range
  local from to
  case "$period" in
    day) from=$(date -u +%Y-%m-%d); to="$from" ;;
    week) from=$(date -u -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -u -v-7d +%Y-%m-%d); to=$(date -u +%Y-%m-%d) ;;
    month) from=$(date -u -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -u -v-30d +%Y-%m-%d); to=$(date -u +%Y-%m-%d) ;;
    *) err "Unknown period: $period (use day, week, month)" ;;
  esac

  echo "📊 Umami Report — $period ($from to $to)"

  # Collect stats
  local report
  report=$(bash "$0" stats --from "$from" --to "$to" 2>&1)
  echo "$report"

  if [[ "$telegram" != "false" && -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -sf -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT_ID" \
      -d text="$report" \
      -d parse_mode="HTML" > /dev/null
    echo ""
    echo "📨 Report sent to Telegram."
  fi
}

cmd_help() {
  cat <<HELP
Umami Analytics Manager

Usage: bash scripts/run.sh <command> [options]

Commands:
  deploy              Deploy Umami (--port, --domain)
  status              Show container status
  logs                View logs (--lines)
  restart             Restart Umami
  stop                Stop Umami
  add-site            Add website (--name, --domain)
  get-script          Get tracking script (--domain)
  stats               View traffic stats (--domain, --from, --to)
  top-pages           Top pages (--domain, --limit)
  top-referrers       Top referrers (--domain)
  backup              Backup database (--output, --schedule)
  restore             Restore from backup (--input)
  update              Update Umami (--version)
  check-update        Check for updates
  change-password     Change user password (--user, --new-password)
  token               Get API auth token
  share               Create public dashboard link (--domain)
  proxy-config        Generate reverse proxy config (--type, --domain)
  report              Traffic report (--period, --telegram)
  help                Show this help

Environment:
  UMAMI_URL           Server URL (default: http://localhost:3000)
  UMAMI_USER          Username (default: admin)
  UMAMI_PASSWORD      Password (default: umami)
  UMAMI_PORT          Port (default: 3000)
  TELEGRAM_BOT_TOKEN  For Telegram alerts
  TELEGRAM_CHAT_ID    For Telegram alerts
HELP
}

# ─── Dispatch ─────────────────────────────────────────────
case "$ACTION" in
  deploy) cmd_deploy ;;
  status) cmd_status ;;
  logs) cmd_logs ;;
  restart) cmd_restart ;;
  stop) cmd_stop ;;
  add-site) cmd_add_site ;;
  get-script) cmd_get_script ;;
  stats) cmd_stats ;;
  top-pages) cmd_top_pages ;;
  top-referrers) cmd_top_referrers ;;
  backup) cmd_backup ;;
  restore) cmd_restore ;;
  update) cmd_update ;;
  check-update) cmd_check_update ;;
  change-password) cmd_change_password ;;
  token) cmd_token ;;
  share) cmd_share ;;
  proxy-config) cmd_proxy_config ;;
  report) cmd_report ;;
  help|--help|-h) cmd_help ;;
  *) err "Unknown command: $ACTION. Run: bash scripts/run.sh help" ;;
esac
