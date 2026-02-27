#!/bin/bash
set -euo pipefail

# Litestream Installer
# Installs litestream and optionally sets up systemd service

VERSION="${LITESTREAM_VERSION:-v0.3.13}"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="arm7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "🔧 Installing Litestream $VERSION for $OS/$ARCH..."

if command -v litestream &>/dev/null; then
  CURRENT=$(litestream version 2>/dev/null || echo "unknown")
  echo "⚠️ Litestream already installed (version: $CURRENT)"
  read -p "Reinstall? [y/N] " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

if [ "$OS" = "linux" ]; then
  if command -v apt-get &>/dev/null; then
    URL="https://github.com/benbjohnson/litestream/releases/download/${VERSION}/litestream-${VERSION}-${OS}-${ARCH}.deb"
    echo "📥 Downloading $URL"
    wget -q "$URL" -O /tmp/litestream.deb
    sudo dpkg -i /tmp/litestream.deb
    rm /tmp/litestream.deb
  else
    URL="https://github.com/benbjohnson/litestream/releases/download/${VERSION}/litestream-${VERSION}-${OS}-${ARCH}.tar.gz"
    echo "📥 Downloading $URL"
    wget -q "$URL" -O /tmp/litestream.tar.gz
    sudo tar -xzf /tmp/litestream.tar.gz -C /usr/local/bin/
    rm /tmp/litestream.tar.gz
  fi
elif [ "$OS" = "darwin" ]; then
  if command -v brew &>/dev/null; then
    brew install benbjohnson/litestream/litestream
  else
    URL="https://github.com/benbjohnson/litestream/releases/download/${VERSION}/litestream-${VERSION}-${OS}-${ARCH}.zip"
    echo "📥 Downloading $URL"
    wget -q "$URL" -O /tmp/litestream.zip
    sudo unzip -o /tmp/litestream.zip -d /usr/local/bin/
    rm /tmp/litestream.zip
  fi
else
  echo "❌ Unsupported OS: $OS"
  exit 1
fi

echo "✅ Litestream installed: $(litestream version)"
