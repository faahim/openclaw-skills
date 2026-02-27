#!/bin/bash
# Install ngrok on Linux/macOS
set -e

echo "🔧 Installing ngrok..."

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l|armhf) ARCH="arm" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) PLATFORM="linux" ;;
  darwin) PLATFORM="darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Check if already installed
if command -v ngrok &>/dev/null; then
  CURRENT_VERSION=$(ngrok version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
  echo "ℹ️  ngrok already installed (v${CURRENT_VERSION})"
  read -p "Reinstall latest? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "✅ Keeping current installation"
    exit 0
  fi
fi

# Download latest ngrok
DOWNLOAD_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-${PLATFORM}-${ARCH}.tgz"
TEMP_DIR=$(mktemp -d)

echo "📥 Downloading ngrok for ${PLATFORM}/${ARCH}..."
curl -sL "$DOWNLOAD_URL" -o "$TEMP_DIR/ngrok.tgz"

echo "📦 Extracting..."
tar -xzf "$TEMP_DIR/ngrok.tgz" -C "$TEMP_DIR"

# Install to /usr/local/bin or ~/bin
if [ -w /usr/local/bin ]; then
  INSTALL_DIR="/usr/local/bin"
elif [ -w "$HOME/.local/bin" ]; then
  INSTALL_DIR="$HOME/.local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
fi

mv "$TEMP_DIR/ngrok" "$INSTALL_DIR/ngrok"
chmod +x "$INSTALL_DIR/ngrok"

# Cleanup
rm -rf "$TEMP_DIR"

# Verify
if command -v ngrok &>/dev/null; then
  VERSION=$(ngrok version 2>/dev/null)
  echo "✅ ngrok installed successfully: $VERSION"
  echo "📍 Location: $(which ngrok)"
else
  echo "✅ ngrok installed to $INSTALL_DIR/ngrok"
  echo "⚠️  Make sure $INSTALL_DIR is in your PATH"
  echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo ""
echo "Next steps:"
echo "  1. Get your authtoken: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "  2. Authenticate: bash scripts/ngrok.sh auth YOUR_TOKEN"
echo "  3. Start a tunnel: bash scripts/ngrok.sh start --port 3000"
