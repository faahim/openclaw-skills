#!/bin/bash
# Archive Manager — Dependency Installer
# Detects OS and installs all required archive tools

set -e

echo "🗃️  Archive Manager — Installing dependencies..."

install_debian() {
  sudo apt-get update -qq
  sudo apt-get install -y -qq tar gzip bzip2 xz-utils zstd p7zip-full zip unzip unrar 2>/dev/null || \
  sudo apt-get install -y -qq tar gzip bzip2 xz-utils zstd p7zip-full zip unzip unrar-free 2>/dev/null
}

install_rhel() {
  sudo dnf install -y tar gzip bzip2 xz zstd p7zip p7zip-plugins zip unzip unrar 2>/dev/null || \
  sudo yum install -y tar gzip bzip2 xz zstd p7zip p7zip-plugins zip unzip 2>/dev/null
}

install_arch() {
  sudo pacman -S --noconfirm tar gzip bzip2 xz zstd p7zip zip unzip unrar 2>/dev/null
}

install_macos() {
  if ! command -v brew &>/dev/null; then
    echo "❌ Homebrew not found. Install from https://brew.sh"
    exit 1
  fi
  brew install p7zip zstd unrar 2>/dev/null || true
}

# Detect OS
if [ -f /etc/debian_version ]; then
  install_debian
elif [ -f /etc/redhat-release ] || [ -f /etc/fedora-release ]; then
  install_rhel
elif [ -f /etc/arch-release ]; then
  install_arch
elif [ "$(uname)" = "Darwin" ]; then
  install_macos
else
  echo "⚠️  Unknown OS. Install manually: p7zip-full, unrar, zstd, xz-utils"
  exit 1
fi

echo ""
echo "✅ Dependencies installed. Checking tools:"
for tool in tar gzip bzip2 xz zstd 7z zip unzip; do
  if command -v "$tool" &>/dev/null; then
    echo "  ✅ $tool"
  else
    echo "  ❌ $tool (not found)"
  fi
done

# unrar might be at different paths
if command -v unrar &>/dev/null; then
  echo "  ✅ unrar"
else
  echo "  ⚠️  unrar (not found — RAR extraction unavailable)"
fi

echo ""
echo "🗃️  Archive Manager ready!"
