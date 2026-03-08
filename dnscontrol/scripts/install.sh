#!/bin/bash
# Install DNSControl — DNS as Code tool by Stack Overflow
set -euo pipefail

VERSION="${DNSCONTROL_VERSION:-4.14.0}"
INSTALL_DIR="${DNSCONTROL_INSTALL_DIR:-/usr/local/bin}"

echo "📦 Installing DNSControl v${VERSION}..."

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l|armhf)  ARCH="arm"   ;;
    *)
        echo "❌ Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

case "$OS" in
    linux)  OS="linux"  ;;
    darwin) OS="darwin" ;;
    *)
        echo "❌ Unsupported OS: $OS"
        exit 1
        ;;
esac

# Check if already installed and at correct version
if command -v dnscontrol &>/dev/null; then
    CURRENT=$(dnscontrol version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
    if [ "$CURRENT" = "$VERSION" ]; then
        echo "✅ DNSControl v${VERSION} already installed"
        exit 0
    fi
    echo "🔄 Upgrading from v${CURRENT} to v${VERSION}..."
fi

# Download binary
DOWNLOAD_URL="https://github.com/StackExchange/dnscontrol/releases/download/v${VERSION}/dnscontrol_${VERSION}_${OS}_${ARCH}.tar.gz"
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "⬇️  Downloading from: ${DOWNLOAD_URL}"
curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/dnscontrol.tar.gz"

# Extract
echo "📂 Extracting..."
tar -xzf "${TMP_DIR}/dnscontrol.tar.gz" -C "${TMP_DIR}"

# Install
if [ -w "$INSTALL_DIR" ]; then
    cp "${TMP_DIR}/dnscontrol" "${INSTALL_DIR}/dnscontrol"
    chmod +x "${INSTALL_DIR}/dnscontrol"
else
    echo "🔐 Need sudo to install to ${INSTALL_DIR}"
    sudo cp "${TMP_DIR}/dnscontrol" "${INSTALL_DIR}/dnscontrol"
    sudo chmod +x "${INSTALL_DIR}/dnscontrol"
fi

# Verify
echo ""
echo "✅ DNSControl installed successfully!"
dnscontrol version
echo ""
echo "Next steps:"
echo "  1. Run: bash scripts/init.sh --provider cloudflare --domain yourdomain.com"
echo "  2. Edit dnsconfig.js with your records"
echo "  3. Run: dnscontrol preview"
echo "  4. Run: dnscontrol push"
