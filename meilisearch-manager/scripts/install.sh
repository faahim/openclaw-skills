#!/bin/bash
# Install Meilisearch binary
set -euo pipefail

INSTALL_DIR="${MEILI_INSTALL_DIR:-/usr/local/bin}"
VERSION="${1:-latest}"

echo "🔍 Detecting system architecture..."
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="aarch64" ;;
  armv7l) ARCH="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) OS="linux" ;;
  darwin) OS="macos" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Get latest version if not specified
if [ "$VERSION" = "latest" ]; then
  echo "📡 Fetching latest version..."
  VERSION=$(curl -s https://api.github.com/repos/meilisearch/meilisearch/releases/latest | jq -r '.tag_name')
  if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
    echo "❌ Failed to fetch latest version. Using fallback v1.12.0"
    VERSION="v1.12.0"
  fi
fi

echo "📦 Installing Meilisearch $VERSION for $OS/$ARCH..."

# Download binary
DOWNLOAD_URL="https://github.com/meilisearch/meilisearch/releases/download/${VERSION}/meilisearch-${OS}-${ARCH}"
TMP_FILE=$(mktemp)

echo "⬇️  Downloading from $DOWNLOAD_URL..."
if ! curl -fsSL -o "$TMP_FILE" "$DOWNLOAD_URL"; then
  echo "❌ Download failed. Check version and architecture."
  rm -f "$TMP_FILE"
  exit 1
fi

# Install
chmod +x "$TMP_FILE"

if [ -w "$INSTALL_DIR" ]; then
  mv "$TMP_FILE" "$INSTALL_DIR/meilisearch"
else
  echo "🔐 Need sudo to install to $INSTALL_DIR"
  sudo mv "$TMP_FILE" "$INSTALL_DIR/meilisearch"
fi

echo "✅ Meilisearch $VERSION installed to $INSTALL_DIR/meilisearch"
meilisearch --version 2>/dev/null || echo "⚠️  Binary installed but not in PATH. Add $INSTALL_DIR to PATH."
