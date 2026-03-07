#!/bin/bash
# Stripe CLI Installer — cross-platform
set -e

echo "🔧 Installing Stripe CLI..."

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

install_linux() {
  # Try apt first (Debian/Ubuntu)
  if command -v apt-get &>/dev/null; then
    echo "📦 Installing via apt..."
    
    # Add Stripe GPG key
    if ! gpg --list-keys "Stripe, Inc." &>/dev/null 2>&1; then
      curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | gpg --dearmor | sudo tee /usr/share/keyrings/stripe.gpg >/dev/null 2>&1
    fi
    
    # Add Stripe repo
    echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | sudo tee /etc/apt/sources.list.d/stripe.list >/dev/null
    
    sudo apt-get update -qq
    sudo apt-get install -y -qq stripe
    
  # Try yum/dnf (RHEL/Fedora)
  elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    echo "📦 Installing via rpm..."
    PKG_MGR=$(command -v dnf || command -v yum)
    
    cat <<EOF | sudo tee /etc/yum.repos.d/stripe-cli.repo >/dev/null
[stripe-cli]
name=Stripe CLI
baseurl=https://packages.stripe.dev/stripe-cli-rpm-local
enabled=1
gpgcheck=0
EOF
    
    sudo $PKG_MGR install -y stripe
    
  # Fallback: direct binary
  else
    echo "📦 Installing via direct download..."
    install_binary
  fi
}

install_macos() {
  if command -v brew &>/dev/null; then
    echo "📦 Installing via Homebrew..."
    brew install stripe/stripe-cli/stripe
  else
    echo "📦 Installing via direct download..."
    install_binary
  fi
}

install_binary() {
  local DEST="$HOME/.local/bin"
  mkdir -p "$DEST"
  
  local DOWNLOAD_URL=""
  case "${OS}_${ARCH}" in
    Linux_x86_64)   DOWNLOAD_URL="https://github.com/stripe/stripe-cli/releases/latest/download/stripe_linux_x86_64.tar.gz" ;;
    Linux_aarch64)  DOWNLOAD_URL="https://github.com/stripe/stripe-cli/releases/latest/download/stripe_linux_arm64.tar.gz" ;;
    Linux_arm64)    DOWNLOAD_URL="https://github.com/stripe/stripe-cli/releases/latest/download/stripe_linux_arm64.tar.gz" ;;
    Darwin_x86_64)  DOWNLOAD_URL="https://github.com/stripe/stripe-cli/releases/latest/download/stripe_darwin_x86_64.tar.gz" ;;
    Darwin_arm64)   DOWNLOAD_URL="https://github.com/stripe/stripe-cli/releases/latest/download/stripe_darwin_arm64.tar.gz" ;;
    *)
      echo "❌ Unsupported platform: ${OS}_${ARCH}"
      exit 1
      ;;
  esac
  
  echo "⬇️  Downloading from $DOWNLOAD_URL..."
  local TMP=$(mktemp -d)
  curl -sL "$DOWNLOAD_URL" | tar xz -C "$TMP"
  mv "$TMP/stripe" "$DEST/stripe"
  chmod +x "$DEST/stripe"
  rm -rf "$TMP"
  
  # Add to PATH if needed
  if ! echo "$PATH" | grep -q "$DEST"; then
    echo "export PATH=\"\$PATH:$DEST\"" >> "$HOME/.bashrc"
    export PATH="$PATH:$DEST"
    echo "ℹ️  Added $DEST to PATH in .bashrc"
  fi
}

# Main
case "$OS" in
  Linux)  install_linux ;;
  Darwin) install_macos ;;
  *)
    echo "❌ Unsupported OS: $OS"
    exit 1
    ;;
esac

# Verify
if command -v stripe &>/dev/null; then
  VERSION=$(stripe version 2>/dev/null || stripe --version 2>/dev/null || echo "unknown")
  echo ""
  echo "✅ Stripe CLI installed successfully!"
  echo "   Version: $VERSION"
  echo ""
  echo "Next steps:"
  echo "  1. stripe login              # Authenticate with Stripe"
  echo "  2. stripe listen             # Start webhook forwarding"
  echo "  3. stripe trigger <event>    # Send test events"
else
  echo "❌ Installation failed. Try manual install: https://stripe.com/docs/stripe-cli"
  exit 1
fi
