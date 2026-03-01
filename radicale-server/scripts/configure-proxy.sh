#!/bin/bash
# Configure Radicale for reverse proxy / HTTPS
set -e

RADICALE_CONFIG_DIR="${RADICALE_CONFIG_DIR:-$HOME/.config/radicale}"
CONFIG_FILE="$RADICALE_CONFIG_DIR/config"
DOMAIN=""
SELF_SIGNED=false
CERT_PATH=""
KEY_PATH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift 2 ;;
    --self-signed) SELF_SIGNED=true; shift ;;
    --cert) CERT_PATH="$2"; shift 2 ;;
    --key) KEY_PATH="$2"; shift 2 ;;
    --help)
      echo "Usage: bash configure-proxy.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --domain DOMAIN    Configure for reverse proxy with this domain"
      echo "  --self-signed      Generate self-signed SSL certificate"
      echo "  --cert PATH        Path to SSL certificate"
      echo "  --key PATH         Path to SSL private key"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config not found. Run install.sh first."
  exit 1
fi

# Self-signed certificate
if $SELF_SIGNED; then
  CERT_DIR="$RADICALE_CONFIG_DIR/ssl"
  mkdir -p "$CERT_DIR"
  CERT_PATH="$CERT_DIR/cert.pem"
  KEY_PATH="$CERT_DIR/key.pem"

  openssl req -x509 -newkey rsa:4096 -keyout "$KEY_PATH" -out "$CERT_PATH" \
    -sha256 -days 365 -nodes \
    -subj "/CN=${DOMAIN:-localhost}" 2>/dev/null

  echo "✅ Self-signed certificate generated"
  echo "   Cert: $CERT_PATH"
  echo "   Key:  $KEY_PATH"
fi

# Add SSL to config if cert paths provided
if [ -n "$CERT_PATH" ] && [ -n "$KEY_PATH" ]; then
  if grep -q "^\[server\]" "$CONFIG_FILE"; then
    # Remove old SSL lines
    sed -i '/^ssl = /d; /^certificate = /d; /^key = /d' "$CONFIG_FILE"
    # Add after [server] section
    sed -i "/^\[server\]/a ssl = True\ncertificate = ${CERT_PATH}\nkey = ${KEY_PATH}" "$CONFIG_FILE"
  fi
  echo "✅ SSL configured in Radicale config"
  echo "   Restart with: bash scripts/install.sh --restart"
fi

# Reverse proxy config examples
if [ -n "$DOMAIN" ]; then
  echo ""
  echo "═══════════════════════════════════════"
  echo "  Reverse Proxy Configuration"
  echo "═══════════════════════════════════════"
  echo ""
  echo "── Caddy (recommended) ──"
  echo ""
  echo "${DOMAIN} {"
  echo "  reverse_proxy localhost:5232"
  echo "}"
  echo ""
  echo "── Nginx ──"
  echo ""
  echo "server {"
  echo "    listen 443 ssl;"
  echo "    server_name ${DOMAIN};"
  echo ""
  echo "    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;"
  echo "    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;"
  echo ""
  echo "    location / {"
  echo "        proxy_pass http://localhost:5232;"
  echo "        proxy_set_header Host \$host;"
  echo "        proxy_set_header X-Real-IP \$remote_addr;"
  echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
  echo "        proxy_set_header X-Forwarded-Proto \$scheme;"
  echo "    }"
  echo "}"
fi
