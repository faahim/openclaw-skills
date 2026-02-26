#!/bin/bash
# Install nektos/act for running GitHub Actions locally
set -euo pipefail

INSTALL_DIR="${ACT_INSTALL_DIR:-$HOME/.local/bin}"
REPO="nektos/act"

echo "🚀 Installing act (GitHub Actions local runner)..."

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "❌ Docker is required but not installed."
  echo ""
  echo "Install Docker:"
  echo "  Ubuntu/Debian: curl -fsSL https://get.docker.com | sh"
  echo "  macOS: brew install --cask docker"
  echo "  Other: https://docs.docker.com/engine/install/"
  exit 1
fi

# Check if Docker daemon is running
if ! docker info &>/dev/null 2>&1; then
  echo "⚠️  Docker is installed but not running."
  echo "  Start it with: sudo systemctl start docker"
  echo "  Or launch Docker Desktop."
  exit 1
fi

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) PLATFORM="Linux" ;;
  darwin) PLATFORM="Darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Check if already installed
if command -v act &>/dev/null; then
  CURRENT=$(act --version 2>/dev/null | grep -oP '[\d.]+' || echo "unknown")
  echo "ℹ️  act is already installed (version $CURRENT)"
  read -p "Reinstall/upgrade? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Keeping current installation."
    exit 0
  fi
fi

# Get latest release version
echo "📦 Fetching latest release..."
LATEST=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST" ]; then
  echo "❌ Could not determine latest version. Check your network."
  exit 1
fi

echo "📥 Downloading act v${LATEST} for ${PLATFORM}_${ARCH}..."

# Download
TARBALL="act_${PLATFORM}_${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/$REPO/releases/download/v${LATEST}/${TARBALL}"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

curl -sL "$DOWNLOAD_URL" -o "$TMPDIR/$TARBALL"

if [ ! -s "$TMPDIR/$TARBALL" ]; then
  echo "❌ Download failed. URL: $DOWNLOAD_URL"
  exit 1
fi

# Extract
tar xzf "$TMPDIR/$TARBALL" -C "$TMPDIR"

# Install
mkdir -p "$INSTALL_DIR"
mv "$TMPDIR/act" "$INSTALL_DIR/act"
chmod +x "$INSTALL_DIR/act"

# Verify
if "$INSTALL_DIR/act" --version &>/dev/null; then
  echo "✅ act v${LATEST} installed to $INSTALL_DIR/act"
else
  echo "❌ Installation verification failed."
  exit 1
fi

# Check PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "⚠️  $INSTALL_DIR is not in your PATH."
  echo "Add it:"
  echo "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc"
  echo "  source ~/.bashrc"
fi

# Setup default config
if [ ! -f "$HOME/.actrc" ]; then
  cat > "$HOME/.actrc" << 'EOF'
-P ubuntu-latest=catthehacker/ubuntu:act-latest
-P ubuntu-22.04=catthehacker/ubuntu:act-22.04
-P ubuntu-20.04=catthehacker/ubuntu:act-20.04
EOF
  echo "📝 Created default config at ~/.actrc"
fi

# Pre-pull default image
echo ""
echo "📦 Pre-pulling default runner image (this may take a minute)..."
docker pull catthehacker/ubuntu:act-latest 2>/dev/null && \
  echo "✅ Default image ready." || \
  echo "⚠️  Could not pre-pull image. It will be downloaded on first run."

echo ""
echo "🎉 Setup complete! Try:"
echo "  cd your-repo && act -l"
