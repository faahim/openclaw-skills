#!/bin/bash
# Install Syft — SBOM generator from Anchore
set -euo pipefail

INSTALL_DIR="${SYFT_INSTALL_DIR:-/usr/local/bin}"

echo "🔍 Checking for existing Syft installation..."
if command -v syft &>/dev/null; then
  CURRENT_VERSION=$(syft version 2>/dev/null | grep -oP 'Version:\s+\K\S+' || syft version 2>/dev/null | head -1)
  echo "✅ Syft already installed: $CURRENT_VERSION"
  read -p "Reinstall/update? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Keeping current installation."
    exit 0
  fi
fi

echo "📦 Installing Syft to $INSTALL_DIR..."

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l)  ARCH="armv7" ;;
  *)
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Use Anchore's official install script
if curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b "$INSTALL_DIR" 2>/dev/null; then
  echo "✅ Syft installed successfully!"
  syft version 2>/dev/null || echo "(version check skipped)"
else
  echo "⚠️  Official installer failed. Trying GitHub release..."
  
  # Fallback: download from GitHub releases
  LATEST=$(curl -sSL https://api.github.com/repos/anchore/syft/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+')
  VERSION="${LATEST#v}"
  
  FILENAME="syft_${VERSION}_${OS}_${ARCH}.tar.gz"
  URL="https://github.com/anchore/syft/releases/download/${LATEST}/${FILENAME}"
  
  echo "Downloading $URL..."
  TMPDIR=$(mktemp -d)
  curl -sSL "$URL" -o "$TMPDIR/$FILENAME"
  tar -xzf "$TMPDIR/$FILENAME" -C "$TMPDIR"
  
  if [ -w "$INSTALL_DIR" ]; then
    mv "$TMPDIR/syft" "$INSTALL_DIR/syft"
  else
    sudo mv "$TMPDIR/syft" "$INSTALL_DIR/syft"
  fi
  
  chmod +x "$INSTALL_DIR/syft"
  rm -rf "$TMPDIR"
  
  echo "✅ Syft $VERSION installed to $INSTALL_DIR/syft"
fi

# Optionally install Grype for vulnerability scanning
echo ""
read -p "Also install Grype (vulnerability scanner)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "📦 Installing Grype..."
  if curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b "$INSTALL_DIR" 2>/dev/null; then
    echo "✅ Grype installed successfully!"
  else
    echo "⚠️  Grype installation failed. Install manually: https://github.com/anchore/grype"
  fi
fi

echo ""
echo "🎉 Setup complete! Try: syft dir:. --output table"
