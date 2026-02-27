#!/bin/bash
# Install Vale prose linter
set -euo pipefail

VALE_VERSION="${VALE_VERSION:-3.9.5}"
INSTALL_DIR="/usr/local/bin"
USE_SUDO=true

# Check if already installed
if command -v vale &>/dev/null; then
  CURRENT=$(vale --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
  echo "✅ Vale already installed (v${CURRENT})"
  if [[ "$CURRENT" == "$VALE_VERSION" ]]; then
    echo "   Already at target version. Nothing to do."
    exit 0
  fi
  echo "   Upgrading to v${VALE_VERSION}..."
fi

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="64-bit" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) PLATFORM="Linux" ;;
  darwin) PLATFORM="macOS" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Check for sudo
if ! command -v sudo &>/dev/null || ! sudo -n true 2>/dev/null; then
  INSTALL_DIR="$HOME/.local/bin"
  USE_SUDO=false
  mkdir -p "$INSTALL_DIR"
  echo "ℹ️  No sudo access. Installing to $INSTALL_DIR"
  if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "⚠️  Add to PATH: export PATH=\"$INSTALL_DIR:\$PATH\""
    echo "   Add this to your ~/.bashrc or ~/.zshrc"
  fi
fi

# Download
FILENAME="vale_${VALE_VERSION}_${PLATFORM}_${ARCH}.tar.gz"
URL="https://github.com/errata-ai/vale/releases/download/v${VALE_VERSION}/${FILENAME}"

echo "📥 Downloading Vale v${VALE_VERSION} for ${PLATFORM}/${ARCH}..."
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl -sL "$URL" -o "$TMPDIR/vale.tar.gz"

# Extract
echo "📦 Extracting..."
tar -xzf "$TMPDIR/vale.tar.gz" -C "$TMPDIR"

# Install
if $USE_SUDO; then
  sudo mv "$TMPDIR/vale" "$INSTALL_DIR/vale"
  sudo chmod +x "$INSTALL_DIR/vale"
else
  mv "$TMPDIR/vale" "$INSTALL_DIR/vale"
  chmod +x "$INSTALL_DIR/vale"
fi

# Verify
if command -v vale &>/dev/null; then
  echo "✅ Vale v$(vale --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "$VALE_VERSION") installed to $(which vale)"
else
  echo "✅ Vale installed to $INSTALL_DIR/vale"
  echo "   Run: export PATH=\"$INSTALL_DIR:\$PATH\""
fi
