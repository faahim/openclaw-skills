#!/bin/bash
# Gotify Server Installer
# Supports Docker and binary installation methods

set -euo pipefail

METHOD="docker"
PORT=8080
DOMAIN=""
NGINX=false
DATA_DIR="${GOTIFY_DATA_DIR:-/var/lib/gotify}"
ADMIN_USER="${GOTIFY_ADMIN_USER:-admin}"
ADMIN_PASS="${GOTIFY_ADMIN_PASS:-$(openssl rand -base64 16)}"

usage() {
  cat <<EOF
Usage: bash install.sh [OPTIONS]

Options:
  --method docker|binary   Installation method (default: docker)
  --port PORT              Server port (default: 8080)
  --domain DOMAIN          Domain for reverse proxy (optional)
  --nginx                  Configure Nginx reverse proxy
  --data-dir DIR           Data directory (default: /var/lib/gotify)
  --admin-user USER        Admin username (default: admin)
  --admin-pass PASS        Admin password (auto-generated if not set)
  -h, --help               Show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --method) METHOD="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --nginx) NGINX=true; shift ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    --admin-user) ADMIN_USER="$2"; shift 2 ;;
    --admin-pass) ADMIN_PASS="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🔧 Installing Gotify Server..."
echo "   Method: $METHOD"
echo "   Port: $PORT"
echo "   Admin: $ADMIN_USER"

install_docker() {
  if ! command -v docker &>/dev/null; then
    echo "❌ Docker not found. Install Docker first:"
    echo "   curl -fsSL https://get.docker.com | sh"
    exit 1
  fi

  echo "📦 Pulling Gotify Docker image..."
  docker pull gotify/server:latest

  echo "🚀 Starting Gotify container..."
  docker run -d \
    --name gotify \
    --restart unless-stopped \
    -p "${PORT}:80" \
    -e "GOTIFY_DEFAULTUSER_NAME=${ADMIN_USER}" \
    -e "GOTIFY_DEFAULTUSER_PASS=${ADMIN_PASS}" \
    -v gotify-data:/app/data \
    gotify/server:latest

  echo "✅ Gotify running via Docker on port ${PORT}"
}

install_binary() {
  ARCH=$(uname -m)
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')

  case "$ARCH" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l|armhf) ARCH="arm-7" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
  esac

  echo "📦 Downloading Gotify server binary (${OS}-${ARCH})..."

  LATEST=$(curl -s https://api.github.com/repos/gotify/server/releases/latest | jq -r '.tag_name' | sed 's/^v//')
  URL="https://github.com/gotify/server/releases/download/v${LATEST}/gotify-${OS}-${ARCH}.zip"

  INSTALL_DIR="/opt/gotify"
  sudo mkdir -p "$INSTALL_DIR" "$DATA_DIR"

  curl -sL "$URL" -o /tmp/gotify.zip
  unzip -o /tmp/gotify.zip -d "$INSTALL_DIR"
  chmod +x "$INSTALL_DIR/gotify-${OS}-${ARCH}"
  ln -sf "$INSTALL_DIR/gotify-${OS}-${ARCH}" "$INSTALL_DIR/gotify"
  rm /tmp/gotify.zip

  # Create config
  cat > "$INSTALL_DIR/config.yml" <<CONF
server:
  port: ${PORT}
  ssl:
    enabled: false
database:
  dialect: sqlite3
  connection: ${DATA_DIR}/gotify.db
defaultuser:
  name: ${ADMIN_USER}
  pass: ${ADMIN_PASS}
CONF

  # Create systemd service
  sudo tee /etc/systemd/system/gotify.service > /dev/null <<SERVICE
[Unit]
Description=Gotify Push Notification Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/gotify
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

  sudo systemctl daemon-reload
  sudo systemctl enable gotify
  sudo systemctl start gotify

  echo "✅ Gotify installed as systemd service on port ${PORT}"
}

setup_nginx() {
  if [ -z "$DOMAIN" ]; then
    echo "⚠️  No --domain specified, skipping Nginx setup"
    return
  fi

  if ! command -v nginx &>/dev/null; then
    echo "📦 Installing Nginx..."
    sudo apt-get update -qq && sudo apt-get install -y -qq nginx
  fi

  sudo tee "/etc/nginx/sites-available/gotify" > /dev/null <<NGINX
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

  sudo ln -sf /etc/nginx/sites-available/gotify /etc/nginx/sites-enabled/
  sudo nginx -t && sudo systemctl reload nginx

  echo "✅ Nginx reverse proxy configured for ${DOMAIN}"
  echo "💡 Run 'certbot --nginx -d ${DOMAIN}' for SSL"
}

# Run installation
case "$METHOD" in
  docker) install_docker ;;
  binary) install_binary ;;
  *) echo "❌ Unknown method: $METHOD (use 'docker' or 'binary')"; exit 1 ;;
esac

if [ "$NGINX" = true ]; then
  setup_nginx
fi

echo ""
echo "========================================="
echo "  Gotify Server Installed Successfully"
echo "========================================="
echo ""
echo "  URL:      http://localhost:${PORT}"
[ -n "$DOMAIN" ] && echo "  Domain:   http://${DOMAIN}"
echo "  Admin:    ${ADMIN_USER}"
echo "  Password: ${ADMIN_PASS}"
echo ""
echo "  Next steps:"
echo "  1. Open http://localhost:${PORT} in your browser"
echo "  2. Log in with admin credentials above"
echo "  3. Create an app: bash scripts/manage.sh create-app --name 'My Agent'"
echo "  4. Send a test: bash scripts/send.sh --token <TOKEN> --title 'Test' --message 'Hello!'"
echo ""
echo "  Save these credentials! The password won't be shown again."
