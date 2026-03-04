#!/bin/bash
# Railway CLI Installer
# Installs the Railway CLI and verifies the installation

set -euo pipefail

INSTALL_DIR="${RAILWAY_INSTALL_DIR:-$HOME/.railway}"
BIN_DIR="$INSTALL_DIR/bin"

echo "🚂 Installing Railway CLI..."

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux|darwin) ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Check if already installed
if command -v railway &>/dev/null; then
  CURRENT_VERSION=$(railway --version 2>/dev/null || echo "unknown")
  echo "ℹ️  Railway CLI already installed: $CURRENT_VERSION"
  read -p "Reinstall/update? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "✅ Keeping current installation"
    exit 0
  fi
fi

# Install via official installer
echo "📦 Downloading Railway CLI for $OS/$ARCH..."
curl -fsSL https://railway.app/install.sh | sh

# Verify installation
if command -v railway &>/dev/null; then
  VERSION=$(railway --version 2>/dev/null || echo "installed")
  echo ""
  echo "✅ Railway CLI installed successfully!"
  echo "   Version: $VERSION"
  echo ""
  echo "Next steps:"
  echo "  1. Run 'railway login' to authenticate"
  echo "  2. Run 'railway init' in your project directory"
  echo "  3. Run 'railway up' to deploy"
elif [ -f "$BIN_DIR/railway" ]; then
  echo ""
  echo "✅ Railway CLI installed to $BIN_DIR/railway"
  echo ""
  echo "⚠️  Add to PATH:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
  echo ""
  echo "  Or add to ~/.bashrc:"
  echo "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc"
else
  echo "❌ Installation may have failed. Try manual install:"
  echo "  npm install -g @railway/cli"
  exit 1
fi
