#!/bin/bash
set -euo pipefail

# Install lazydocker — auto-detects OS and architecture
# Usage: bash install.sh [--version X.Y.Z]

VERSION=""
INSTALL_DIR="/usr/local/bin"
FALLBACK_DIR="$HOME/.local/bin"

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
  linux) OS="Linux" ;;
  darwin) OS="Darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l|armhf) ARCH="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "Detecting system... $OS $ARCH"

# Get latest version if not specified
if [ -z "$VERSION" ]; then
  VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
  if [ -z "$VERSION" ]; then
    echo "❌ Failed to fetch latest version. Try: bash install.sh --version 0.24.1"
    exit 1
  fi
fi

echo "Downloading lazydocker v${VERSION}..."

# Build download URL
FILENAME="lazydocker_${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/jesseduffield/lazydocker/releases/download/v${VERSION}/${FILENAME}"

# Download to temp
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

curl -sL "$URL" -o "$TMP_DIR/$FILENAME"
if [ $? -ne 0 ] || [ ! -s "$TMP_DIR/$FILENAME" ]; then
  echo "❌ Download failed from: $URL"
  exit 1
fi

# Extract
tar xzf "$TMP_DIR/$FILENAME" -C "$TMP_DIR" lazydocker

# Install
if [ -w "$INSTALL_DIR" ] || [ -w "$(dirname "$INSTALL_DIR")" ]; then
  mv "$TMP_DIR/lazydocker" "$INSTALL_DIR/lazydocker"
  chmod +x "$INSTALL_DIR/lazydocker"
  echo "Installing to $INSTALL_DIR/lazydocker..."
elif command -v sudo &>/dev/null; then
  sudo mv "$TMP_DIR/lazydocker" "$INSTALL_DIR/lazydocker"
  sudo chmod +x "$INSTALL_DIR/lazydocker"
  echo "Installing to $INSTALL_DIR/lazydocker (with sudo)..."
else
  mkdir -p "$FALLBACK_DIR"
  mv "$TMP_DIR/lazydocker" "$FALLBACK_DIR/lazydocker"
  chmod +x "$FALLBACK_DIR/lazydocker"
  INSTALL_DIR="$FALLBACK_DIR"
  echo "Installing to $FALLBACK_DIR/lazydocker (no sudo available)..."
  if [[ ":$PATH:" != *":$FALLBACK_DIR:"* ]]; then
    echo "⚠️  Add to PATH: export PATH=\"$FALLBACK_DIR:\$PATH\""
  fi
fi

# Verify
if command -v lazydocker &>/dev/null; then
  INSTALLED_VER=$(lazydocker --version 2>&1 | head -1)
  echo "✅ lazydocker v${VERSION} installed successfully"
  echo "   $INSTALLED_VER"
else
  echo "✅ Installed to $INSTALL_DIR/lazydocker"
  echo "   You may need to restart your shell or add it to PATH"
fi

# Check Docker
if ! command -v docker &>/dev/null; then
  echo ""
  echo "⚠️  Docker is not installed. Lazydocker requires Docker."
  echo "   Install: https://docs.docker.com/get-docker/"
fi
