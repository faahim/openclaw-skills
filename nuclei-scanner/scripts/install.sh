#!/bin/bash
# Install Nuclei vulnerability scanner
# Supports Linux (amd64/arm64) and macOS (amd64/arm64)
set -euo pipefail

INSTALL_DIR="${NUCLEI_INSTALL_DIR:-$HOME/.local/bin}"
TEMPLATES_DIR="${NUCLEI_TEMPLATES_DIR:-$HOME/nuclei-templates}"

echo "🔍 Nuclei Vulnerability Scanner — Installer"
echo "============================================"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) PLATFORM="linux" ;;
  darwin) PLATFORM="darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

echo "📋 Platform: ${PLATFORM}_${ARCH}"

# Check if nuclei is already installed
if command -v nuclei &>/dev/null; then
  CURRENT_VERSION=$(nuclei -version 2>&1 | grep -oP 'v[\d.]+' | head -1 || echo "unknown")
  echo "ℹ️  Nuclei already installed: $CURRENT_VERSION"
  read -p "   Reinstall/update? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "✅ Keeping current installation."
    exit 0
  fi
fi

# Get latest release URL from GitHub
echo "📡 Fetching latest release..."
LATEST_URL=$(curl -sL "https://api.github.com/repos/projectdiscovery/nuclei/releases/latest" \
  | grep -oP '"browser_download_url":\s*"\K[^"]*'"${PLATFORM}_${ARCH}"'\.zip[^"]*' \
  | head -1)

if [ -z "$LATEST_URL" ]; then
  echo "❌ Could not find download URL for ${PLATFORM}_${ARCH}"
  echo "   Try manual install: https://github.com/projectdiscovery/nuclei/releases"
  exit 1
fi

VERSION=$(echo "$LATEST_URL" | grep -oP 'v[\d.]+' | head -1)
echo "📦 Downloading Nuclei $VERSION..."

# Download and extract
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

curl -sL "$LATEST_URL" -o "$TMPDIR/nuclei.zip"
unzip -q "$TMPDIR/nuclei.zip" -d "$TMPDIR/"

# Install binary
mkdir -p "$INSTALL_DIR"
mv "$TMPDIR/nuclei" "$INSTALL_DIR/nuclei"
chmod +x "$INSTALL_DIR/nuclei"

echo "✅ Nuclei $VERSION installed to $INSTALL_DIR/nuclei"

# Ensure PATH includes install dir
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "⚠️  $INSTALL_DIR is not in your PATH."
  echo "   Add to your shell profile:"
  echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
  echo ""
  # Add to common profiles
  for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ] && ! grep -q "$INSTALL_DIR" "$RC"; then
      echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$RC"
      echo "   ✅ Added to $RC"
    fi
  done
  export PATH="$INSTALL_DIR:$PATH"
fi

# Download/update templates
echo ""
echo "📚 Downloading vulnerability templates..."
"$INSTALL_DIR/nuclei" -update-templates -silent 2>/dev/null || true

TEMPLATE_COUNT=$(find "$TEMPLATES_DIR" -name "*.yaml" 2>/dev/null | wc -l)
echo "✅ $TEMPLATE_COUNT templates ready"

# Verify installation
echo ""
echo "🎉 Installation complete!"
echo ""
"$INSTALL_DIR/nuclei" -version 2>&1 || true
echo ""
echo "Quick start:"
echo "  nuclei -u https://example.com                    # Basic scan"
echo "  nuclei -u https://example.com -s critical,high   # Critical only"
echo "  nuclei -u https://example.com -o results.txt     # Save results"
echo ""
echo "⚠️  Only scan targets you own or have permission to test."
