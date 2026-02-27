#!/bin/bash
# PocketBase Installer — Downloads and installs the PocketBase binary
set -euo pipefail

VERSION=""
INSTALL_DIR="/usr/local/bin"
DATA_BASE="/opt/pocketbase"

usage() {
  echo "Usage: $0 [--version VERSION] [--dir INSTALL_DIR]"
  echo "  --version  Specific PocketBase version (default: latest)"
  echo "  --dir      Installation directory (default: /usr/local/bin)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) OS="linux" ;;
  darwin) OS="darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Get latest version if not specified
if [[ -z "$VERSION" ]]; then
  echo "🔍 Fetching latest PocketBase version..."
  VERSION=$(curl -s https://api.github.com/repos/pocketbase/pocketbase/releases/latest | jq -r '.tag_name' | sed 's/^v//')
  if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
    echo "❌ Failed to fetch latest version. Specify with --version"
    exit 1
  fi
fi

echo "📦 Installing PocketBase v${VERSION} (${OS}/${ARCH})..."

# Download
DOWNLOAD_URL="https://github.com/pocketbase/pocketbase/releases/download/v${VERSION}/pocketbase_${VERSION}_${OS}_${ARCH}.zip"
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "⬇️  Downloading from: $DOWNLOAD_URL"
curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/pocketbase.zip"

if [[ ! -s "$TMP_DIR/pocketbase.zip" ]]; then
  echo "❌ Download failed or empty file"
  exit 1
fi

# Extract
echo "📂 Extracting..."
unzip -qo "$TMP_DIR/pocketbase.zip" -d "$TMP_DIR"

if [[ ! -f "$TMP_DIR/pocketbase" ]]; then
  echo "❌ Binary not found in archive"
  exit 1
fi

# Install
chmod +x "$TMP_DIR/pocketbase"
if [[ -w "$INSTALL_DIR" ]]; then
  mv "$TMP_DIR/pocketbase" "$INSTALL_DIR/pocketbase"
else
  sudo mv "$TMP_DIR/pocketbase" "$INSTALL_DIR/pocketbase"
fi

# Create base data directory
if [[ ! -d "$DATA_BASE" ]]; then
  if [[ -w "$(dirname $DATA_BASE)" ]]; then
    mkdir -p "$DATA_BASE"
  else
    sudo mkdir -p "$DATA_BASE"
    sudo chmod 755 "$DATA_BASE"
  fi
fi

# Verify
INSTALLED_VERSION=$("$INSTALL_DIR/pocketbase" --version 2>/dev/null | grep -oP '[\d.]+' || echo "unknown")
echo ""
echo "✅ PocketBase v${INSTALLED_VERSION} installed to ${INSTALL_DIR}/pocketbase"
echo "📁 Data directory base: ${DATA_BASE}"
echo ""
echo "Next steps:"
echo "  bash scripts/manage.sh init --name myapp --port 8090"
echo "  bash scripts/manage.sh service --name myapp --enable"
