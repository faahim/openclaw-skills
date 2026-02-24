#!/bin/bash
# Immich Server — Automated Installation Script
set -euo pipefail

# Defaults
INSTALL_DIR="/opt/immich"
VERSION="release"
PORT="2283"
DATA_DIR=""
SKIP_ML=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --no-ml) SKIP_ML=true; shift ;;
    -h|--help)
      echo "Usage: install.sh [OPTIONS]"
      echo "  --version VERSION    Immich version tag (default: release)"
      echo "  --port PORT          Server port (default: 2283)"
      echo "  --data-dir DIR       Photo upload directory"
      echo "  --install-dir DIR    Installation directory (default: /opt/immich)"
      echo "  --no-ml              Disable machine learning container"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check prerequisites
log "🔍 Checking prerequisites..."

if ! command -v docker &>/dev/null; then
  log "${RED}❌ Docker not found. Install it first:${NC}"
  echo "  curl -fsSL https://get.docker.com | sh"
  exit 1
fi

if ! docker compose version &>/dev/null; then
  log "${RED}❌ Docker Compose v2 not found.${NC}"
  exit 1
fi

if ! docker info &>/dev/null 2>&1; then
  log "${RED}❌ Cannot connect to Docker daemon. Is it running?${NC}"
  echo "  sudo systemctl start docker"
  exit 1
fi

# Create directories
log "📁 Creating installation directory: $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"
sudo chown "$(whoami):$(whoami)" "$INSTALL_DIR"
cd "$INSTALL_DIR"

UPLOAD_DIR="${DATA_DIR:-$INSTALL_DIR/upload}"
mkdir -p "$UPLOAD_DIR" backups scripts

# Download docker-compose.yml
log "📦 Downloading Immich docker-compose.yml..."
curl -sL "https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml" -o docker-compose.yml

# Download .env template
log "📦 Downloading environment template..."
curl -sL "https://github.com/immich-app/immich/releases/latest/download/example.env" -o .env

# Generate secure credentials
log "🔑 Generating secure credentials..."
DB_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)

# Configure .env
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" .env
sed -i "s|^UPLOAD_LOCATION=.*|UPLOAD_LOCATION=$UPLOAD_DIR|" .env

# Set version
if [ "$VERSION" != "release" ]; then
  sed -i "s|^IMMICH_VERSION=.*|IMMICH_VERSION=$VERSION|" .env
fi

# Set port if non-default
if [ "$PORT" != "2283" ]; then
  # Modify port mapping in docker-compose.yml
  sed -i "s|2283:2283|$PORT:2283|g" docker-compose.yml
fi

# Disable ML if requested
if [ "$SKIP_ML" = true ]; then
  log "⚠️ Machine learning disabled"
  export IMMICH_MACHINE_LEARNING_ENABLED=false
  echo "IMMICH_MACHINE_LEARNING_ENABLED=false" >> .env
fi

# Pull and start containers
log "🐳 Pulling Docker images (this may take a few minutes)..."
docker compose pull

log "🚀 Starting Immich..."
docker compose up -d

# Wait for server to be ready
log "⏳ Waiting for Immich to start..."
RETRIES=30
for i in $(seq 1 $RETRIES); do
  if curl -sf "http://localhost:${PORT}/api/server/ping" &>/dev/null; then
    break
  fi
  if [ "$i" -eq "$RETRIES" ]; then
    log "${YELLOW}⚠️ Server not responding yet. Check: docker compose logs${NC}"
    exit 0
  fi
  sleep 5
done

# Get server info
log "${GREEN}✅ Immich is running!${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  Immich Server Installed Successfully${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""
echo -e "  🌐 Web UI:      http://localhost:$PORT"
echo -e "  📁 Upload dir:  $UPLOAD_DIR"
echo -e "  📁 Install dir: $INSTALL_DIR"
echo -e "  🔑 DB Password: $DB_PASSWORD"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. Open http://$(hostname -I | awk '{print $1}'):$PORT"
echo -e "  2. Create your admin account"
echo -e "  3. Install Immich mobile app (iOS/Android)"
echo -e "  4. Connect app to http://$(hostname -I | awk '{print $1}'):$PORT"
echo ""
echo -e "  ${GREEN}Set up automated backups:${NC}"
echo -e "  bash scripts/backup.sh --schedule daily --keep 7"
echo ""
