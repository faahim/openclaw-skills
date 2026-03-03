#!/bin/bash
# Stripe CLI Installer — detects OS and installs via appropriate method
set -e

echo "🔍 Detecting operating system..."

install_stripe() {
  if command -v stripe &>/dev/null; then
    CURRENT_VERSION=$(stripe version 2>/dev/null || echo "unknown")
    echo "✅ Stripe CLI already installed: $CURRENT_VERSION"
    read -p "Reinstall/update? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
  fi

  OS="$(uname -s)"
  ARCH="$(uname -m)"

  case "$OS" in
    Linux)
      if command -v apt-get &>/dev/null; then
        echo "📦 Installing via apt (Debian/Ubuntu)..."
        # Add Stripe GPG key and repo
        if [ ! -f /etc/apt/sources.list.d/stripe.list ]; then
          curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | gpg --dearmor | sudo tee /usr/share/keyrings/stripe.gpg >/dev/null
          echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | sudo tee /etc/apt/sources.list.d/stripe.list
        fi
        sudo apt-get update -qq
        sudo apt-get install -y stripe
      elif command -v yum &>/dev/null; then
        echo "📦 Installing via yum (RHEL/CentOS)..."
        sudo rpm --import https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public
        cat <<EOF | sudo tee /etc/yum.repos.d/stripe.repo
[stripe-cli]
name=Stripe CLI
baseurl=https://packages.stripe.dev/stripe-cli-rpm-local
enabled=1
gpgcheck=1
gpgkey=https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public
EOF
        sudo yum install -y stripe
      elif command -v pacman &>/dev/null; then
        echo "📦 Installing via AUR (Arch Linux)..."
        if command -v yay &>/dev/null; then
          yay -S stripe-cli-bin
        else
          echo "⚠️ yay not found. Install manually from AUR: stripe-cli-bin"
          echo "Falling back to binary download..."
          install_binary
        fi
      else
        echo "📦 Installing from binary..."
        install_binary
      fi
      ;;
    Darwin)
      if command -v brew &>/dev/null; then
        echo "📦 Installing via Homebrew..."
        brew install stripe/stripe-cli/stripe
      else
        echo "📦 Installing from binary..."
        install_binary
      fi
      ;;
    *)
      echo "❌ Unsupported OS: $OS"
      echo "Download manually: https://stripe.com/docs/stripe-cli#install"
      exit 1
      ;;
  esac
}

install_binary() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  
  case "$ARCH" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
  esac

  LATEST=$(curl -s https://api.github.com/repos/stripe/stripe-cli/releases/latest | jq -r '.tag_name' | sed 's/^v//')
  if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    echo "❌ Failed to fetch latest version"
    exit 1
  fi

  URL="https://github.com/stripe/stripe-cli/releases/download/v${LATEST}/stripe_${LATEST}_${OS}_${ARCH}.tar.gz"
  echo "⬇️ Downloading Stripe CLI v${LATEST}..."
  
  TMP_DIR=$(mktemp -d)
  curl -sL "$URL" -o "$TMP_DIR/stripe.tar.gz"
  tar -xzf "$TMP_DIR/stripe.tar.gz" -C "$TMP_DIR"
  
  if [ -w /usr/local/bin ]; then
    mv "$TMP_DIR/stripe" /usr/local/bin/stripe
  else
    sudo mv "$TMP_DIR/stripe" /usr/local/bin/stripe
  fi
  
  rm -rf "$TMP_DIR"
  chmod +x /usr/local/bin/stripe
}

install_stripe

# Verify
if command -v stripe &>/dev/null; then
  echo ""
  echo "✅ Stripe CLI installed successfully!"
  echo "   Version: $(stripe version)"
  echo ""
  echo "Next steps:"
  echo "  1. Authenticate:  stripe login"
  echo "     Or set key:    export STRIPE_API_KEY='sk_test_...'"
  echo "  2. Test:          stripe status"
  echo "  3. Forward hooks: bash scripts/run.sh webhook-forward --url http://localhost:3000/webhooks"
else
  echo "❌ Installation failed. Please install manually:"
  echo "   https://stripe.com/docs/stripe-cli#install"
  exit 1
fi
