#!/bin/bash
# Install mkcert and set up local CA
set -euo pipefail

echo "🔐 mkcert Local SSL — Installer"
echo "================================"

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

install_mkcert() {
  if command -v mkcert &>/dev/null; then
    echo "✅ mkcert already installed: $(mkcert --version 2>&1 || echo 'unknown version')"
    return 0
  fi

  echo "📦 Installing mkcert..."

  case "$OS" in
    Linux)
      # Try package managers first
      if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq libnss3-tools 2>/dev/null || true
      elif command -v dnf &>/dev/null; then
        sudo dnf install -y nss-tools 2>/dev/null || true
      elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm nss 2>/dev/null || true
      fi

      # Install mkcert binary
      if command -v brew &>/dev/null; then
        brew install mkcert
      else
        # Direct binary download
        case "$ARCH" in
          x86_64|amd64) MKCERT_ARCH="amd64" ;;
          aarch64|arm64) MKCERT_ARCH="arm64" ;;
          armv7*|armhf) MKCERT_ARCH="arm" ;;
          *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
        esac

        MKCERT_URL="https://dl.filippo.io/mkcert/latest?for=linux/$MKCERT_ARCH"
        MKCERT_BIN="/usr/local/bin/mkcert"

        echo "  Downloading from $MKCERT_URL"
        sudo curl -sL "$MKCERT_URL" -o "$MKCERT_BIN"
        sudo chmod +x "$MKCERT_BIN"
      fi
      ;;

    Darwin)
      if command -v brew &>/dev/null; then
        brew install mkcert
        brew install nss  # for Firefox
      else
        echo "❌ Please install Homebrew first: https://brew.sh"
        exit 1
      fi
      ;;

    *)
      echo "❌ Unsupported OS: $OS"
      echo "   Install mkcert manually: https://github.com/nicerloop/mkcert#installation"
      exit 1
      ;;
  esac

  if command -v mkcert &>/dev/null; then
    echo "✅ mkcert installed: $(mkcert --version 2>&1 || echo 'ok')"
  else
    echo "❌ mkcert installation failed"
    exit 1
  fi
}

setup_ca() {
  echo ""
  echo "🏛️  Setting up local Certificate Authority..."
  mkcert -install
  echo "✅ Local CA installed and trusted by your system"

  # Show CA location
  CAROOT="$(mkcert -CAROOT)"
  echo "   CA root: $CAROOT"
}

# Create cert storage directory
setup_storage() {
  CERT_DIR="${MKCERT_SSL_DIR:-$HOME/.local/share/mkcert-ssl}"
  mkdir -p "$CERT_DIR"
  echo ""
  echo "📁 Certificate storage: $CERT_DIR"
}

# Run
install_mkcert
setup_ca
setup_storage

echo ""
echo "🎉 Setup complete! Generate your first cert:"
echo "   bash scripts/run.sh --domains \"localhost,myapp.local\""
