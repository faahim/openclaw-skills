#!/bin/bash
# Install rclone on Linux/macOS
set -euo pipefail

echo "🔧 Installing rclone..."

# Check if already installed
if command -v rclone &>/dev/null; then
  CURRENT=$(rclone version --check 2>/dev/null | head -1 || rclone version | head -1)
  echo "✅ rclone already installed: $CURRENT"
  echo "   To update: rclone selfupdate (or re-run this script with --force)"
  if [[ "${1:-}" != "--force" ]]; then
    exit 0
  fi
  echo "   --force flag detected, reinstalling..."
fi

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="arm-v7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux|darwin)
    echo "📦 Detected: $OS/$ARCH"
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    echo "   Visit https://rclone.org/downloads/ for manual install"
    exit 1
    ;;
esac

# Install via official script (handles sudo internally)
if command -v curl &>/dev/null; then
  curl -fsSL https://rclone.org/install.sh | sudo bash
elif command -v wget &>/dev/null; then
  wget -qO- https://rclone.org/install.sh | sudo bash
else
  echo "❌ Neither curl nor wget found. Install one first."
  exit 1
fi

# Verify
if command -v rclone &>/dev/null; then
  echo ""
  echo "✅ rclone installed successfully!"
  rclone version | head -1
  echo ""
  echo "Next steps:"
  echo "  1. Configure a remote:  bash scripts/manage-remote.sh add <name> <type>"
  echo "  2. Or interactive:      rclone config"
  echo "  3. Start syncing:       bash scripts/sync.sh /local/path remote:path"
else
  echo "❌ Installation failed. Try manual install: https://rclone.org/install.sh"
  exit 1
fi

# Install optional dependencies
echo ""
echo "📦 Checking optional dependencies..."

if ! command -v jq &>/dev/null; then
  echo "   jq (for usage reports): not installed"
  if command -v apt-get &>/dev/null; then
    echo "   Install with: sudo apt-get install -y jq"
  elif command -v brew &>/dev/null; then
    echo "   Install with: brew install jq"
  fi
else
  echo "   ✅ jq installed"
fi

if ! command -v fusermount3 &>/dev/null && ! command -v fusermount &>/dev/null; then
  echo "   fuse3 (for mounting): not installed"
  if command -v apt-get &>/dev/null; then
    echo "   Install with: sudo apt-get install -y fuse3"
  fi
else
  echo "   ✅ FUSE installed"
fi
