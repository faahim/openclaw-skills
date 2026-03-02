#!/bin/bash
# Install ctop - container metrics viewer
set -e

CTOP_VERSION="${CTOP_VERSION:-0.7.7}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

echo "=== Ctop Container Monitor — Installer ==="
echo ""

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l)  ARCH="armv6" ;;
  *)       echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "📦 Detected: ${OS}-${ARCH}"

# Check if ctop already installed
if command -v ctop &>/dev/null; then
  CURRENT=$(ctop -v 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
  echo "ℹ️  ctop already installed (version: $CURRENT)"
  read -p "   Reinstall? [y/N] " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && echo "Skipping install." && exit 0
fi

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "⚠️  Docker not found. ctop requires Docker to monitor containers."
  echo "   Install Docker first: https://docs.docker.com/engine/install/"
  exit 1
fi

if ! docker info &>/dev/null 2>&1; then
  echo "⚠️  Docker daemon not running or current user lacks permissions."
  echo "   Try: sudo systemctl start docker"
  echo "   Or:  sudo usermod -aG docker $USER && newgrp docker"
fi

# Download ctop
DOWNLOAD_URL="https://github.com/bcicen/ctop/releases/download/v${CTOP_VERSION}/ctop-${CTOP_VERSION}-${OS}-${ARCH}"
TEMP_FILE=$(mktemp)

echo "⬇️  Downloading ctop v${CTOP_VERSION}..."
if curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_FILE"; then
  chmod +x "$TEMP_FILE"

  # Install (try without sudo first)
  if [ -w "$INSTALL_DIR" ]; then
    mv "$TEMP_FILE" "${INSTALL_DIR}/ctop"
  else
    echo "   Need sudo to install to ${INSTALL_DIR}"
    sudo mv "$TEMP_FILE" "${INSTALL_DIR}/ctop"
    sudo chmod +x "${INSTALL_DIR}/ctop"
  fi

  echo "✅ ctop installed to ${INSTALL_DIR}/ctop"
  ctop -v 2>&1 || true
else
  rm -f "$TEMP_FILE"
  echo "❌ Download failed. Trying alternative method..."

  # Try via Docker
  echo "   Attempting Docker-based install..."
  docker pull quay.io/vektorlab/ctop:latest 2>/dev/null && \
    echo "✅ ctop available via Docker: docker run --rm -ti -v /var/run/docker.sock:/var/run/docker.sock quay.io/vektorlab/ctop:latest" && \
    exit 0

  echo "❌ All install methods failed."
  echo "   Manual install: https://github.com/bcicen/ctop/releases"
  exit 1
fi

# Install dependencies for monitoring scripts
echo ""
echo "📋 Checking script dependencies..."

for cmd in curl jq awk; do
  if command -v "$cmd" &>/dev/null; then
    echo "   ✅ $cmd"
  else
    echo "   ❌ $cmd — install with: sudo apt-get install $cmd"
  fi
done

echo ""
echo "🎉 Setup complete! Run 'ctop' for interactive monitoring."
echo "   Or 'bash scripts/monitor.sh' for automated alerting."
