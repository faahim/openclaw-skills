#!/bin/bash
# Install Pagefind binary — client-side static site search indexer
set -euo pipefail

VERSION="${PAGEFIND_VERSION:-1.3.0}"
INSTALL_DIR="${PAGEFIND_INSTALL_DIR:-$HOME/.local/bin}"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
  linux)  PLATFORM="unknown-linux-musl" ;;
  darwin) PLATFORM="apple-darwin" ;;
  *)      echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
  x86_64|amd64)   ARCH_TAG="x86_64" ;;
  aarch64|arm64)   ARCH_TAG="aarch64" ;;
  *)               echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

FILENAME="pagefind-v${VERSION}-${ARCH_TAG}-${PLATFORM}.tar.gz"
URL="https://github.com/CloudCannon/pagefind/releases/download/v${VERSION}/${FILENAME}"

echo "📦 Installing Pagefind v${VERSION} for ${ARCH_TAG}-${PLATFORM}..."

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download and extract
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "⬇️  Downloading from $URL..."
if ! curl -fsSL "$URL" -o "$TMPDIR/$FILENAME"; then
  echo "❌ Download failed. Check version ($VERSION) and platform ($ARCH_TAG-$PLATFORM)."
  echo "   Available releases: https://github.com/CloudCannon/pagefind/releases"
  exit 1
fi

echo "📂 Extracting..."
tar xzf "$TMPDIR/$FILENAME" -C "$TMPDIR"

# Find the binary (could be pagefind or pagefind_extended)
BINARY=""
for name in pagefind pagefind_extended; do
  if [ -f "$TMPDIR/$name" ]; then
    BINARY="$TMPDIR/$name"
    break
  fi
done

if [ -z "$BINARY" ]; then
  echo "❌ Binary not found in archive. Contents:"
  ls -la "$TMPDIR/"
  exit 1
fi

# Install
cp "$BINARY" "$INSTALL_DIR/pagefind"
chmod +x "$INSTALL_DIR/pagefind"

echo "✅ Pagefind v${VERSION} installed to $INSTALL_DIR/pagefind"

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "^${INSTALL_DIR}$"; then
  echo ""
  echo "⚠️  $INSTALL_DIR is not in your PATH. Add it:"
  echo "   echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
fi

# Verify
"$INSTALL_DIR/pagefind" --version 2>/dev/null && echo "🎉 Ready to use!" || echo "⚠️  Binary downloaded but version check failed"
