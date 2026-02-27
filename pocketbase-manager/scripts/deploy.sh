#!/bin/bash
# PocketBase Full Deployment — install + init + systemd + optional Caddy
set -euo pipefail

NAME=""
PORT="8090"
DOMAIN=""
WITH_CADDY=false
BACKUP_DEST=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --name NAME         Instance name (required)
  --port PORT         Port (default: 8090)
  --domain DOMAIN     Domain for reverse proxy (enables Caddy)
  --with-caddy        Set up Caddy reverse proxy
  --backup-dest PATH  Enable daily backups to this path
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; WITH_CADDY=true; shift 2 ;;
    --with-caddy) WITH_CADDY=true; shift ;;
    --backup-dest) BACKUP_DEST="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -z "$NAME" ]] && { echo "❌ --name is required"; usage; }

echo "🚀 Full PocketBase Deployment: $NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Install PocketBase
echo "Step 1/5: Installing PocketBase..."
bash "$SCRIPT_DIR/install.sh"
echo ""

# Step 2: Initialize instance
echo "Step 2/5: Initializing instance..."
bash "$SCRIPT_DIR/manage.sh" init --name "$NAME" --port "$PORT"
echo ""

# Step 3: Set up systemd service
echo "Step 3/5: Setting up systemd service..."
bash "$SCRIPT_DIR/manage.sh" service --name "$NAME" --port "$PORT" --enable
echo ""

# Step 4: Caddy reverse proxy (optional)
if [[ "$WITH_CADDY" == "true" && -n "$DOMAIN" ]]; then
  echo "Step 4/5: Configuring Caddy reverse proxy..."

  if ! command -v caddy &>/dev/null; then
    echo "  Installing Caddy..."
    sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl 2>/dev/null || true
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null || true
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null 2>/dev/null || true
    sudo apt-get update -qq && sudo apt-get install -y caddy 2>/dev/null || {
      echo "  ⚠️  Auto-install failed. Install Caddy manually: https://caddyserver.com/docs/install"
    }
  fi

  if command -v caddy &>/dev/null; then
    # Append to Caddyfile
    local caddyfile="/etc/caddy/Caddyfile"
    if ! grep -q "$DOMAIN" "$caddyfile" 2>/dev/null; then
      cat >> "$caddyfile" <<CADDY

${DOMAIN} {
    reverse_proxy localhost:${PORT}
}
CADDY
      sudo systemctl reload caddy
      echo "  ✅ Caddy configured: ${DOMAIN} → localhost:${PORT}"
    else
      echo "  ⚠️  Domain already in Caddyfile"
    fi
  fi
else
  echo "Step 4/5: Skipping reverse proxy (no --domain specified)"
fi
echo ""

# Step 5: Backups (optional)
if [[ -n "$BACKUP_DEST" ]]; then
  echo "Step 5/5: Setting up daily backups..."
  bash "$SCRIPT_DIR/backup.sh" --name "$NAME" --dest "$BACKUP_DEST" --schedule daily
else
  echo "Step 5/5: Skipping backups (no --backup-dest specified)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Deployment complete!"
echo ""
echo "   Instance:  $NAME"
echo "   URL:       http://localhost:${PORT}"
[[ -n "$DOMAIN" ]] && echo "   Domain:    https://${DOMAIN}"
echo "   Admin:     http://localhost:${PORT}/_/"
echo "   Logs:      sudo journalctl -u pocketbase-${NAME} -f"
echo ""
echo "Create your admin account at: http://localhost:${PORT}/_/"
