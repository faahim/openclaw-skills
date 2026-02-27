#!/bin/bash
# Install Typst binary — auto-detects OS and architecture
set -euo pipefail

INSTALL_DIR="${TYPST_INSTALL_DIR:-$HOME/.local/bin}"

echo "🔧 Installing Typst..."

# Detect OS
OS="$(uname -s)"
case "$OS" in
  Linux)  OS_NAME="unknown-linux-musl" ;;
  Darwin) OS_NAME="apple-darwin" ;;
  *)      echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)  ARCH_NAME="x86_64" ;;
  aarch64|arm64)  ARCH_NAME="aarch64" ;;
  armv7l)         ARCH_NAME="armv7" ;;
  *)              echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest version
echo "📡 Fetching latest version..."
LATEST=$(curl -sL "https://api.github.com/repos/typst/typst/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"v\(.*\)".*/\1/')
if [ -z "$LATEST" ]; then
  echo "⚠️ Could not detect latest version, using v0.13.0"
  LATEST="0.13.0"
fi
echo "   Version: v${LATEST}"

# Build download URL
TARBALL="typst-${ARCH_NAME}-${OS_NAME}.tar.xz"
URL="https://github.com/typst/typst/releases/download/v${LATEST}/${TARBALL}"

# Download
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "⬇️  Downloading from ${URL}..."
curl -sL "$URL" -o "$TMPDIR/$TARBALL"

# Extract
echo "📦 Extracting..."
cd "$TMPDIR"
tar xf "$TARBALL"

# Install
mkdir -p "$INSTALL_DIR"
EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "typst-*" | head -1)
if [ -z "$EXTRACTED_DIR" ]; then
  echo "❌ Extraction failed — could not find typst directory"
  exit 1
fi

cp "$EXTRACTED_DIR/typst" "$INSTALL_DIR/typst"
chmod +x "$INSTALL_DIR/typst"

# Verify
if "$INSTALL_DIR/typst" --version >/dev/null 2>&1; then
  VERSION=$("$INSTALL_DIR/typst" --version)
  echo "✅ Installed: $VERSION"
  echo "   Location: $INSTALL_DIR/typst"
else
  echo "❌ Installation verification failed"
  exit 1
fi

# Check PATH
if ! command -v typst >/dev/null 2>&1; then
  echo ""
  echo "⚠️  typst is not in your PATH. Add this to your shell profile:"
  echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo ""
echo "🎉 Typst is ready! Try: typst compile document.typ"
