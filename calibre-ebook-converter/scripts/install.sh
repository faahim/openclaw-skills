#!/bin/bash
# Install Calibre CLI tools
set -e

echo "🔍 Checking for Calibre..."

if command -v ebook-convert &>/dev/null; then
  VERSION=$(ebook-convert --version 2>&1 | head -1)
  echo "✅ Calibre already installed: $VERSION"
  exit 0
fi

echo "📦 Installing Calibre..."

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  if command -v brew &>/dev/null; then
    brew install --cask calibre
  else
    echo "❌ Homebrew not found. Install from: https://calibre-ebook.com/download"
    exit 1
  fi
elif [[ -f /etc/debian_version ]]; then
  # Debian/Ubuntu
  sudo apt-get update -qq
  sudo apt-get install -y -qq calibre
elif [[ -f /etc/redhat-release ]]; then
  # RHEL/CentOS/Fedora
  sudo dnf install -y calibre 2>/dev/null || sudo yum install -y calibre
elif [[ -f /etc/arch-release ]]; then
  # Arch
  sudo pacman -S --noconfirm calibre
else
  # Generic Linux — official installer
  echo "Using Calibre's official Linux installer..."
  sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin
fi

# Verify
if command -v ebook-convert &>/dev/null; then
  VERSION=$(ebook-convert --version 2>&1 | head -1)
  echo "✅ Calibre installed successfully: $VERSION"
else
  echo "❌ Installation failed. Install manually: https://calibre-ebook.com/download"
  exit 1
fi
