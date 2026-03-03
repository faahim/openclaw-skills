#!/bin/bash
# Mailpit Installer — downloads and installs the latest Mailpit binary
set -e

INSTALL_DIR="/usr/local/bin"
USER_INSTALL=false
UNINSTALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --user) USER_INSTALL=true; INSTALL_DIR="$HOME/.local/bin"; shift ;;
    --uninstall) UNINSTALL=true; shift ;;
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if $UNINSTALL; then
  echo "🗑️  Uninstalling Mailpit..."
  for dir in "/usr/local/bin" "$HOME/.local/bin"; do
    if [ -f "$dir/mailpit" ]; then
      rm -f "$dir/mailpit"
      echo "   Removed $dir/mailpit"
    fi
  done
  # Remove systemd service if exists
  if [ -f "/etc/systemd/system/mailpit.service" ]; then
    sudo systemctl stop mailpit 2>/dev/null || true
    sudo systemctl disable mailpit 2>/dev/null || true
    sudo rm -f /etc/systemd/system/mailpit.service
    sudo systemctl daemon-reload
    echo "   Removed systemd service"
  fi
  echo "✅ Mailpit uninstalled"
  exit 0
fi

# Check if already installed
if command -v mailpit &>/dev/null; then
  CURRENT=$(mailpit version 2>/dev/null || echo "unknown")
  echo "ℹ️  Mailpit already installed: $CURRENT"
  read -p "   Reinstall/update? [y/N] " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case $ARCH in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l|armhf)  ARCH="armv7" ;;
  armv6l)        ARCH="armv6" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case $OS in
  linux)  OS="linux" ;;
  darwin) OS="darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

echo "🔍 Detecting system: ${OS}/${ARCH}"

# Get latest release URL from GitHub
echo "📥 Fetching latest Mailpit release..."
LATEST_URL=$(curl -s https://api.github.com/repos/axllent/mailpit/releases/latest \
  | grep "browser_download_url.*mailpit-${OS}-${ARCH}\.tar\.gz" \
  | head -1 \
  | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
  echo "❌ Could not find release for ${OS}/${ARCH}"
  echo "   Check https://github.com/axllent/mailpit/releases"
  exit 1
fi

VERSION=$(echo "$LATEST_URL" | grep -oP 'v[\d.]+' | head -1)
echo "   Latest version: $VERSION"

# Download and extract
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "⬇️  Downloading..."
curl -sL "$LATEST_URL" -o "$TMPDIR/mailpit.tar.gz"

echo "📦 Extracting..."
tar -xzf "$TMPDIR/mailpit.tar.gz" -C "$TMPDIR"

# Install binary
mkdir -p "$INSTALL_DIR"

if [ "$INSTALL_DIR" = "/usr/local/bin" ] && [ "$(id -u)" != "0" ]; then
  echo "🔐 Installing to $INSTALL_DIR (requires sudo)..."
  sudo mv "$TMPDIR/mailpit" "$INSTALL_DIR/mailpit"
  sudo chmod +x "$INSTALL_DIR/mailpit"
else
  mv "$TMPDIR/mailpit" "$INSTALL_DIR/mailpit"
  chmod +x "$INSTALL_DIR/mailpit"
fi

# Verify
if command -v mailpit &>/dev/null; then
  echo "✅ Mailpit $VERSION installed to $INSTALL_DIR/mailpit"
  echo ""
  echo "   Start:  mailpit"
  echo "   SMTP:   localhost:1025"
  echo "   Web UI: http://localhost:8025"
else
  echo "✅ Mailpit installed to $INSTALL_DIR/mailpit"
  if $USER_INSTALL; then
    echo "⚠️  Make sure $INSTALL_DIR is in your PATH:"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
fi
