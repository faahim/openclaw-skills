#!/bin/bash
# Typesense Server Installer
set -e

TYPESENSE_VERSION="${TYPESENSE_VERSION:-27.1}"
INSTALL_DIR="${TYPESENSE_DIR:-$HOME/.typesense}"
DATA_DIR="$INSTALL_DIR/data"
LOG_DIR="$INSTALL_DIR/logs"
CONFIG_FILE="$INSTALL_DIR/config.ini"
BIN_DIR="$INSTALL_DIR/bin"

echo "🔍 Detecting system..."

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) PLATFORM="linux-$ARCH" ;;
  darwin) PLATFORM="darwin-$ARCH" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

echo "📦 Platform: $PLATFORM"

# Check if already installed
if [ -f "$BIN_DIR/typesense-server" ]; then
  CURRENT=$("$BIN_DIR/typesense-server" --version 2>/dev/null || echo "unknown")
  echo "⚠️  Typesense already installed (version: $CURRENT)"
  read -p "   Reinstall? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipping installation."
    exit 0
  fi
fi

# Create directories
mkdir -p "$BIN_DIR" "$DATA_DIR" "$LOG_DIR"

# Download
DOWNLOAD_URL="https://dl.typesense.org/releases/${TYPESENSE_VERSION}/typesense-server-${TYPESENSE_VERSION}-${PLATFORM}.tar.gz"
TEMP_DIR=$(mktemp -d)
echo "⬇️  Downloading Typesense v${TYPESENSE_VERSION}..."
echo "   URL: $DOWNLOAD_URL"

if ! curl -fSL "$DOWNLOAD_URL" -o "$TEMP_DIR/typesense.tar.gz" 2>/dev/null; then
  echo "❌ Download failed. Check version number or network."
  echo "   Available versions: https://github.com/typesense/typesense/releases"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Extract
echo "📂 Extracting..."
tar -xzf "$TEMP_DIR/typesense.tar.gz" -C "$TEMP_DIR"
cp "$TEMP_DIR/typesense-server" "$BIN_DIR/typesense-server"
chmod +x "$BIN_DIR/typesense-server"
rm -rf "$TEMP_DIR"

# Generate API key if config doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
  API_KEY=$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 64)
  cat > "$CONFIG_FILE" << EOF
[server]
api-address = 0.0.0.0
api-port = 8108
data-dir = $DATA_DIR
api-key = $API_KEY
log-dir = $LOG_DIR
enable-cors = true
EOF
  echo "🔑 API key generated and saved to $CONFIG_FILE"
  echo "   Key: $API_KEY"
else
  echo "📝 Config already exists at $CONFIG_FILE"
  API_KEY=$(grep "api-key" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
fi

# Verify installation
VERSION=$("$BIN_DIR/typesense-server" --version 2>&1 || echo "unknown")
echo ""
echo "✅ Typesense installed successfully!"
echo "   Binary: $BIN_DIR/typesense-server"
echo "   Config: $CONFIG_FILE"
echo "   Data:   $DATA_DIR"
echo "   Logs:   $LOG_DIR"
echo "   Version: $VERSION"
echo ""
echo "🚀 Start with: bash scripts/run.sh start"
