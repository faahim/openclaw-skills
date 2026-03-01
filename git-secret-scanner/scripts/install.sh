#!/bin/bash
# Git Secret Scanner — Gitleaks Installer
# Installs gitleaks binary for the current platform

set -euo pipefail

INSTALL_DIR="${GITLEAKS_INSTALL_DIR:-/usr/local/bin}"
VERSION="${GITLEAKS_VERSION:-8.21.2}"

# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) PLATFORM="linux" ;;
  darwin) PLATFORM="darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Map arch for gitleaks release naming
case "$ARCH" in
  x64) RELEASE_ARCH="x64" ;;
  arm64) RELEASE_ARCH="arm64" ;;
  armv7) RELEASE_ARCH="armv7" ;;
esac

# Check if already installed
if command -v gitleaks &>/dev/null; then
  CURRENT_VERSION=$(gitleaks version 2>/dev/null || echo "unknown")
  echo "ℹ️  Gitleaks already installed: $CURRENT_VERSION"
  read -r -p "Reinstall v${VERSION}? [y/N] " response
  if [[ ! "$response" =~ ^[yY]$ ]]; then
    echo "Keeping current installation."
    exit 0
  fi
fi

# Download and install
TARBALL="gitleaks_${VERSION}_${PLATFORM}_${RELEASE_ARCH}.tar.gz"
URL="https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/${TARBALL}"

echo "📦 Downloading gitleaks v${VERSION} for ${PLATFORM}/${RELEASE_ARCH}..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if ! curl -sSfL "$URL" -o "$TMPDIR/$TARBALL"; then
  echo "❌ Download failed. Check version and platform."
  echo "   URL: $URL"
  exit 1
fi

echo "📂 Extracting..."
tar xzf "$TMPDIR/$TARBALL" -C "$TMPDIR"

# Install binary
if [ -w "$INSTALL_DIR" ]; then
  cp "$TMPDIR/gitleaks" "$INSTALL_DIR/gitleaks"
  chmod +x "$INSTALL_DIR/gitleaks"
else
  echo "🔐 Need sudo to install to $INSTALL_DIR"
  sudo cp "$TMPDIR/gitleaks" "$INSTALL_DIR/gitleaks"
  sudo chmod +x "$INSTALL_DIR/gitleaks"
fi

# Verify
if command -v gitleaks &>/dev/null; then
  echo "✅ Gitleaks v${VERSION} installed successfully!"
  echo "   Location: $(which gitleaks)"
  gitleaks version
else
  echo "⚠️  Installed to $INSTALL_DIR but not in PATH."
  echo "   Add to PATH: export PATH=\"$INSTALL_DIR:\$PATH\""
fi
