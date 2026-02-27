#!/bin/bash
# Plausible Analytics Manager — Main entry point
set -euo pipefail

CONFIG_DIR="${PLAUSIBLE_CONFIG_DIR:-$HOME/.plausible}"
CONFIG_FILE="$CONFIG_DIR/config.env"
INSTALL_DIR="${PLAUSIBLE_INSTALL_DIR:-/opt/plausible}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        set -a; source "$CONFIG_FILE"; set +a
    fi
}

save_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
PLAUSIBLE_URL=${PLAUSIBLE_URL:-}
PLAUSIBLE_API_KEY=${PLAUSIBLE_API_KEY:-}
PLAUSIBLE_INSTALL_DIR=${INSTALL_DIR}
ADMIN_EMAIL=${ADMIN_EMAIL:-}
EOF
    chmod 600 "$CONFIG_FILE"
}

cmd_setup() {
    local domain="" admin_email="" admin_name="" admin_password="" port=8000
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain) domain="$2"; shift 2 ;;
            --admin-email) admin_email="$2"; shift 2 ;;
            --admin-name) admin_name="$2"; shift 2 ;;
            --admin-password) admin_password="$2"; shift 2 ;;
            --port) port="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done
    
    # Interactive prompts for missing values
    if [ -z "$domain" ]; then
        read -rp "Dashboard domain (e.g. analytics.yourdomain.com): " domain
    fi
    if [ -z "$admin_email" ]; then
        read -rp "Admin email: " admin_email
    fi
    if [ -z "$admin_name" ]; then
        read -rp "Admin name [Admin]: " admin_name
        admin_name="${admin_name:-Admin}"
    fi
    if [ -z "$admin_password" ]; then
        admin_password=$(openssl rand -base64 16)
        echo -e "${YELLOW}Generated password: $admin_password${NC}"
    fi
    
    # Generate secret key
    local secret_key
    secret_key=$(openssl rand -base64 48 | tr -d '\n')
    
    echo -e "\n${CYAN}🚀 Deploying Plausible Analytics...${NC}\n"
    
    # Create install directory
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown "$USER:$USER" "$INSTALL_DIR"
    
    # Generate docker-compose.yml
    cat > "$INSTALL_DIR/docker-compose.yml" <<YAML
services:
  plausible_db:
    image: postgres:16-alpine
    restart: always
    volumes:
      - db-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  plausible_events_db:
    image: clickhouse/clickhouse-server:24.3-alpine
    restart: always
    volumes:
      - event-data:/var/lib/clickhouse
      - event-logs:/var/log/clickhouse-server
      - ./clickhouse/clickhouse-config.xml:/etc/clickhouse-server/config.d/logging.xml:ro
      - ./clickhouse/clickhouse-user-config.xml:/etc/clickhouse-server/users.d/logging.xml:ro
    ulimits:
      nofile:
        soft: 262144
        hard: 262144
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8123/ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  plausible:
    image: ghcr.io/plausible/community-edition:v2.1
    restart: always
    command: sh -c "sleep 10 && /entrypoint.sh db createdb && /entrypoint.sh db migrate && /entrypoint.sh run"
    depends_on:
      plausible_db:
        condition: service_healthy
      plausible_events_db:
        condition: service_healthy
    ports:
      - "${port}:8000"
    env_file:
      - plausible-conf.env

volumes:
  db-data:
  event-data:
  event-logs:
YAML
    
    # Generate plausible config
    cat > "$INSTALL_DIR/plausible-conf.env" <<ENV
BASE_URL=https://${domain}
SECRET_KEY_BASE=${secret_key}
DATABASE_URL=postgres://postgres:postgres@plausible_db:5432/plausible_db
CLICKHOUSE_DATABASE_URL=http://plausible_events_db:8123/plausible_events_db
DISABLE_REGISTRATION=invite_only
MAILER_EMAIL=${admin_email}
ENV

    # ClickHouse config
    mkdir -p "$INSTALL_DIR/clickhouse"
    cat > "$INSTALL_DIR/clickhouse/clickhouse-config.xml" <<XML
<clickhouse>
    <logger>
        <level>warning</level>
        <console>true</console>
    </logger>
    <query_thread_log remove="remove"/>
    <query_log remove="remove"/>
    <text_log remove="remove"/>
    <trace_log remove="remove"/>
    <metric_log remove="remove"/>
    <asynchronous_metric_log remove="remove"/>
    <session_log remove="remove"/>
    <part_log remove="remove"/>
</clickhouse>
XML

    cat > "$INSTALL_DIR/clickhouse/clickhouse-user-config.xml" <<XML
<clickhouse>
    <profiles>
        <default>
            <log_queries>0</log_queries>
            <log_query_threads>0</log_query_threads>
        </default>
    </profiles>
</clickhouse>
XML

    # Pull and start
    cd "$INSTALL_DIR"
    echo "⏳ Pulling Docker images..."
    docker compose pull --quiet
    
    echo "⏳ Starting containers..."
    docker compose up -d
    
    # Wait for Plausible to be ready
    echo "⏳ Waiting for Plausible to start..."
    local retries=30
    while [ $retries -gt 0 ]; do
        if curl -sf "http://localhost:${port}/api/health" &>/dev/null; then
            break
        fi
        sleep 2
        retries=$((retries - 1))
    done
    
    if [ $retries -eq 0 ]; then
        echo -e "${YELLOW}⚠️ Plausible may still be starting. Check: docker compose -f $INSTALL_DIR/docker-compose.yml logs plausible${NC}"
    fi
    
    # Save config
    PLAUSIBLE_URL="https://${domain}"
    ADMIN_EMAIL="$admin_email"
    save_config
    
    echo -e "\n${GREEN}✅ Plausible Analytics deployed!${NC}"
    echo -e "   Dashboard: ${CYAN}https://${domain}${NC}"
    echo -e "   Local:     ${CYAN}http://localhost:${port}${NC}"
    echo -e "   Admin:     ${admin_email}"
    echo -e "   Password:  ${admin_password}"
    echo -e ""
    echo -e "   ${YELLOW}Tracking snippet:${NC}"
    echo -e "   <script defer data-domain=\"yourdomain.com\" src=\"https://${domain}/js/script.js\"></script>"
    echo -e ""
    echo -e "   ${YELLOW}Next steps:${NC}"
    echo -e "   1. Set up reverse proxy (Nginx/Caddy) pointing to localhost:${port}"
    echo -e "   2. Register admin account at https://${domain}"
    echo -e "   3. Add your first site in the dashboard"
    echo -e "   4. Add the tracking snippet to your website"
}

cmd_status() {
    load_config
    echo -e "${CYAN}📊 Plausible Analytics Status${NC}\n"
    
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        cd "$INSTALL_DIR"
        docker compose ps
        echo ""
        
        # Check health
        local port
        port=$(grep -oP '"\K\d+(?=:8000")' "$INSTALL_DIR/docker-compose.yml" 2>/dev/null || echo "8000")
        if curl -sf "http://localhost:${port}/api/health" &>/dev/null; then
            echo -e "${GREEN}✅ Plausible is healthy${NC}"
        else
            echo -e "${RED}❌ Plausible is not responding${NC}"
        fi
    else
        echo -e "${YELLOW}Not installed. Run: bash scripts/run.sh setup${NC}"
    fi
}

cmd_stats() {
    load_config
    local domain="" period="7d" breakdown=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain) domain="$2"; shift 2 ;;
            --period) period="$2"; shift 2 ;;
            --breakdown) breakdown=true; shift ;;
            *) echo "Unknown: $1"; exit 1 ;;
        esac
    done
    
    if [ -z "$domain" ]; then
        echo "Usage: bash scripts/run.sh stats --domain yourdomain.com [--period 7d] [--breakdown]"
        exit 1
    fi
    
    if [ -z "${PLAUSIBLE_API_KEY:-}" ]; then
        echo -e "${YELLOW}⚠️ PLAUSIBLE_API_KEY not set. Get one from: ${PLAUSIBLE_URL:-your-dashboard}/settings/api-keys${NC}"
        exit 1
    fi
    
    local base="${PLAUSIBLE_URL}/api/v1/stats"
    
    echo -e "${CYAN}📊 ${domain} — Last ${period}${NC}\n"
    
    # Aggregate stats
    local agg
    agg=$(curl -sf "${base}/aggregate?site_id=${domain}&period=${period}&metrics=visitors,pageviews,bounce_rate,visit_duration" \
        -H "Authorization: Bearer ${PLAUSIBLE_API_KEY}")
    
    if [ $? -ne 0 ] || [ -z "$agg" ]; then
        echo -e "${RED}❌ Failed to fetch stats. Check API key and domain.${NC}"
        exit 1
    fi
    
    local visitors pageviews bounce_rate duration
    visitors=$(echo "$agg" | jq -r '.results.visitors.value')
    pageviews=$(echo "$agg" | jq -r '.results.pageviews.value')
    bounce_rate=$(echo "$agg" | jq -r '.results.bounce_rate.value')
    duration=$(echo "$agg" | jq -r '.results.visit_duration.value')
    
    local min=$((duration / 60))
    local sec=$((duration % 60))
    
    printf "  Visitors:    %s\n" "$(printf '%d' "$visitors" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')"
    printf "  Pageviews:   %s\n" "$(printf '%d' "$pageviews" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')"
    printf "  Bounce Rate: %s%%\n" "$bounce_rate"
    printf "  Avg. Time:   %dm %ds\n" "$min" "$sec"
    
    if [ "$breakdown" = true ]; then
        echo -e "\n  ${CYAN}Top Pages:${NC}"
        curl -sf "${base}/breakdown?site_id=${domain}&period=${period}&property=event:page&limit=10" \
            -H "Authorization: Bearer ${PLAUSIBLE_API_KEY}" | \
            jq -r '.results[] | "    \(.page) → \(.visitors) visitors"'
        
        echo -e "\n  ${CYAN}Top Sources:${NC}"
        curl -sf "${base}/breakdown?site_id=${domain}&period=${period}&property=visit:source&limit=10" \
            -H "Authorization: Bearer ${PLAUSIBLE_API_KEY}" | \
            jq -r '.results[] | "    \(.source) → \(.visitors) visitors"'
    fi
}

cmd_logs() {
    load_config
    local tail="${2:-50}"
    cd "$INSTALL_DIR"
    docker compose logs --tail "$tail" plausible
}

cmd_restart() {
    load_config
    cd "$INSTALL_DIR"
    echo "♻️ Restarting Plausible..."
    docker compose restart
    echo -e "${GREEN}✅ Restarted${NC}"
}

cmd_stop() {
    load_config
    cd "$INSTALL_DIR"
    docker compose down
    echo -e "${GREEN}✅ Stopped${NC}"
}

cmd_update() {
    load_config
    cd "$INSTALL_DIR"
    
    echo "📦 Checking for updates..."
    docker compose pull
    docker compose up -d
    echo -e "${GREEN}✅ Updated to latest version${NC}"
}

cmd_backup() {
    load_config
    local output="${2:-plausible-backup-$(date +%Y%m%d).tar.gz}"
    
    cd "$INSTALL_DIR"
    
    echo "💾 Backing up Plausible data..."
    
    # Dump Postgres
    docker compose exec -T plausible_db pg_dump -U postgres plausible_db > /tmp/plausible_pg.sql
    
    # Package everything
    tar -czf "$output" \
        -C /tmp plausible_pg.sql \
        -C "$INSTALL_DIR" plausible-conf.env docker-compose.yml
    
    rm -f /tmp/plausible_pg.sql
    
    local size
    size=$(du -h "$output" | cut -f1)
    echo -e "${GREEN}✅ Backup saved: ${output} (${size})${NC}"
}

cmd_nginx_config() {
    local domain=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain) domain="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [ -z "$domain" ]; then
        echo "Usage: bash scripts/run.sh nginx-config --domain analytics.yourdomain.com"
        exit 1
    fi
    
    local port
    port=$(grep -oP '"\K\d+(?=:8000")' "$INSTALL_DIR/docker-compose.yml" 2>/dev/null || echo "8000")
    
    cat <<NGINX
server {
    listen 80;
    server_name ${domain};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${domain};

    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX
}

# Command router
case "${1:-help}" in
    setup) shift; cmd_setup "$@" ;;
    status) cmd_status ;;
    stats) shift; cmd_stats "$@" ;;
    logs) cmd_logs "$@" ;;
    restart) cmd_restart ;;
    stop) cmd_stop ;;
    update) cmd_update ;;
    backup) cmd_backup "$@" ;;
    nginx-config) shift; cmd_nginx_config "$@" ;;
    help|*)
        echo "Plausible Analytics Manager"
        echo ""
        echo "Commands:"
        echo "  setup          Deploy Plausible Analytics"
        echo "  status         Check container status"
        echo "  stats          Get traffic statistics"
        echo "  logs           View Plausible logs"
        echo "  restart        Restart containers"
        echo "  stop           Stop containers"
        echo "  update         Update to latest version"
        echo "  backup         Backup data"
        echo "  nginx-config   Generate Nginx reverse proxy config"
        echo ""
        echo "Examples:"
        echo "  bash scripts/run.sh setup --domain analytics.example.com --admin-email you@example.com"
        echo "  bash scripts/run.sh stats --domain example.com --period 30d --breakdown"
        ;;
esac
