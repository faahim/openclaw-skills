#!/bin/bash
# Install restic backup tool
set -e

echo "🔧 Installing restic..."

# Detect OS and install
if command -v restic &>/dev/null; then
  CURRENT=$(restic version 2>/dev/null | awk '{print $2}')
  echo "✅ restic already installed (version $CURRENT)"
  echo "   Updating to latest..."
  sudo restic self-update 2>/dev/null || true
  exit 0
fi

if [[ "$(uname)" == "Darwin" ]]; then
  if command -v brew &>/dev/null; then
    brew install restic
  else
    echo "❌ Homebrew not found. Install from: https://github.com/restic/restic/releases"
    exit 1
  fi
elif [[ -f /etc/debian_version ]]; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq restic
  # Debian/Ubuntu repos often have old versions — self-update
  sudo restic self-update 2>/dev/null || true
elif [[ -f /etc/redhat-release ]]; then
  sudo dnf install -y restic 2>/dev/null || sudo yum install -y restic
elif [[ -f /etc/arch-release ]]; then
  sudo pacman -S --noconfirm restic
elif [[ -f /etc/alpine-release ]]; then
  sudo apk add restic
else
  # Fallback: download binary from GitHub
  echo "📦 Downloading restic binary from GitHub..."
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
  esac
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  LATEST=$(curl -sL https://api.github.com/repos/restic/restic/releases/latest | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
  VERSION="${LATEST#v}"
  URL="https://github.com/restic/restic/releases/download/${LATEST}/restic_${VERSION}_${OS}_${ARCH}.bz2"
  curl -sL "$URL" | bunzip2 > /tmp/restic
  chmod +x /tmp/restic
  sudo mv /tmp/restic /usr/local/bin/restic
fi

# Verify
if command -v restic &>/dev/null; then
  echo "✅ restic $(restic version | awk '{print $2}') installed successfully"
else
  echo "❌ Installation failed"
  exit 1
fi
