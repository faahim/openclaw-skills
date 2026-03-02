#!/bin/bash
# Zola installer — downloads and installs Zola binary
set -euo pipefail

VERSION=""
UPDATE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --update) UPDATE=true; shift ;;
    -h|--help) echo "Usage: install.sh [--version X.Y.Z] [--update]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

INSTALL_DIR="${ZOLA_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$INSTALL_DIR"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
  linux) OS_TAG="unknown-linux-gnu" ;;
  darwin) OS_TAG="apple-darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
  x86_64|amd64) ARCH_TAG="x86_64" ;;
  aarch64|arm64) ARCH_TAG="aarch64" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest version if not specified
if [[ -z "$VERSION" ]]; then
  echo "🔍 Fetching latest Zola version..."
  VERSION=$(curl -sL "https://api.github.com/repos/getzola/zola/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
  if [[ -z "$VERSION" ]]; then
    echo "❌ Failed to fetch latest version. Try: install.sh --version 0.19.2"
    exit 1
  fi
fi

# Check if already installed
if command -v zola &>/dev/null; then
  CURRENT=$(zola --version 2>/dev/null | awk '{print $2}')
  if [[ "$CURRENT" == "$VERSION" ]] && [[ "$UPDATE" == false ]]; then
    echo "✅ Zola v${VERSION} already installed at $(which zola)"
    exit 0
  fi
  echo "📦 Updating Zola from v${CURRENT} to v${VERSION}..."
else
  echo "📦 Installing Zola v${VERSION}..."
fi

# Download
TARBALL="zola-v${VERSION}-${ARCH_TAG}-${OS_TAG}.tar.gz"
DOWNLOAD_URL="https://github.com/getzola/zola/releases/download/v${VERSION}/${TARBALL}"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "⬇️  Downloading ${TARBALL}..."
if ! curl -sL --fail -o "$TMPDIR/$TARBALL" "$DOWNLOAD_URL"; then
  echo "❌ Download failed. Check version and platform."
  echo "   URL: $DOWNLOAD_URL"
  exit 1
fi

# Extract
echo "📂 Extracting..."
tar -xzf "$TMPDIR/$TARBALL" -C "$TMPDIR"

# Install
cp "$TMPDIR/zola" "$INSTALL_DIR/zola"
chmod +x "$INSTALL_DIR/zola"

# Verify
if "$INSTALL_DIR/zola" --version &>/dev/null; then
  echo "✅ Zola v${VERSION} installed to ${INSTALL_DIR}/zola"
else
  echo "❌ Installation failed — binary not executable"
  exit 1
fi

# Check PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "⚠️  ${INSTALL_DIR} is not in your PATH. Add it:"
  echo "   export PATH=\"${INSTALL_DIR}:\$PATH\""
  echo "   echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.bashrc"
fi
