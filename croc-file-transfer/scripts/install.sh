#!/bin/bash
set -euo pipefail

# Croc File Transfer — Installer
# Detects OS/arch and installs the latest croc binary

INSTALL_DIR="${CROC_INSTALL_DIR:-/usr/local/bin}"
GITHUB_REPO="schollz/croc"

echo "🐊 Installing croc file transfer tool..."

# Check if already installed
if command -v croc &>/dev/null; then
    CURRENT=$(croc --version 2>&1 | grep -oP 'v[\d.]+' || echo "unknown")
    echo "ℹ️  croc is already installed: $CURRENT"
    read -p "Reinstall/upgrade? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping current installation."
        exit 0
    fi
fi

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    linux)   OS_NAME="Linux" ;;
    darwin)  OS_NAME="macOS" ;;
    freebsd) OS_NAME="FreeBSD" ;;
    *)       echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)  ARCH_NAME="64bit" ;;
    aarch64|arm64) ARCH_NAME="ARM64" ;;
    armv7l|armhf)  ARCH_NAME="ARM" ;;
    i386|i686)     ARCH_NAME="32bit" ;;
    *)             echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest release version
echo "📡 Fetching latest release..."
LATEST=$(curl -sI "https://github.com/$GITHUB_REPO/releases/latest" | grep -i "^location:" | grep -oP 'v[\d.]+' || true)

if [ -z "$LATEST" ]; then
    # Fallback: use API
    LATEST=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name"' | grep -oP 'v[\d.]+')
fi

if [ -z "$LATEST" ]; then
    echo "❌ Could not determine latest version. Check your internet connection."
    exit 1
fi

echo "📦 Latest version: $LATEST"

# Download
FILENAME="croc_${LATEST}_${OS_NAME}-${ARCH_NAME}.tar.gz"
URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST/$FILENAME"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "⬇️  Downloading $FILENAME..."
if ! curl -fsSL "$URL" -o "$TMPDIR/croc.tar.gz"; then
    echo "❌ Download failed. URL: $URL"
    echo "   Check https://github.com/$GITHUB_REPO/releases for available builds."
    exit 1
fi

# Extract
echo "📂 Extracting..."
tar -xzf "$TMPDIR/croc.tar.gz" -C "$TMPDIR"

# Install
if [ -w "$INSTALL_DIR" ]; then
    cp "$TMPDIR/croc" "$INSTALL_DIR/croc"
    chmod +x "$INSTALL_DIR/croc"
else
    echo "🔐 Need sudo to install to $INSTALL_DIR"
    sudo cp "$TMPDIR/croc" "$INSTALL_DIR/croc"
    sudo chmod +x "$INSTALL_DIR/croc"
fi

# Verify
if command -v croc &>/dev/null; then
    echo ""
    echo "✅ croc installed successfully!"
    croc --version
    echo ""
    echo "Quick start:"
    echo "  Send:    croc send <file>"
    echo "  Receive: croc <code-phrase>"
else
    echo "❌ Installation failed. croc not found in PATH."
    echo "   Installed to: $INSTALL_DIR/croc"
    echo "   Make sure $INSTALL_DIR is in your PATH."
    exit 1
fi
