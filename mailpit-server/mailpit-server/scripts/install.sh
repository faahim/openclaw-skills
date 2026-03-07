#!/bin/bash
# Install Mailpit - local SMTP email testing server
set -euo pipefail

INSTALL_DIR="${MAILPIT_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${MAILPIT_VERSION:-latest}"

echo "📧 Installing Mailpit..."

# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7*|armhf) ARCH="armv7" ;;
  armv6*) ARCH="armv6" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) OS="linux" ;;
  darwin) OS="darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Get download URL
if [ "$VERSION" = "latest" ]; then
  DOWNLOAD_URL="https://github.com/axllent/mailpit/releases/latest/download/mailpit-${OS}-${ARCH}.tar.gz"
else
  DOWNLOAD_URL="https://github.com/axllent/mailpit/releases/download/v${VERSION}/mailpit-${OS}-${ARCH}.tar.gz"
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download and extract
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "⬇️  Downloading from: $DOWNLOAD_URL"
curl -fsSL "$DOWNLOAD_URL" -o "$TMPDIR/mailpit.tar.gz"

echo "📦 Extracting..."
tar -xzf "$TMPDIR/mailpit.tar.gz" -C "$TMPDIR"

# Install binary
mv "$TMPDIR/mailpit" "$INSTALL_DIR/mailpit"
chmod +x "$INSTALL_DIR/mailpit"

# Verify
if "$INSTALL_DIR/mailpit" version 2>/dev/null; then
  echo ""
  echo "✅ Mailpit installed to $INSTALL_DIR/mailpit"
else
  # Some versions don't have 'version' command
  echo "✅ Mailpit installed to $INSTALL_DIR/mailpit"
fi

# Check PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "⚠️  $INSTALL_DIR is not in your PATH. Add it:"
  echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo ""
echo "🚀 Start with: mailpit"
echo "   SMTP: localhost:1025"
echo "   Web:  http://localhost:8025"
