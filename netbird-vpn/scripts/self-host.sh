#!/bin/bash
# NetBird Self-Hosted Setup
# Deploys NetBird management server, signal server, and dashboard

set -euo pipefail

DOMAIN=""
EMAIL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: self-host.sh --domain vpn.example.com --email admin@example.com"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
  echo "❌ Both --domain and --email are required"
  echo "Usage: self-host.sh --domain vpn.example.com --email admin@example.com"
  exit 1
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

INSTALL_DIR="/opt/netbird"

# Check prerequisites
check_prereqs() {
  log "🔍 Checking prerequisites..."

  for cmd in docker curl; do
    if ! command -v "$cmd" &>/dev/null; then
      log "❌ $cmd is required but not installed"
      exit 1
    fi
  done

  if ! docker compose version &>/dev/null && ! docker-compose version &>/dev/null; then
    log "❌ docker compose is required"
    exit 1
  fi

  log "✅ Prerequisites OK"
}

# Download and configure
setup_self_hosted() {
  log "📦 Setting up NetBird self-hosted at $INSTALL_DIR..."
  sudo mkdir -p "$INSTALL_DIR"
  cd "$INSTALL_DIR"

  # Download the official quickstart script
  log "⬇️  Downloading NetBird quickstart..."
  sudo curl -fsSL https://github.com/netbirdio/netbird/releases/latest/download/getting-started-with-zitadel.sh \
    -o quickstart.sh
  sudo chmod +x quickstart.sh

  log "🚀 Running NetBird quickstart..."
  log "   Domain: $DOMAIN"
  log "   Email:  $EMAIL"

  # Run the quickstart
  sudo NETBIRD_DOMAIN="$DOMAIN" \
       NETBIRD_LETSENCRYPT_EMAIL="$EMAIL" \
       bash quickstart.sh

  log ""
  log "✅ NetBird self-hosted deployment complete!"
  log ""
  log "📋 Next steps:"
  log "   1. Dashboard: https://$DOMAIN"
  log "   2. Create an admin account"
  log "   3. Generate setup keys for your peers"
  log "   4. Connect peers: netbird up --management-url https://$DOMAIN"
  log ""
  log "📁 Installation directory: $INSTALL_DIR"
  log "📝 Config: $INSTALL_DIR/docker-compose.yml"
  log ""
  log "🔧 Management commands:"
  log "   cd $INSTALL_DIR && docker compose ps     # Check status"
  log "   cd $INSTALL_DIR && docker compose logs    # View logs"
  log "   cd $INSTALL_DIR && docker compose restart # Restart"
}

check_prereqs
setup_self_hosted
