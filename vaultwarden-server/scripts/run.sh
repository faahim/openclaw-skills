#!/bin/bash
# Vaultwarden Server — Main Management Script
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# Defaults
DATA_DIR="${VW_DATA_DIR:-/opt/vaultwarden}"
DOMAIN="${VW_DOMAIN:-localhost}"
PORT="${VW_PORT:-8080}"
ADMIN_TOKEN="${VW_ADMIN_TOKEN:-}"
COMPOSE_FILE="$DATA_DIR/docker-compose.yml"

ACTION="${1:-help}"
shift || true

# Parse flags
SSL=false
EMAIL=""
NO_PROXY=false
ENCRYPT=false
PASSPHRASE=""
SCHEDULE=false
KEEP_DAYS=30
BACKUP_FILE=""
SMTP_HOST="" SMTP_USER="" SMTP_PASS="" SMTP_FROM="" SMTP_PORT="587"
ALLOWED_DOMAINS=""
SHOW_TOKEN=false
DISABLE_SIGNUPS=false
LIST_USERS=false
FAIL2BAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --ssl) SSL=true; shift ;;
        --email) EMAIL="$2"; shift 2 ;;
        --no-proxy) NO_PROXY=true; shift ;;
        --admin-token) ADMIN_TOKEN="$2"; shift 2 ;;
        --encrypt) ENCRYPT=true; shift ;;
        --passphrase) PASSPHRASE="$2"; shift 2 ;;
        --schedule) SCHEDULE=true; shift ;;
        --keep) KEEP_DAYS="$2"; shift 2 ;;
        --from) BACKUP_FILE="$2"; shift 2 ;;
        --smtp-host) SMTP_HOST="$2"; shift 2 ;;
        --smtp-user) SMTP_USER="$2"; shift 2 ;;
        --smtp-pass) SMTP_PASS="$2"; shift 2 ;;
        --smtp-from) SMTP_FROM="$2"; shift 2 ;;
        --smtp-port) SMTP_PORT="$2"; shift 2 ;;
        --allowed-domains) ALLOWED_DOMAINS="$2"; shift 2 ;;
        --show-token) SHOW_TOKEN=true; shift ;;
        --disable-signups) DISABLE_SIGNUPS=true; shift ;;
        --list-users) LIST_USERS=true; shift ;;
        --fail2ban) FAIL2BAN=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

ensure_dir() {
    sudo mkdir -p "$DATA_DIR"/{data,backups,logs}
    sudo chown -R "$(id -u):$(id -g)" "$DATA_DIR" 2>/dev/null || true
}

generate_token() {
    openssl rand -base64 48 | tr -d '\n'
}

# === DEPLOY ===
do_deploy() {
    echo -e "${CYAN}🚀 Deploying Vaultwarden...${NC}"
    ensure_dir

    if [[ -z "$ADMIN_TOKEN" ]]; then
        ADMIN_TOKEN=$(generate_token)
        echo "$ADMIN_TOKEN" > "$DATA_DIR/.admin-token"
        chmod 600 "$DATA_DIR/.admin-token"
        echo -e "${GREEN}🔑 Admin token generated and saved to $DATA_DIR/.admin-token${NC}"
    fi

    local PROTOCOL="http"
    [[ "$SSL" == true ]] && PROTOCOL="https"
    local DOMAIN_URL="${PROTOCOL}://${DOMAIN}"

    # Generate docker-compose.yml
    if [[ "$SSL" == true && "$NO_PROXY" == false ]]; then
        # Full setup with Caddy reverse proxy for SSL
        cat > "$COMPOSE_FILE" <<YAML
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      DOMAIN: "${DOMAIN_URL}"
      ADMIN_TOKEN: "${ADMIN_TOKEN}"
      SIGNUPS_ALLOWED: "${VW_SIGNUPS_ALLOWED:-true}"
      WEBSOCKET_ENABLED: "true"
      LOG_FILE: "/data/vaultwarden.log"
      LOG_LEVEL: "info"
      SMTP_HOST: "${SMTP_HOST}"
      SMTP_FROM: "${SMTP_FROM:-noreply@${DOMAIN}}"
      SMTP_PORT: "${SMTP_PORT}"
      SMTP_SECURITY: "starttls"
      SMTP_USERNAME: "${SMTP_USER}"
      SMTP_PASSWORD: "${SMTP_PASS}"
    volumes:
      - ${DATA_DIR}/data:/data
    networks:
      - vaultwarden

  caddy:
    image: caddy:2-alpine
    container_name: vaultwarden-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ${DATA_DIR}/Caddyfile:/etc/caddy/Caddyfile:ro
      - ${DATA_DIR}/caddy-data:/data
      - ${DATA_DIR}/caddy-config:/config
    networks:
      - vaultwarden

networks:
  vaultwarden:
    driver: bridge
YAML

        # Generate Caddyfile
        cat > "$DATA_DIR/Caddyfile" <<CADDY
${DOMAIN} {
    tls ${EMAIL:-internal}

    encode gzip

    # Vaultwarden HTTP
    reverse_proxy vaultwarden:80 {
        header_up X-Real-IP {remote_host}
    }
}
CADDY

    else
        # Simple setup without SSL proxy
        cat > "$COMPOSE_FILE" <<YAML
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    ports:
      - "${PORT}:80"
      - "3012:3012"
    environment:
      DOMAIN: "${DOMAIN_URL}"
      ADMIN_TOKEN: "${ADMIN_TOKEN}"
      SIGNUPS_ALLOWED: "${VW_SIGNUPS_ALLOWED:-true}"
      WEBSOCKET_ENABLED: "true"
      LOG_FILE: "/data/vaultwarden.log"
      LOG_LEVEL: "info"
    volumes:
      - ${DATA_DIR}/data:/data
YAML
    fi

    echo -e "${CYAN}📦 Pulling images...${NC}"
    cd "$DATA_DIR"
    docker compose pull

    echo -e "${CYAN}▶️  Starting containers...${NC}"
    docker compose up -d

    echo ""
    echo -e "${GREEN}✅ Vaultwarden deployed at ${DOMAIN_URL}${NC}"
    if [[ "$SSL" == false && "$NO_PROXY" == false ]]; then
        echo -e "   URL: http://localhost:${PORT}"
    fi
    echo -e "${GREEN}🔑 Admin panel: ${DOMAIN_URL}/admin${NC}"
    echo -e "${GREEN}📋 Admin token: $DATA_DIR/.admin-token${NC}"
    [[ "$SSL" == true ]] && echo -e "${GREEN}🔒 SSL: Let's Encrypt via Caddy (auto-renew)${NC}"
    echo -e "\n${YELLOW}Next: Open ${DOMAIN_URL} and create your first account.${NC}"
    echo -e "${YELLOW}Then install Bitwarden clients and set server URL to: ${DOMAIN_URL}${NC}"
}

# === BACKUP ===
do_backup() {
    echo -e "${CYAN}📦 Backing up Vaultwarden data...${NC}"
    ensure_dir

    local TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
    local BACKUP_NAME="vw-backup-${TIMESTAMP}.tar.gz"
    local BACKUP_PATH="$DATA_DIR/backups/$BACKUP_NAME"

    # Create tarball of data directory
    tar -czf "$BACKUP_PATH" -C "$DATA_DIR" data/

    if [[ "$ENCRYPT" == true ]]; then
        if [[ -z "$PASSPHRASE" ]]; then
            echo -e "${RED}❌ --passphrase required with --encrypt${NC}"
            exit 1
        fi
        openssl enc -aes-256-cbc -salt -pbkdf2 -in "$BACKUP_PATH" -out "${BACKUP_PATH}.enc" -pass "pass:${PASSPHRASE}"
        rm "$BACKUP_PATH"
        BACKUP_PATH="${BACKUP_PATH}.enc"
        BACKUP_NAME="${BACKUP_NAME}.enc"
    fi

    local SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
    echo -e "${GREEN}✅ Backup created: $BACKUP_PATH${NC}"
    echo -e "   📦 Size: $SIZE"

    # Clean old backups
    if [[ $KEEP_DAYS -gt 0 ]]; then
        find "$DATA_DIR/backups" -name "vw-backup-*" -mtime +${KEEP_DAYS} -delete 2>/dev/null || true
        echo -e "   🧹 Retention: ${KEEP_DAYS} days"
    fi

    # Schedule cron
    if [[ "$SCHEDULE" == true ]]; then
        local CRON_CMD="0 2 * * * cd $(dirname "$(readlink -f "$0")") && bash run.sh backup --encrypt --passphrase '${PASSPHRASE}' --keep ${KEEP_DAYS} >> $DATA_DIR/logs/backup.log 2>&1"
        (crontab -l 2>/dev/null | grep -v "vaultwarden.*backup"; echo "$CRON_CMD") | crontab -
        echo -e "   🗓️ Cron: daily at 2 AM"
    fi
}

# === RESTORE ===
do_restore() {
    if [[ -z "$BACKUP_FILE" ]]; then
        echo -e "${RED}❌ --from <backup-file> required${NC}"
        exit 1
    fi

    echo -e "${CYAN}🔄 Restoring from: $BACKUP_FILE${NC}"

    # Stop vaultwarden
    if [[ -f "$COMPOSE_FILE" ]]; then
        cd "$DATA_DIR" && docker compose stop vaultwarden
    fi

    local RESTORE_FILE="$BACKUP_FILE"
    if [[ "$BACKUP_FILE" == *.enc ]]; then
        if [[ -z "$PASSPHRASE" ]]; then
            echo -e "${RED}❌ --passphrase required for encrypted backup${NC}"
            exit 1
        fi
        RESTORE_FILE="/tmp/vw-restore-$$.tar.gz"
        openssl enc -aes-256-cbc -d -pbkdf2 -in "$BACKUP_FILE" -out "$RESTORE_FILE" -pass "pass:${PASSPHRASE}"
    fi

    # Backup current data just in case
    if [[ -d "$DATA_DIR/data" ]]; then
        mv "$DATA_DIR/data" "$DATA_DIR/data.pre-restore.$(date +%s)"
    fi

    tar -xzf "$RESTORE_FILE" -C "$DATA_DIR"
    [[ "$RESTORE_FILE" == /tmp/* ]] && rm -f "$RESTORE_FILE"

    # Restart
    if [[ -f "$COMPOSE_FILE" ]]; then
        cd "$DATA_DIR" && docker compose start vaultwarden
    fi

    echo -e "${GREEN}✅ Vault restored successfully.${NC}"
}

# === STATUS ===
do_status() {
    echo -e "${CYAN}📊 Vaultwarden Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━"

    # Container status
    if docker ps --format '{{.Names}} {{.Status}}' 2>/dev/null | grep -q "^vaultwarden "; then
        local STATUS=$(docker ps --format '{{.Status}}' --filter name=^vaultwarden$)
        echo -e "  ${GREEN}✅${NC} Vaultwarden: running ($STATUS)"
    else
        echo -e "  ${RED}❌${NC} Vaultwarden: not running"
    fi

    # Caddy status
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^vaultwarden-caddy$"; then
        echo -e "  ${GREEN}✅${NC} Caddy (SSL proxy): running"
    fi

    # SSL check
    if [[ "$DOMAIN" != "localhost" ]]; then
        local EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        if [[ -n "$EXPIRY" ]]; then
            local DAYS_LEFT=$(( ($(date -d "$EXPIRY" +%s) - $(date +%s)) / 86400 ))
            echo -e "  ${GREEN}🔒${NC} SSL cert: valid until $EXPIRY ($DAYS_LEFT days)"
        fi
    fi

    # Data size
    if [[ -d "$DATA_DIR/data" ]]; then
        local DATA_SIZE=$(du -sh "$DATA_DIR/data" 2>/dev/null | cut -f1)
        echo -e "  💾 Data size: $DATA_SIZE"
    fi

    # Last backup
    local LAST_BACKUP=$(ls -t "$DATA_DIR/backups"/vw-backup-* 2>/dev/null | head -1)
    if [[ -n "$LAST_BACKUP" ]]; then
        local BACKUP_DATE=$(stat -c %y "$LAST_BACKUP" 2>/dev/null | cut -d. -f1)
        echo -e "  📦 Last backup: $BACKUP_DATE"
    else
        echo -e "  ${YELLOW}⚠️${NC}  No backups found"
    fi

    # Image version
    local IMAGE_VER=$(docker inspect vaultwarden --format '{{.Config.Image}}' 2>/dev/null || echo "unknown")
    echo -e "  🐳 Image: $IMAGE_VER"
}

# === ADMIN ===
do_admin() {
    if [[ "$SHOW_TOKEN" == true ]]; then
        if [[ -f "$DATA_DIR/.admin-token" ]]; then
            echo -e "🔑 Admin token: $(cat "$DATA_DIR/.admin-token")"
        else
            echo -e "${YELLOW}No admin token file found at $DATA_DIR/.admin-token${NC}"
        fi
    fi

    if [[ "$DISABLE_SIGNUPS" == true ]]; then
        if [[ -f "$COMPOSE_FILE" ]]; then
            sed -i 's/SIGNUPS_ALLOWED: "true"/SIGNUPS_ALLOWED: "false"/' "$COMPOSE_FILE"
            cd "$DATA_DIR" && docker compose up -d
            echo -e "${GREEN}✅ Public signups disabled. Use admin panel to invite users.${NC}"
        fi
    fi

    if [[ -n "$ALLOWED_DOMAINS" ]]; then
        if [[ -f "$COMPOSE_FILE" ]]; then
            # Add SIGNUPS_DOMAINS_WHITELIST to compose
            if grep -q "SIGNUPS_DOMAINS_WHITELIST" "$COMPOSE_FILE"; then
                sed -i "s|SIGNUPS_DOMAINS_WHITELIST:.*|SIGNUPS_DOMAINS_WHITELIST: \"${ALLOWED_DOMAINS}\"|" "$COMPOSE_FILE"
            else
                sed -i "/SIGNUPS_ALLOWED/a\\      SIGNUPS_DOMAINS_WHITELIST: \"${ALLOWED_DOMAINS}\"" "$COMPOSE_FILE"
            fi
            cd "$DATA_DIR" && docker compose up -d
            echo -e "${GREEN}✅ Signups restricted to: ${ALLOWED_DOMAINS}${NC}"
        fi
    fi

    if [[ "$LIST_USERS" == true ]]; then
        if [[ -f "$DATA_DIR/data/db.sqlite3" ]]; then
            echo "📋 Registered users:"
            docker exec vaultwarden sqlite3 /data/db.sqlite3 "SELECT email, name, created_at FROM users ORDER BY created_at;" 2>/dev/null || \
                echo "  (Install sqlite3 in container or check admin panel)"
        fi
    fi
}

# === UPDATE ===
do_update() {
    echo -e "${CYAN}🔄 Updating Vaultwarden...${NC}"

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo -e "${RED}❌ No deployment found at $DATA_DIR${NC}"
        exit 1
    fi

    cd "$DATA_DIR"
    echo "📦 Pulling latest images..."
    docker compose pull

    echo "⏹️ Stopping containers..."
    docker compose down

    echo "▶️ Starting updated containers..."
    docker compose up -d

    local NEW_VER=$(docker inspect vaultwarden --format '{{.Config.Image}}' 2>/dev/null || echo "latest")
    echo -e "\n${GREEN}✅ Vaultwarden updated to ${NEW_VER}${NC}"
}

# === CONFIG (SMTP) ===
do_config() {
    if [[ -n "$SMTP_HOST" && -f "$COMPOSE_FILE" ]]; then
        sed -i "s|SMTP_HOST:.*|SMTP_HOST: \"${SMTP_HOST}\"|" "$COMPOSE_FILE"
        [[ -n "$SMTP_USER" ]] && sed -i "s|SMTP_USERNAME:.*|SMTP_USERNAME: \"${SMTP_USER}\"|" "$COMPOSE_FILE"
        [[ -n "$SMTP_PASS" ]] && sed -i "s|SMTP_PASSWORD:.*|SMTP_PASSWORD: \"${SMTP_PASS}\"|" "$COMPOSE_FILE"
        cd "$DATA_DIR" && docker compose up -d
        echo -e "${GREEN}✅ SMTP configured. Email notifications enabled.${NC}"
    fi
}

# === SECURITY ===
do_security() {
    if [[ "$FAIL2BAN" == true ]]; then
        echo -e "${CYAN}🛡️ Configuring Fail2Ban for Vaultwarden...${NC}"

        # Create filter
        sudo tee /etc/fail2ban/filter.d/vaultwarden.conf > /dev/null <<'FILTER'
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.*Username or password is incorrect\. Try again\. IP: <ADDR>\. Username:.*$
ignoreregex =
FILTER

        # Create jail
        sudo tee /etc/fail2ban/jail.d/vaultwarden.local > /dev/null <<JAIL
[vaultwarden]
enabled = true
port = 80,443,8080
filter = vaultwarden
action = iptables-allports[name=vaultwarden, chain=FORWARD]
logpath = ${DATA_DIR}/data/vaultwarden.log
maxretry = 5
bantime = 900
findtime = 900
JAIL

        sudo systemctl restart fail2ban 2>/dev/null || echo "Install fail2ban: sudo apt install fail2ban"
        echo -e "${GREEN}✅ Fail2Ban jail configured (5 attempts → 15 min ban)${NC}"
    fi
}

# === HELP ===
do_help() {
    cat <<EOF
Vaultwarden Server Manager

Usage: bash scripts/run.sh <command> [options]

Commands:
  deploy     Deploy Vaultwarden with Docker
  backup     Backup vault data (optional encryption)
  restore    Restore from backup
  status     Show vault status and health
  update     Update to latest Vaultwarden image
  admin      Admin panel management
  config     Configure SMTP and settings
  security   Security hardening (fail2ban)
  help       Show this help

Deploy Options:
  --domain <domain>      Domain name (required)
  --ssl                  Enable SSL via Caddy + Let's Encrypt
  --email <email>        Email for Let's Encrypt certificate
  --port <port>          HTTP port (default: 8080)
  --no-proxy             Skip Caddy proxy (use your own)
  --admin-token <token>  Admin panel token (auto-generated if empty)

Backup Options:
  --encrypt              Encrypt backup with AES-256
  --passphrase <pass>    Encryption passphrase
  --schedule             Add nightly cron job
  --keep <days>          Retention period (default: 30)

Restore Options:
  --from <file>          Backup file to restore
  --passphrase <pass>    Decryption passphrase

Admin Options:
  --show-token           Display admin token
  --disable-signups      Disable public registration
  --allowed-domains <d>  Restrict signups to domains
  --list-users           List registered users

Config Options:
  --smtp-host <host>     SMTP server
  --smtp-user <user>     SMTP username
  --smtp-pass <pass>     SMTP password

Security Options:
  --fail2ban             Configure fail2ban protection
EOF
}

# Dispatch
case "$ACTION" in
    deploy)   do_deploy ;;
    backup)   do_backup ;;
    restore)  do_restore ;;
    status)   do_status ;;
    update)   do_update ;;
    admin)    do_admin ;;
    config)   do_config ;;
    security) do_security ;;
    help|*)   do_help ;;
esac
