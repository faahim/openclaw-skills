#!/bin/bash
# Hugo Site Manager — Install Hugo Extended
set -euo pipefail

HUGO_VERSION="${HUGO_VERSION:-0.147.4}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

echo "🔧 Installing Hugo Extended v${HUGO_VERSION}..."

# Detect OS and arch
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="arm" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) OS="linux" ;;
  darwin) OS="darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Check if already installed
if command -v hugo &>/dev/null; then
  CURRENT=$(hugo version 2>/dev/null | grep -oP 'v\K[0-9.]+' | head -1 || echo "unknown")
  echo "ℹ️  Hugo already installed (v${CURRENT})"
  if [[ "$CURRENT" == "$HUGO_VERSION" ]]; then
    echo "✅ Already at target version. Nothing to do."
    exit 0
  fi
  echo "⬆️  Upgrading from v${CURRENT} to v${HUGO_VERSION}..."
fi

# Download
FILENAME="hugo_extended_${HUGO_VERSION}_${OS}-${ARCH}.tar.gz"
URL="https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/${FILENAME}"
TMP_DIR=$(mktemp -d)

echo "📥 Downloading from ${URL}..."
curl -fsSL "$URL" -o "${TMP_DIR}/${FILENAME}"

# Extract
echo "📦 Extracting..."
tar -xzf "${TMP_DIR}/${FILENAME}" -C "${TMP_DIR}"

# Install
if [[ -w "$INSTALL_DIR" ]]; then
  mv "${TMP_DIR}/hugo" "${INSTALL_DIR}/hugo"
else
  echo "🔑 Need sudo to install to ${INSTALL_DIR}"
  sudo mv "${TMP_DIR}/hugo" "${INSTALL_DIR}/hugo"
fi

chmod +x "${INSTALL_DIR}/hugo"

# Cleanup
rm -rf "$TMP_DIR"

# Verify
INSTALLED=$(hugo version 2>/dev/null | head -1)
echo "✅ Hugo installed: ${INSTALLED}"
echo "📍 Location: $(which hugo)"
