#!/bin/bash
# MinIO Object Storage — Install Script
# Installs MinIO server and mc (MinIO Client)

set -euo pipefail

MINIO_VERSION="latest"
INSTALL_DIR="/usr/local/bin"

echo "🔧 Installing MinIO Object Storage..."

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
  x86_64|amd64)  ARCH="amd64" ;;
  aarch64|arm64)  ARCH="arm64" ;;
  armv7l)         ARCH="arm" ;;
  *)              echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "📦 Detected: $OS/$ARCH"

# Install MinIO Server
install_server() {
  if command -v minio &>/dev/null; then
    echo "✅ MinIO server already installed: $(minio --version 2>/dev/null | head -1)"
    return 0
  fi

  echo "📥 Downloading MinIO server..."
  local url="https://dl.min.io/server/minio/release/${OS}-${ARCH}/minio"

  if command -v wget &>/dev/null; then
    wget -q --show-progress -O /tmp/minio "$url"
  elif command -v curl &>/dev/null; then
    curl -fSL --progress-bar -o /tmp/minio "$url"
  else
    echo "❌ Neither wget nor curl found. Install one first."
    exit 1
  fi

  chmod +x /tmp/minio

  if [ -w "$INSTALL_DIR" ]; then
    mv /tmp/minio "$INSTALL_DIR/minio"
  else
    echo "🔑 Need sudo to install to $INSTALL_DIR"
    sudo mv /tmp/minio "$INSTALL_DIR/minio"
  fi

  echo "✅ MinIO server installed: $(minio --version 2>/dev/null | head -1)"
}

# Install MinIO Client (mc)
install_client() {
  if command -v mc &>/dev/null; then
    local ver=$(mc --version 2>/dev/null | head -1)
    if echo "$ver" | grep -qi "minio"; then
      echo "✅ MinIO client already installed: $ver"
      return 0
    fi
  fi

  echo "📥 Downloading MinIO client (mc)..."
  local url="https://dl.min.io/client/mc/release/${OS}-${ARCH}/mc"

  if command -v wget &>/dev/null; then
    wget -q --show-progress -O /tmp/mc "$url"
  elif command -v curl &>/dev/null; then
    curl -fSL --progress-bar -o /tmp/mc "$url"
  else
    echo "❌ Neither wget nor curl found."
    exit 1
  fi

  chmod +x /tmp/mc

  if [ -w "$INSTALL_DIR" ]; then
    mv /tmp/mc "$INSTALL_DIR/mc"
  else
    sudo mv /tmp/mc "$INSTALL_DIR/mc"
  fi

  echo "✅ MinIO client installed"
}

# Run installation
install_server
install_client

echo ""
echo "🎉 MinIO installation complete!"
echo "   Server: $(which minio)"
echo "   Client: $(which mc)"
echo ""
echo "Next: Run 'bash scripts/run.sh start' to start the server"
