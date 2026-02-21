#!/bin/bash
# Nginx Reverse Proxy Manager
# Usage: bash proxy.sh <command> [options]
set -euo pipefail

NGINX_CONF_DIR="${NGINX_CONF_DIR:-/etc/nginx}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
DRY_RUN="${DRY_RUN:-false}"
SITES_AVAILABLE="$NGINX_CONF_DIR/sites-available"
SITES_ENABLED="$NGINX_CONF_DIR/sites-enabled"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

usage() {
    cat <<EOF
Nginx Reverse Proxy Manager

COMMANDS:
  add       Add a new reverse proxy
  remove    Remove a proxy config
  status    List all configured proxies
  health    Check health of a proxy
  renew     Renew all SSL certificates
  setup-renewal  Set up automatic SSL renewal cron
  template  Output a config template to stdout
  backup    Backup all nginx configs
  restore   Restore from a backup

ADD OPTIONS:
  --domain <domain>         Domain name (required)
  --upstream <host:port>    Upstream server(s), comma-separated (required)
  --ssl                     Enable SSL via Let's Encrypt
  --email <email>           Email for Let's Encrypt (or set CERTBOT_EMAIL)
  --websocket               Enable WebSocket proxying
  --rate-limit <rate>       Rate limiting (e.g., 10r/s)
  --lb-method <method>      Load balance: round_robin, least_conn, ip_hash
  --add-header <header>     Add custom header (repeatable)

EXAMPLES:
  bash proxy.sh add --domain api.example.com --upstream 127.0.0.1:3000 --ssl
  bash proxy.sh add --domain app.example.com --upstream 127.0.0.1:8001,127.0.0.1:8002 --ssl --lb-method least_conn
  bash proxy.sh status
  bash proxy.sh health --domain api.example.com
  bash proxy.sh remove --domain api.example.com
EOF
    exit 0
}

# Parse a proxy config command
parse_add_args() {
    DOMAIN="" UPSTREAM="" SSL=false EMAIL="$CERTBOT_EMAIL" WEBSOCKET=false
    RATE_LIMIT="" LB_METHOD="round_robin" HEADERS=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain) DOMAIN="$2"; shift 2 ;;
            --upstream) UPSTREAM="$2"; shift 2 ;;
            --ssl) SSL=true; shift ;;
            --email) EMAIL="$2"; shift 2 ;;
            --websocket) WEBSOCKET=true; shift ;;
            --rate-limit) RATE_LIMIT="$2"; shift 2 ;;
            --lb-method) LB_METHOD="$2"; shift 2 ;;
            --add-header) HEADERS+=("$2"); shift 2 ;;
            *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
        esac
    done

    [[ -z "$DOMAIN" ]] && echo -e "${RED}Error: --domain is required${NC}" && exit 1
    [[ -z "$UPSTREAM" ]] && echo -e "${RED}Error: --upstream is required${NC}" && exit 1
}

generate_config() {
    local conf=""
    IFS=',' read -ra UPSTREAMS <<< "$UPSTREAM"
    local upstream_name=$(echo "$DOMAIN" | tr '.' '_')

    # Upstream block (if multiple backends)
    if [[ ${#UPSTREAMS[@]} -gt 1 ]]; then
        conf+="upstream ${upstream_name}_backend {\n"
        [[ "$LB_METHOD" == "least_conn" ]] && conf+="    least_conn;\n"
        [[ "$LB_METHOD" == "ip_hash" ]] && conf+="    ip_hash;\n"
        for u in "${UPSTREAMS[@]}"; do
            u=$(echo "$u" | xargs)  # trim whitespace
            conf+="    server ${u};\n"
        done
        conf+="}\n\n"
    fi

    local backend
    if [[ ${#UPSTREAMS[@]} -gt 1 ]]; then
        backend="http://${upstream_name}_backend"
    else
        backend="http://${UPSTREAMS[0]}"
    fi

    # Rate limiting zone
    if [[ -n "$RATE_LIMIT" ]]; then
        conf+="limit_req_zone \$binary_remote_addr zone=${upstream_name}_limit:10m rate=${RATE_LIMIT};\n\n"
    fi

    # HTTP → HTTPS redirect (if SSL)
    if $SSL; then
        conf+="server {\n"
        conf+="    listen 80;\n"
        conf+="    listen [::]:80;\n"
        conf+="    server_name ${DOMAIN};\n"
        conf+="    return 301 https://\$host\$request_uri;\n"
        conf+="}\n\n"
    fi

    # Main server block
    if $SSL; then
        conf+="server {\n"
        conf+="    listen 443 ssl http2;\n"
        conf+="    listen [::]:443 ssl http2;\n"
        conf+="    server_name ${DOMAIN};\n\n"
        conf+="    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;\n"
        conf+="    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;\n"
        conf+="    include ${NGINX_CONF_DIR}/snippets/ssl-params.conf;\n\n"
    else
        conf+="server {\n"
        conf+="    listen 80;\n"
        conf+="    listen [::]:80;\n"
        conf+="    server_name ${DOMAIN};\n\n"
    fi

    # Rate limiting
    if [[ -n "$RATE_LIMIT" ]]; then
        conf+="    limit_req zone=${upstream_name}_limit burst=20 nodelay;\n\n"
    fi

    # Custom headers
    for h in "${HEADERS[@]+"${HEADERS[@]}"}"; do
        local hname="${h%%:*}"
        local hval="${h#*: }"
        conf+="    add_header ${hname} \"${hval}\" always;\n"
    done
    [[ ${#HEADERS[@]} -gt 0 ]] && conf+="\n"

    # Location block
    conf+="    location / {\n"
    conf+="        proxy_pass ${backend};\n"
    conf+="        include ${NGINX_CONF_DIR}/snippets/proxy-params.conf;\n"

    if $WEBSOCKET; then
        conf+="\n"
        conf+="        # WebSocket support\n"
        conf+="        proxy_set_header Upgrade \$http_upgrade;\n"
        conf+="        proxy_set_header Connection \"upgrade\";\n"
        conf+="        proxy_read_timeout 86400;\n"
    fi

    conf+="    }\n\n"

    # Access log
    conf+="    access_log /var/log/nginx/${DOMAIN}.access.log;\n"
    conf+="    error_log /var/log/nginx/${DOMAIN}.error.log;\n"
    conf+="}\n"

    echo -e "$conf"
}

cmd_add() {
    parse_add_args "$@"

    echo -e "${GREEN}🔧 Adding reverse proxy: ${DOMAIN} → ${UPSTREAM}${NC}"

    local config
    config=$(generate_config)

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN] Would write to ${SITES_AVAILABLE}/${DOMAIN}.conf:${NC}"
        echo -e "$config"
        return
    fi

    # Write config
    echo -e "$config" | sudo tee "$SITES_AVAILABLE/${DOMAIN}.conf" > /dev/null

    # Enable site
    sudo ln -sf "$SITES_AVAILABLE/${DOMAIN}.conf" "$SITES_ENABLED/${DOMAIN}.conf"

    # Test config
    if ! sudo nginx -t 2>/dev/null; then
        echo -e "${RED}❌ Nginx config test failed! Rolling back...${NC}"
        sudo rm -f "$SITES_ENABLED/${DOMAIN}.conf" "$SITES_AVAILABLE/${DOMAIN}.conf"
        sudo nginx -t
        exit 1
    fi

    # Get SSL certificate
    if $SSL; then
        echo -e "${GREEN}🔐 Obtaining SSL certificate...${NC}"
        # Temporarily serve HTTP for certbot challenge
        sudo systemctl reload nginx

        local certbot_args="certonly --nginx -d ${DOMAIN} --non-interactive --agree-tos"
        [[ -n "$EMAIL" ]] && certbot_args+=" --email ${EMAIL}" || certbot_args+=" --register-unsafely-without-email"

        if sudo certbot $certbot_args; then
            echo -e "${GREEN}✅ SSL certificate obtained!${NC}"
        else
            echo -e "${RED}❌ SSL certificate failed. Proxy configured without SSL.${NC}"
            # Rewrite config without SSL
            SSL=false
            config=$(generate_config)
            echo -e "$config" | sudo tee "$SITES_AVAILABLE/${DOMAIN}.conf" > /dev/null
        fi
    fi

    # Reload nginx
    sudo systemctl reload nginx

    echo -e "${GREEN}✅ Proxy configured: ${DOMAIN}${NC}"
    $SSL && echo -e "   HTTPS: https://${DOMAIN}" || echo -e "   HTTP: http://${DOMAIN}"
    echo -e "   Upstream: ${UPSTREAM}"
    echo -e "   Config: ${SITES_AVAILABLE}/${DOMAIN}.conf"
}

cmd_remove() {
    local domain=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain) domain="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [[ -z "$domain" ]] && echo -e "${RED}Error: --domain required${NC}" && exit 1

    echo -e "${YELLOW}🗑  Removing proxy: ${domain}${NC}"

    sudo rm -f "$SITES_ENABLED/${domain}.conf"
    sudo rm -f "$SITES_AVAILABLE/${domain}.conf"

    if sudo nginx -t 2>/dev/null; then
        sudo systemctl reload nginx
        echo -e "${GREEN}✅ Proxy removed: ${domain}${NC}"
    else
        echo -e "${RED}❌ Nginx config error after removal. Check manually.${NC}"
    fi
}

cmd_status() {
    echo -e "${GREEN}Nginx Reverse Proxy Status${NC}"
    echo "================================================"
    printf "%-30s %-25s %-6s %-8s\n" "DOMAIN" "UPSTREAM" "SSL" "STATUS"
    echo "------------------------------------------------"

    for conf in "$SITES_ENABLED"/*.conf; do
        [[ ! -f "$conf" ]] && continue
        local domain=$(basename "$conf" .conf)
        local upstream=$(grep -oP 'proxy_pass\s+\K[^;]+' "$conf" 2>/dev/null | head -1)
        local has_ssl="❌"
        grep -q "ssl_certificate" "$conf" && has_ssl="✅"
        local status="active"
        printf "%-30s %-25s %-6s %-8s\n" "$domain" "${upstream:-N/A}" "$has_ssl" "$status"
    done

    echo ""
    echo "Nginx: $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
}

cmd_health() {
    local domain=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain) domain="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [[ -z "$domain" ]] && echo -e "${RED}Error: --domain required${NC}" && exit 1

    echo -e "${GREEN}Health Check: ${domain}${NC}"
    echo "================================"

    # Nginx status
    if systemctl is-active nginx &>/dev/null; then
        echo -e "  Nginx: ${GREEN}✅ running${NC}"
    else
        echo -e "  Nginx: ${RED}❌ not running${NC}"
    fi

    # SSL check
    local conf="$SITES_AVAILABLE/${domain}.conf"
    if [[ -f "$conf" ]] && grep -q "ssl_certificate" "$conf"; then
        local expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        if [[ -n "$expiry" ]]; then
            local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
            local now_epoch=$(date +%s)
            local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
            if [[ $days_left -gt 30 ]]; then
                echo -e "  SSL: ${GREEN}✅ valid (expires ${expiry}, ${days_left} days)${NC}"
            elif [[ $days_left -gt 0 ]]; then
                echo -e "  SSL: ${YELLOW}⚠️  expiring soon (${days_left} days)${NC}"
            else
                echo -e "  SSL: ${RED}❌ expired${NC}"
            fi
        else
            echo -e "  SSL: ${YELLOW}⚠️  could not check (DNS or connectivity issue)${NC}"
        fi
    else
        echo -e "  SSL: ➖ not configured"
    fi

    # Upstream check
    local upstream=$(grep -oP 'proxy_pass\s+http://\K[^;/]+' "$conf" 2>/dev/null | head -1)
    if [[ -n "$upstream" ]]; then
        local start_ms=$(($(date +%s%N)/1000000))
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://${upstream}" 2>/dev/null || echo "000")
        local end_ms=$(($(date +%s%N)/1000000))
        local elapsed=$((end_ms - start_ms))

        if [[ "$http_code" =~ ^[23] ]]; then
            echo -e "  Upstream ${upstream}: ${GREEN}✅ responding (HTTP ${http_code}, ${elapsed}ms)${NC}"
        else
            echo -e "  Upstream ${upstream}: ${RED}❌ error (HTTP ${http_code}, ${elapsed}ms)${NC}"
        fi
    fi
}

cmd_renew() {
    echo -e "${GREEN}🔐 Renewing all SSL certificates...${NC}"
    sudo certbot renew --quiet --post-hook "systemctl reload nginx"
    echo -e "${GREEN}✅ Renewal complete.${NC}"
}

cmd_setup_renewal() {
    echo -e "${GREEN}⏰ Setting up automatic SSL renewal...${NC}"
    (crontab -l 2>/dev/null | grep -v certbot; echo '0 3 * * * certbot renew --quiet --post-hook "systemctl reload nginx"') | sudo crontab -
    echo -e "${GREEN}✅ Auto-renewal cron added (daily at 3am).${NC}"
}

cmd_template() {
    parse_add_args "$@"
    generate_config
}

cmd_backup() {
    local backup_file="$NGINX_CONF_DIR/backups/nginx-backup-$(date +%Y-%m-%d).tar.gz"
    sudo mkdir -p "$NGINX_CONF_DIR/backups"
    sudo tar -czf "$backup_file" -C /etc nginx/sites-available nginx/sites-enabled nginx/snippets 2>/dev/null
    echo -e "${GREEN}✅ Backup created: ${backup_file}${NC}"
}

cmd_restore() {
    local file=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --file) file="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [[ -z "$file" ]] && echo -e "${RED}Error: --file required${NC}" && exit 1
    [[ ! -f "$file" ]] && echo -e "${RED}Error: File not found: ${file}${NC}" && exit 1

    echo -e "${YELLOW}⚠️  Restoring from ${file}...${NC}"
    sudo tar -xzf "$file" -C /etc
    sudo nginx -t && sudo systemctl reload nginx
    echo -e "${GREEN}✅ Restored and reloaded.${NC}"
}

# Main dispatcher
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    add) cmd_add "$@" ;;
    remove) cmd_remove "$@" ;;
    status) cmd_status ;;
    health) cmd_health "$@" ;;
    renew) cmd_renew ;;
    setup-renewal) cmd_setup_renewal ;;
    template) cmd_template "$@" ;;
    backup) cmd_backup ;;
    restore) cmd_restore "$@" ;;
    help|--help|-h) usage ;;
    *) echo -e "${RED}Unknown command: ${COMMAND}${NC}"; usage ;;
esac
