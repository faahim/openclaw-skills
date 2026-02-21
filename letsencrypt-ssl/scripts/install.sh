#!/bin/bash
# Let's Encrypt SSL Manager — Certbot Installer
# Detects OS and installs certbot with appropriate method

set -euo pipefail

echo "🔐 Let's Encrypt SSL Manager — Installing certbot..."

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  elif [ "$(uname)" = "Darwin" ]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

OS=$(detect_os)
echo "Detected OS: $OS"

case "$OS" in
  ubuntu|debian)
    echo "Installing via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq certbot openssl
    # Install nginx plugin if nginx is present
    if command -v nginx &>/dev/null; then
      sudo apt-get install -y -qq python3-certbot-nginx
    fi
    # Install apache plugin if apache is present
    if command -v apache2 &>/dev/null; then
      sudo apt-get install -y -qq python3-certbot-apache
    fi
    ;;
  centos|rhel|fedora|rocky|alma)
    echo "Installing via dnf/yum..."
    if command -v dnf &>/dev/null; then
      sudo dnf install -y epel-release
      sudo dnf install -y certbot openssl
    else
      sudo yum install -y epel-release
      sudo yum install -y certbot openssl
    fi
    ;;
  alpine)
    echo "Installing via apk..."
    sudo apk add --no-cache certbot openssl
    ;;
  arch|manjaro)
    echo "Installing via pacman..."
    sudo pacman -S --noconfirm certbot openssl
    ;;
  macos)
    echo "Installing via Homebrew..."
    if ! command -v brew &>/dev/null; then
      echo "❌ Homebrew not found. Install from https://brew.sh"
      exit 1
    fi
    brew install certbot openssl
    ;;
  *)
    echo "⚠️  Unknown OS. Trying snap..."
    if command -v snap &>/dev/null; then
      sudo snap install --classic certbot
      sudo ln -sf /snap/bin/certbot /usr/bin/certbot
    elif command -v pip3 &>/dev/null; then
      echo "Trying pip..."
      pip3 install certbot
    else
      echo "❌ Could not install certbot automatically."
      echo "   Visit: https://certbot.eff.org/instructions"
      exit 1
    fi
    ;;
esac

# Verify installation
if command -v certbot &>/dev/null; then
  VERSION=$(certbot --version 2>&1)
  echo "✅ Certbot installed: $VERSION"
else
  echo "❌ Certbot installation failed. Check errors above."
  exit 1
fi

if command -v openssl &>/dev/null; then
  echo "✅ OpenSSL available: $(openssl version)"
else
  echo "⚠️  OpenSSL not found — certificate inspection won't work"
fi

echo ""
echo "🎉 Installation complete! Run: bash scripts/ssl.sh obtain --domain yourdomain.com --email you@email.com"
