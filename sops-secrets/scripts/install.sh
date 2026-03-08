#!/bin/bash
# Install SOPS and age encryption tools
set -euo pipefail

echo "🔐 Installing SOPS Secret Manager dependencies..."

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Normalize architecture
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Install age
install_age() {
  if command -v age &>/dev/null; then
    echo "✅ age already installed: $(age --version 2>&1 | head -1)"
    return 0
  fi

  echo "📦 Installing age..."
  
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq age
  elif command -v brew &>/dev/null; then
    brew install age
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm age
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y age
  else
    # Manual install
    AGE_VERSION="1.2.0"
    AGE_URL="https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
    echo "  Downloading from $AGE_URL"
    TMP=$(mktemp -d)
    curl -sL "$AGE_URL" | tar xz -C "$TMP"
    sudo mv "$TMP/age/age" /usr/local/bin/age
    sudo mv "$TMP/age/age-keygen" /usr/local/bin/age-keygen
    sudo chmod +x /usr/local/bin/age /usr/local/bin/age-keygen
    rm -rf "$TMP"
  fi

  echo "✅ age installed: $(age --version 2>&1 | head -1)"
}

# Install sops
install_sops() {
  if command -v sops &>/dev/null; then
    echo "✅ sops already installed: $(sops --version 2>&1 | head -1)"
    return 0
  fi

  echo "📦 Installing sops..."

  SOPS_VERSION="3.9.4"
  
  if command -v brew &>/dev/null; then
    brew install sops
  else
    SOPS_URL="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.${OS}.${ARCH}"
    echo "  Downloading from $SOPS_URL"
    sudo curl -sL "$SOPS_URL" -o /usr/local/bin/sops
    sudo chmod +x /usr/local/bin/sops
  fi

  echo "✅ sops installed: $(sops --version 2>&1 | head -1)"
}

# Install jq if missing
install_jq() {
  if command -v jq &>/dev/null; then
    echo "✅ jq already installed"
    return 0
  fi

  echo "📦 Installing jq..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y -qq jq
  elif command -v brew &>/dev/null; then
    brew install jq
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm jq
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y jq
  fi
  echo "✅ jq installed"
}

install_age
install_sops
install_jq

echo ""
echo "🎉 All dependencies installed!"
echo "   Next: Run 'bash scripts/setup-key.sh' to generate your encryption key"
