#!/bin/bash
# Install rclone and verify
set -e

echo "🔧 Cloud Sync & Backup — Installer"
echo "===================================="

# Check if rclone already installed
if command -v rclone &>/dev/null; then
  CURRENT_VERSION=$(rclone version --check 2>/dev/null | head -1 || rclone --version | head -1)
  echo "✅ rclone already installed: $CURRENT_VERSION"
  echo ""
  echo "To update: rclone selfupdate"
  exit 0
fi

echo "📦 Installing rclone..."

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l)  ARCH="arm-v7" ;;
  *)       echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

if [[ "$OS" == "linux" ]]; then
  # Try package manager first
  if command -v apt-get &>/dev/null; then
    echo "Using apt..."
    sudo apt-get update -qq && sudo apt-get install -y -qq rclone
  elif command -v dnf &>/dev/null; then
    echo "Using dnf..."
    sudo dnf install -y rclone
  elif command -v pacman &>/dev/null; then
    echo "Using pacman..."
    sudo pacman -S --noconfirm rclone
  else
    # Fallback: official install script
    echo "Using official installer..."
    curl -fsSL https://rclone.org/install.sh | sudo bash
  fi
elif [[ "$OS" == "darwin" ]]; then
  if command -v brew &>/dev/null; then
    brew install rclone
  else
    curl -fsSL https://rclone.org/install.sh | sudo bash
  fi
else
  echo "❌ Unsupported OS: $OS"
  exit 1
fi

# Verify
if command -v rclone &>/dev/null; then
  echo ""
  echo "✅ rclone installed successfully!"
  rclone --version | head -1
else
  echo "❌ Installation failed. Try: curl https://rclone.org/install.sh | sudo bash"
  exit 1
fi

# Check for gpg (encryption)
if command -v gpg &>/dev/null; then
  echo "✅ gpg available (encryption supported)"
else
  echo "⚠️  gpg not found — encryption won't work. Install: sudo apt-get install gnupg"
fi

# Check for tar/gzip (compression)
if command -v tar &>/dev/null && command -v gzip &>/dev/null; then
  echo "✅ tar/gzip available (compression supported)"
else
  echo "⚠️  tar/gzip not found — compression won't work"
fi

echo ""
echo "🎉 Ready! Next: run 'bash scripts/setup-remote.sh' to configure a cloud provider"
