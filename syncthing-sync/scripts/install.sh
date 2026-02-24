#!/bin/bash
# Install Syncthing on Linux or macOS
set -e

echo "🔄 Installing Syncthing..."

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  elif [[ "$(uname)" == "Darwin" ]]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

OS=$(detect_os)
echo "Detected OS: $OS"

case "$OS" in
  ubuntu|debian|pop|linuxmint)
    echo "Installing via APT (official Syncthing repo)..."
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL -o /etc/apt/keyrings/syncthing-archive-keyring.gpg \
      https://syncthing.net/release-key.gpg
    echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" \
      | sudo tee /etc/apt/sources.list.d/syncthing.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y syncthing
    ;;
  fedora|rhel|centos|rocky|alma)
    echo "Installing via DNF..."
    sudo dnf install -y syncthing
    ;;
  arch|manjaro|endeavouros)
    echo "Installing via pacman..."
    sudo pacman -Sy --noconfirm syncthing
    ;;
  macos)
    if command -v brew &>/dev/null; then
      echo "Installing via Homebrew..."
      brew install syncthing
    else
      echo "❌ Homebrew not found. Install from https://syncthing.net/downloads/"
      exit 1
    fi
    ;;
  *)
    echo "⚠️ Unknown OS. Attempting binary download..."
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64) ST_ARCH="amd64" ;;
      aarch64|arm64) ST_ARCH="arm64" ;;
      armv7*) ST_ARCH="arm" ;;
      *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    LATEST=$(curl -fsSL https://api.github.com/repos/syncthing/syncthing/releases/latest | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
    VERSION="${LATEST#v}"
    URL="https://github.com/syncthing/syncthing/releases/download/${LATEST}/syncthing-linux-${ST_ARCH}-v${VERSION}.tar.gz"
    
    echo "Downloading Syncthing $VERSION for $ST_ARCH..."
    TMP=$(mktemp -d)
    curl -fsSL "$URL" | tar xz -C "$TMP"
    sudo cp "$TMP"/syncthing-linux-*/syncthing /usr/local/bin/
    rm -rf "$TMP"
    ;;
esac

# Verify
if command -v syncthing &>/dev/null; then
  echo "✅ Syncthing installed: $(syncthing --version 2>/dev/null | head -1)"
else
  echo "❌ Installation failed. Check logs above."
  exit 1
fi

# Generate initial config if not present
CONFIG_DIR="${HOME}/.local/state/syncthing"
if [[ ! -f "$CONFIG_DIR/config.xml" ]]; then
  ALT_DIR="${HOME}/.config/syncthing"
  if [[ ! -f "$ALT_DIR/config.xml" ]]; then
    echo "Generating initial config..."
    syncthing generate --skip-port-probing 2>/dev/null || true
    echo "✅ Initial config created"
  fi
fi

echo ""
echo "🎉 Syncthing is ready!"
echo "   Start: bash scripts/run.sh start"
echo "   Web UI: http://127.0.0.1:8384"
