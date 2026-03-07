#!/bin/bash
# Dnsmasq Manager — Install Script
# Detects OS and installs dnsmasq with sane defaults

set -euo pipefail

DISABLE_RESOLVED=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --disable-resolved) DISABLE_RESOLVED=true; shift ;;
    -h|--help)
      echo "Usage: bash install.sh [--disable-resolved]"
      echo "  --disable-resolved  Disable systemd-resolved (frees port 53)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🔍 Detecting OS..."

install_dnsmasq() {
  if command -v apt-get &>/dev/null; then
    echo "📦 Installing dnsmasq via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq dnsmasq
  elif command -v dnf &>/dev/null; then
    echo "📦 Installing dnsmasq via dnf..."
    sudo dnf install -y -q dnsmasq
  elif command -v yum &>/dev/null; then
    echo "📦 Installing dnsmasq via yum..."
    sudo yum install -y -q dnsmasq
  elif command -v pacman &>/dev/null; then
    echo "📦 Installing dnsmasq via pacman..."
    sudo pacman -S --noconfirm dnsmasq
  elif command -v apk &>/dev/null; then
    echo "📦 Installing dnsmasq via apk..."
    sudo apk add dnsmasq
  elif command -v brew &>/dev/null; then
    echo "📦 Installing dnsmasq via Homebrew..."
    brew install dnsmasq
  else
    echo "❌ Unsupported package manager. Install dnsmasq manually."
    exit 1
  fi
}

disable_systemd_resolved() {
  if systemctl is-active systemd-resolved &>/dev/null; then
    echo "⚠️  systemd-resolved is running on port 53"
    if [[ "$DISABLE_RESOLVED" == "true" ]]; then
      echo "🔧 Disabling systemd-resolved..."
      sudo systemctl stop systemd-resolved
      sudo systemctl disable systemd-resolved
      # Point /etc/resolv.conf to a real file
      sudo rm -f /etc/resolv.conf
      echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf > /dev/null
      echo "✅ systemd-resolved disabled"
    else
      echo ""
      echo "   Port 53 is in use by systemd-resolved."
      echo "   Re-run with --disable-resolved to free it."
      echo "   Or manually: sudo systemctl disable --now systemd-resolved"
      echo ""
    fi
  fi
}

# Check if already installed
if command -v dnsmasq &>/dev/null; then
  echo "✅ dnsmasq is already installed: $(dnsmasq --version | head -1)"
else
  install_dnsmasq
  echo "✅ dnsmasq installed: $(dnsmasq --version | head -1)"
fi

# Handle systemd-resolved conflict (Linux only)
if [[ "$(uname)" == "Linux" ]]; then
  disable_systemd_resolved
fi

# Create config directory
sudo mkdir -p /etc/dnsmasq.d
echo "conf-dir=/etc/dnsmasq.d/,*.conf" | sudo tee /etc/dnsmasq.d/.include > /dev/null 2>&1 || true

# Create custom hosts file
sudo touch /etc/dnsmasq.d/custom.hosts 2>/dev/null || true

echo ""
echo "✅ Dnsmasq installation complete!"
echo "   Next: bash scripts/configure.sh --mode dns --upstream '1.1.1.1,8.8.8.8'"
