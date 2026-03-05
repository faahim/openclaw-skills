#!/bin/bash
set -euo pipefail

DOMAIN="" PROXY="caddy"
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN="$2"; shift 2 ;;
        --proxy) PROXY="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[ -z "$DOMAIN" ] && { echo "Usage: setup-proxy.sh --domain <domain> [--proxy caddy|nginx]"; exit 1; }

INSTALL_DIR="${LISTMONK_DIR:-$HOME/listmonk}"
source "$INSTALL_DIR/.env" 2>/dev/null || true
PORT="${LISTMONK_PORT:-9000}"

case "$PROXY" in
    caddy)
        if ! command -v caddy &>/dev/null; then
            echo "📦 Installing Caddy..."
            sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
            sudo apt-get update && sudo apt-get install -y caddy
        fi

        CADDYFILE="/etc/caddy/Caddyfile"
        sudo tee -a "$CADDYFILE" > /dev/null <<EOF

${DOMAIN} {
    reverse_proxy localhost:${PORT}
}
EOF
        sudo systemctl reload caddy
        echo "✅ Caddy reverse proxy configured for ${DOMAIN}"
        echo "   SSL will be auto-provisioned by Caddy"
        ;;

    nginx)
        if ! command -v nginx &>/dev/null; then
            echo "📦 Installing Nginx..."
            sudo apt-get update && sudo apt-get install -y nginx
        fi

        sudo tee "/etc/nginx/sites-available/listmonk" > /dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://localhost:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
}
EOF
        sudo ln -sf /etc/nginx/sites-available/listmonk /etc/nginx/sites-enabled/
        sudo nginx -t && sudo systemctl reload nginx
        echo "✅ Nginx reverse proxy configured for ${DOMAIN}"
        echo "   Run 'sudo certbot --nginx -d ${DOMAIN}' for SSL"
        ;;

    *)
        echo "❌ Unknown proxy: $PROXY (use caddy or nginx)"
        exit 1
        ;;
esac
