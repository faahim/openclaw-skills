#!/bin/bash
# Set up Cloudflare tunnel for n8n webhooks
set -euo pipefail

N8N_DIR="${N8N_DIR:-$HOME/.n8n}"
N8N_PORT="${N8N_PORT:-5678}"
ACTION=""
DOMAIN=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --install) ACTION="install"; shift ;;
    --domain) ACTION="tunnel"; DOMAIN="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [ "$ACTION" = "install" ]; then
  echo "📦 Installing cloudflared..."
  if command -v cloudflared &>/dev/null; then
    echo "✅ Already installed: $(cloudflared --version)"
    exit 0
  fi

  # Detect architecture
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
  esac

  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${OS}-${ARCH}"

  curl -sL "$URL" -o /usr/local/bin/cloudflared 2>/dev/null || \
    sudo curl -sL "$URL" -o /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared 2>/dev/null || \
    sudo chmod +x /usr/local/bin/cloudflared

  echo "✅ Installed: $(cloudflared --version)"

elif [ "$ACTION" = "tunnel" ]; then
  if ! command -v cloudflared &>/dev/null; then
    echo "❌ cloudflared not installed. Run: bash scripts/tunnel.sh --install"
    exit 1
  fi

  echo "🔗 Starting tunnel to http://localhost:$N8N_PORT..."
  echo "   Domain: $DOMAIN"

  # Update n8n webhook URL
  if [ -f "$N8N_DIR/.env" ]; then
    sed -i '/WEBHOOK_URL/d' "$N8N_DIR/.env"
    echo "WEBHOOK_URL=https://$DOMAIN" >> "$N8N_DIR/.env"
    echo "   Updated WEBHOOK_URL in .env"
  fi

  cloudflared tunnel --url "http://localhost:$N8N_PORT" --hostname "$DOMAIN"
else
  echo "Usage:"
  echo "  tunnel.sh --install              Install cloudflared"
  echo "  tunnel.sh --domain n8n.site.com  Start tunnel"
fi
