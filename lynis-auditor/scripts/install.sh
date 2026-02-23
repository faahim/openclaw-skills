#!/bin/bash
# Lynis Security Auditor — Installer
# Auto-detects OS and installs Lynis + dependencies

set -euo pipefail

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

echo "🔧 Lynis Security Auditor — Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if already installed
if command -v lynis &>/dev/null && [[ "$FORCE" == "false" ]]; then
  VERSION=$(lynis --version 2>/dev/null | head -1)
  echo "✅ Lynis already installed (version: $VERSION)"
  echo "   Use --force to reinstall"
  exit 0
fi

# Detect OS
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  elif [ -f /etc/redhat-release ]; then
    echo "rhel"
  elif command -v sw_vers &>/dev/null; then
    echo "macos"
  else
    echo "unknown"
  fi
}

OS=$(detect_os)
echo "📦 Detected OS: $OS"

# Install jq if missing
if ! command -v jq &>/dev/null; then
  echo "📦 Installing jq..."
  case "$OS" in
    ubuntu|debian|pop|linuxmint)
      sudo apt-get update -qq && sudo apt-get install -y -qq jq ;;
    fedora|rhel|centos|rocky|alma)
      sudo dnf install -y -q jq ;;
    arch|manjaro)
      sudo pacman -Sy --noconfirm jq ;;
    alpine)
      sudo apk add jq ;;
    macos)
      brew install jq ;;
    *)
      echo "⚠️  Please install jq manually" ;;
  esac
fi

# Install Lynis
echo "📦 Installing Lynis..."
case "$OS" in
  ubuntu|debian|pop|linuxmint)
    # Try official repo first
    if ! sudo apt-get install -y -qq lynis 2>/dev/null; then
      echo "📦 Adding CISOfy repository..."
      sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 013baa07180c50a7101097ef9de922f1c2fde6c4 2>/dev/null || true
      echo "deb https://packages.cisofy.com/community/lynis/deb/ stable main" | sudo tee /etc/apt/sources.list.d/cisofy-lynis.list
      sudo apt-get update -qq && sudo apt-get install -y -qq lynis
    fi
    ;;
  fedora|rhel|centos|rocky|alma)
    sudo dnf install -y -q lynis 2>/dev/null || {
      echo "📦 Installing from source..."
      install_from_source
    }
    ;;
  arch|manjaro)
    sudo pacman -Sy --noconfirm lynis ;;
  alpine)
    sudo apk add lynis ;;
  macos)
    brew install lynis ;;
  *)
    install_from_source ;;
esac

install_from_source() {
  echo "📦 Installing Lynis from source..."
  cd /tmp
  if [ -d lynis ]; then rm -rf lynis; fi
  git clone --depth 1 https://github.com/CISOfy/lynis.git
  sudo mv lynis /opt/lynis
  sudo ln -sf /opt/lynis/lynis /usr/local/bin/lynis
  echo "✅ Installed from source to /opt/lynis"
}

# Verify installation
if command -v lynis &>/dev/null; then
  VERSION=$(lynis --version 2>/dev/null | head -1)
  echo ""
  echo "✅ Lynis installed successfully!"
  echo "   Version: $VERSION"
  echo "   Path: $(which lynis)"
  echo ""
  echo "🚀 Run your first audit:"
  echo "   sudo bash scripts/run.sh --audit"
else
  echo "❌ Installation failed. Try installing manually:"
  echo "   sudo apt-get install lynis  (Debian/Ubuntu)"
  echo "   sudo dnf install lynis      (Fedora/RHEL)"
  echo "   brew install lynis           (macOS)"
  exit 1
fi
