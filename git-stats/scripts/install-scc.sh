#!/bin/bash
# Install scc (Succinct Code Counter) — fast, accurate code analysis
# https://github.com/boyter/scc

set -e

if command -v scc &>/dev/null; then
  echo "✅ scc already installed: $(scc --version 2>&1 | head -1)"
  exit 0
fi

echo "📦 Installing scc..."

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7*|armhf)  ARCH="armv7" ;;
  *)
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

case "$OS" in
  linux)
    FILENAME="scc_Linux_${ARCH}.tar.gz"
    ;;
  darwin)
    FILENAME="scc_Darwin_${ARCH}.tar.gz"
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    echo "Install manually: https://github.com/boyter/scc/releases"
    exit 1
    ;;
esac

# Get latest release URL
RELEASE_URL="https://github.com/boyter/scc/releases/latest/download/${FILENAME}"

# Determine install directory
if [ -w /usr/local/bin ]; then
  INSTALL_DIR="/usr/local/bin"
elif [ -d "$HOME/.local/bin" ]; then
  INSTALL_DIR="$HOME/.local/bin"
else
  mkdir -p "$HOME/.local/bin"
  INSTALL_DIR="$HOME/.local/bin"
  echo "⚠️  Add $INSTALL_DIR to your PATH if not already there"
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "⬇️  Downloading from $RELEASE_URL"
curl -sL "$RELEASE_URL" -o "$TMPDIR/scc.tar.gz"

echo "📂 Extracting to $INSTALL_DIR"
tar xzf "$TMPDIR/scc.tar.gz" -C "$TMPDIR"
mv "$TMPDIR/scc" "$INSTALL_DIR/scc"
chmod +x "$INSTALL_DIR/scc"

echo "✅ scc installed at $INSTALL_DIR/scc"
"$INSTALL_DIR/scc" --version 2>&1 | head -1
