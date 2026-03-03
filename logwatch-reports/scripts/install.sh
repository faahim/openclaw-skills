#!/bin/bash
# Install Logwatch and dependencies
set -e

echo "🔍 Logwatch Report Generator — Installer"
echo "=========================================="

# Detect package manager
detect_pm() {
  if command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v yum &>/dev/null; then
    echo "yum"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v pacman &>/dev/null; then
    echo "pacman"
  elif command -v apk &>/dev/null; then
    echo "apk"
  else
    echo "unknown"
  fi
}

PM=$(detect_pm)
echo "📦 Detected package manager: $PM"

# Check if logwatch is already installed
if command -v logwatch &>/dev/null; then
  CURRENT_VER=$(logwatch --version 2>&1 | head -1)
  echo "✅ Logwatch already installed: $CURRENT_VER"
  exit 0
fi

echo "📥 Installing logwatch..."

case $PM in
  apt)
    sudo apt-get update -qq
    sudo apt-get install -y logwatch
    ;;
  yum)
    sudo yum install -y logwatch
    ;;
  dnf)
    sudo dnf install -y logwatch
    ;;
  pacman)
    sudo pacman -S --noconfirm logwatch
    ;;
  apk)
    sudo apk add logwatch
    ;;
  *)
    echo "❌ Unsupported package manager. Install logwatch manually:"
    echo "   https://sourceforge.net/projects/logwatch/"
    exit 1
    ;;
esac

# Create local config directories
sudo mkdir -p /etc/logwatch/conf
sudo mkdir -p /etc/logwatch/conf/logfiles
sudo mkdir -p /etc/logwatch/conf/services
sudo mkdir -p /var/log/logwatch

# Verify installation
if command -v logwatch &>/dev/null; then
  echo "✅ Logwatch installed successfully!"
  logwatch --version 2>&1 | head -1
  echo ""
  echo "Next steps:"
  echo "  1. Generate a report:  bash scripts/report.sh"
  echo "  2. Set up daily email: bash scripts/setup-daily.sh --email you@example.com"
else
  echo "❌ Installation failed. Check errors above."
  exit 1
fi
