#!/bin/bash
# Install cloudflared on Linux/macOS
set -e

echo "🔍 Detecting platform..."

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Normalize architecture
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l|armhf)  ARCH="arm" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Check if already installed
if command -v cloudflared &>/dev/null; then
  CURRENT=$(cloudflared --version 2>&1 | head -1)
  echo "✅ cloudflared already installed: $CURRENT"
  read -p "Reinstall/update? (y/N): " CONFIRM
  [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && exit 0
fi

echo "📦 Installing cloudflared ($OS/$ARCH)..."

case "$OS" in
  linux)
    # Try package manager first
    if command -v apt-get &>/dev/null; then
      echo "Using apt..."
      # Add Cloudflare GPG key and repo
      sudo mkdir -p --mode=0755 /usr/share/keyrings
      curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
      echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs 2>/dev/null || echo 'jammy') main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
      sudo apt-get update -qq
      sudo apt-get install -y cloudflared
    elif command -v yum &>/dev/null; then
      echo "Using yum..."
      sudo rpm -ivh "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.rpm"
    else
      echo "Using direct binary..."
      DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"
      sudo curl -fsSL -o /usr/local/bin/cloudflared "$DOWNLOAD_URL"
      sudo chmod +x /usr/local/bin/cloudflared
    fi
    ;;
  darwin)
    if command -v brew &>/dev/null; then
      brew install cloudflared
    else
      DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-${ARCH}.tgz"
      curl -fsSL "$DOWNLOAD_URL" | tar xz -C /usr/local/bin
      chmod +x /usr/local/bin/cloudflared
    fi
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    exit 1
    ;;
esac

# Verify
if command -v cloudflared &>/dev/null; then
  VERSION=$(cloudflared --version 2>&1 | head -1)
  echo "✅ cloudflared installed successfully: $VERSION"
else
  echo "❌ Installation failed. Please install manually: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
  exit 1
fi

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "⚠️  jq not found. Installing..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y jq
  elif command -v brew &>/dev/null; then
    brew install jq
  elif command -v yum &>/dev/null; then
    sudo yum install -y jq
  else
    echo "❌ Please install jq manually"
  fi
fi

echo ""
echo "🎉 Setup complete! Next steps:"
echo "  1. Run: bash scripts/run.sh auth"
echo "  2. Run: bash scripts/run.sh create <tunnel-name>"
echo "  3. Run: bash scripts/run.sh route <tunnel-name> <hostname>"
echo "  4. Run: bash scripts/run.sh start <tunnel-name> --url http://localhost:PORT"
