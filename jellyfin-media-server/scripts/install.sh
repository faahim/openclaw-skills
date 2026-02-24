#!/bin/bash
# Jellyfin Media Server Installer
# Installs Jellyfin via Docker with sensible defaults

set -euo pipefail

# Defaults
PORT="${JELLYFIN_PORT:-8096}"
MEDIA_DIR="${JELLYFIN_MEDIA_DIR:-/media}"
CONFIG_DIR="${JELLYFIN_CONFIG_DIR:-$HOME/.jellyfin/config}"
CACHE_DIR="${JELLYFIN_CACHE_DIR:-$HOME/.jellyfin/cache}"
CONTAINER_NAME="jellyfin"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --media-dir) MEDIA_DIR="$2"; shift 2 ;;
    --config-dir) CONFIG_DIR="$2"; shift 2 ;;
    --cache-dir) CACHE_DIR="$2"; shift 2 ;;
    --name) CONTAINER_NAME="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --port PORT          Web UI port (default: 8096)"
      echo "  --media-dir DIR      Media directory (default: /media)"
      echo "  --config-dir DIR     Config directory (default: ~/.jellyfin/config)"
      echo "  --cache-dir DIR      Cache directory (default: ~/.jellyfin/cache)"
      echo "  --name NAME          Container name (default: jellyfin)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🎬 Jellyfin Media Server Installer"
echo "==================================="
echo ""

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "❌ Docker not found. Installing..."
  if command -v apt-get &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    echo "✅ Docker installed. You may need to log out/in for group changes."
  elif command -v yum &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
  elif command -v brew &>/dev/null; then
    echo "   Install Docker Desktop from https://www.docker.com/products/docker-desktop"
    exit 1
  else
    echo "❌ Cannot auto-install Docker. Install manually: https://docs.docker.com/get-docker/"
    exit 1
  fi
fi

echo "✅ Docker: $(docker --version)"

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo ""
  echo "⚠️  Container '$CONTAINER_NAME' already exists."
  read -p "   Remove and reinstall? (y/N) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
  else
    echo "Aborted."
    exit 0
  fi
fi

# Create directories
echo ""
echo "📁 Creating directories..."
mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

# Create media subdirectories if they don't exist
for subdir in movies tv music photos; do
  mkdir -p "${MEDIA_DIR}/${subdir}" 2>/dev/null || true
done

echo "   Config: $CONFIG_DIR"
echo "   Cache:  $CACHE_DIR"
echo "   Media:  $MEDIA_DIR"

# Pull latest image
echo ""
echo "📥 Pulling Jellyfin image..."
docker pull jellyfin/jellyfin:latest

# Detect hardware acceleration
HWACCEL_ARGS=""
if [ -e /dev/dri/renderD128 ]; then
  echo "🎮 Intel/VAAPI GPU detected — enabling hardware transcoding"
  HWACCEL_ARGS="--device /dev/dri:/dev/dri"
elif command -v nvidia-smi &>/dev/null; then
  echo "🎮 NVIDIA GPU detected — enabling hardware transcoding"
  HWACCEL_ARGS="--runtime=nvidia --gpus all"
fi

# Run container
echo ""
echo "🚀 Starting Jellyfin..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "${PORT}:8096" \
  -p 8920:8920 \
  -p 7359:7359/udp \
  -p 1900:1900/udp \
  -v "${CONFIG_DIR}:/config" \
  -v "${CACHE_DIR}:/cache" \
  -v "${MEDIA_DIR}/movies:/media/movies:ro" \
  -v "${MEDIA_DIR}/tv:/media/tv:ro" \
  -v "${MEDIA_DIR}/music:/media/music:ro" \
  -v "${MEDIA_DIR}/photos:/media/photos:ro" \
  $HWACCEL_ARGS \
  jellyfin/jellyfin:latest

# Wait for startup
echo ""
echo "⏳ Waiting for Jellyfin to start..."
for i in $(seq 1 30); do
  if curl -sf "http://localhost:${PORT}/health" &>/dev/null; then
    break
  fi
  sleep 1
done

# Verify
if curl -sf "http://localhost:${PORT}/health" &>/dev/null; then
  echo ""
  echo "✅ Jellyfin is running!"
  echo ""
  echo "   🌐 Web UI: http://localhost:${PORT}"
  echo "   📁 Media:  ${MEDIA_DIR}"
  echo "   ⚙️  Config: ${CONFIG_DIR}"
  echo ""
  echo "   Next: Open the Web UI to complete the setup wizard."
  echo "   Or use: bash scripts/manage.sh create-user --name admin --password YourPassword"
else
  echo ""
  echo "⚠️  Jellyfin started but health check failed. Check logs:"
  echo "   docker logs $CONTAINER_NAME --tail 20"
fi

# Save install info
cat > "${CONFIG_DIR}/.jellyfin-skill-meta.json" <<EOF
{
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "port": ${PORT},
  "media_dir": "${MEDIA_DIR}",
  "config_dir": "${CONFIG_DIR}",
  "cache_dir": "${CACHE_DIR}",
  "container": "${CONTAINER_NAME}",
  "hwaccel": "$([ -n "$HWACCEL_ARGS" ] && echo 'enabled' || echo 'none')"
}
EOF
