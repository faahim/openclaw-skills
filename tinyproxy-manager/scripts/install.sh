#!/bin/bash
# Tinyproxy Installer — Detects OS and installs tinyproxy
set -euo pipefail

UNINSTALL=false
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=true ;;
  esac
done

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  elif command -v sw_vers &>/dev/null; then
    echo "macos"
  else
    echo "unknown"
  fi
}

OS=$(detect_os)

if $UNINSTALL; then
  echo "🗑️  Uninstalling tinyproxy..."
  
  # Stop service
  if systemctl is-active --quiet tinyproxy 2>/dev/null; then
    sudo systemctl stop tinyproxy
    sudo systemctl disable tinyproxy 2>/dev/null || true
  fi
  
  case "$OS" in
    ubuntu|debian|pop|linuxmint)
      sudo apt-get remove -y tinyproxy
      ;;
    fedora|centos|rhel|rocky|alma)
      sudo dnf remove -y tinyproxy 2>/dev/null || sudo yum remove -y tinyproxy
      ;;
    alpine)
      sudo apk del tinyproxy
      ;;
    arch|manjaro)
      sudo pacman -R --noconfirm tinyproxy
      ;;
    macos)
      brew uninstall tinyproxy 2>/dev/null || true
      ;;
  esac
  
  echo "✅ Tinyproxy uninstalled"
  echo "   Config files preserved at /etc/tinyproxy/ (remove manually if desired)"
  exit 0
fi

echo "🔍 Detected OS: $OS"

# Check if already installed
if command -v tinyproxy &>/dev/null; then
  VERSION=$(tinyproxy -v 2>&1 | head -1)
  echo "✅ Tinyproxy already installed: $VERSION"
  exit 0
fi

echo "📦 Installing tinyproxy..."

case "$OS" in
  ubuntu|debian|pop|linuxmint)
    sudo apt-get update -qq
    sudo apt-get install -y tinyproxy
    ;;
  fedora|centos|rhel|rocky|alma)
    sudo dnf install -y tinyproxy 2>/dev/null || sudo yum install -y tinyproxy
    ;;
  alpine)
    sudo apk add tinyproxy
    ;;
  arch|manjaro)
    sudo pacman -S --noconfirm tinyproxy
    ;;
  macos)
    if ! command -v brew &>/dev/null; then
      echo "❌ Homebrew required. Install from https://brew.sh"
      exit 1
    fi
    brew install tinyproxy
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    echo "   Install tinyproxy manually: https://tinyproxy.github.io/"
    exit 1
    ;;
esac

# Verify installation
if command -v tinyproxy &>/dev/null; then
  VERSION=$(tinyproxy -v 2>&1 | head -1)
  echo "✅ Installed: $VERSION"
else
  echo "❌ Installation failed"
  exit 1
fi

# Set up default config if not exists
CONF="/etc/tinyproxy/tinyproxy.conf"
if [ ! -f "$CONF" ]; then
  CONF=$(find /etc -name "tinyproxy.conf" 2>/dev/null | head -1)
fi

if [ -n "$CONF" ] && [ -f "$CONF" ]; then
  # Backup original config
  sudo cp "$CONF" "${CONF}.orig" 2>/dev/null || true
  echo "📋 Config at: $CONF"
  echo "📋 Original backed up to: ${CONF}.orig"
fi

# Create log directory
sudo mkdir -p /var/log/tinyproxy
sudo chown nobody:nogroup /var/log/tinyproxy 2>/dev/null || \
  sudo chown nobody:nobody /var/log/tinyproxy 2>/dev/null || true

echo ""
echo "🚀 Ready! Start with: bash scripts/run.sh start"
echo "   Default: listening on 127.0.0.1:8888"
