#!/bin/bash
# Meilisearch Installer
# Installs the latest Meilisearch binary and optionally sets up systemd service

set -euo pipefail

INSTALL_DIR="/usr/local/bin"
DATA_DIR="/var/lib/meilisearch/data"
SYSTEMD_UNIT="/etc/systemd/system/meilisearch.service"
SETUP_SYSTEMD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --systemd) SETUP_SYSTEMD=true; shift ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --systemd       Set up systemd service"
      echo "  --install-dir   Installation directory (default: /usr/local/bin)"
      echo "  --data-dir      Data directory (default: /var/lib/meilisearch/data)"
      echo "  -h, --help      Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64)  MEILI_ARCH="amd64" ;;
  aarch64) MEILI_ARCH="aarch64" ;;
  *)       echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "$OS" != "linux" ]]; then
  echo "❌ This installer supports Linux only. For macOS, use: brew install meilisearch"
  exit 1
fi

echo "🔍 Detecting latest Meilisearch version..."
LATEST=$(curl -s https://api.github.com/repos/meilisearch/meilisearch/releases/latest | jq -r '.tag_name')
if [[ -z "$LATEST" || "$LATEST" == "null" ]]; then
  echo "❌ Could not detect latest version. Check your internet connection."
  exit 1
fi
echo "   Latest version: $LATEST"

# Check if already installed
if command -v meilisearch &>/dev/null; then
  CURRENT=$(meilisearch --version 2>/dev/null | head -1 | grep -oP 'v[\d.]+' || echo "unknown")
  echo "   Currently installed: $CURRENT"
  if [[ "$CURRENT" == "$LATEST" ]]; then
    echo "✅ Already up to date!"
    [[ "$SETUP_SYSTEMD" == "false" ]] && exit 0
  fi
fi

# Download
DOWNLOAD_URL="https://github.com/meilisearch/meilisearch/releases/download/${LATEST}/meilisearch-linux-${MEILI_ARCH}"
echo "⬇️  Downloading Meilisearch ${LATEST} (${MEILI_ARCH})..."
TMPFILE=$(mktemp)
curl -sL "$DOWNLOAD_URL" -o "$TMPFILE"
chmod +x "$TMPFILE"

# Verify it runs
if ! "$TMPFILE" --version &>/dev/null; then
  echo "❌ Downloaded binary is not executable. Try manual install."
  rm -f "$TMPFILE"
  exit 1
fi

# Install
echo "📦 Installing to ${INSTALL_DIR}/meilisearch..."
if [[ -w "$INSTALL_DIR" ]]; then
  mv "$TMPFILE" "${INSTALL_DIR}/meilisearch"
else
  sudo mv "$TMPFILE" "${INSTALL_DIR}/meilisearch"
fi

echo "✅ Meilisearch ${LATEST} installed successfully!"
meilisearch --version

# Systemd setup
if [[ "$SETUP_SYSTEMD" == "true" ]]; then
  echo ""
  echo "🔧 Setting up systemd service..."

  # Create user
  if ! id meilisearch &>/dev/null; then
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin meilisearch
    echo "   Created system user: meilisearch"
  fi

  # Create data directory
  sudo mkdir -p "$DATA_DIR"
  sudo chown meilisearch:meilisearch "$DATA_DIR"

  # Generate master key if not set
  MASTER_KEY="${MEILI_MASTER_KEY:-$(openssl rand -base64 24)}"

  # Write service file
  sudo tee "$SYSTEMD_UNIT" > /dev/null << EOSVC
[Unit]
Description=Meilisearch Search Engine
Documentation=https://docs.meilisearch.com
After=network.target

[Service]
Type=simple
User=meilisearch
Group=meilisearch
ExecStart=${INSTALL_DIR}/meilisearch \\
  --db-path ${DATA_DIR} \\
  --env production \\
  --http-addr 127.0.0.1:7700 \\
  --master-key ${MASTER_KEY}
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOSVC

  sudo systemctl daemon-reload
  sudo systemctl enable meilisearch

  echo "✅ Systemd service created and enabled"
  echo ""
  echo "🔑 Master key: ${MASTER_KEY}"
  echo "   Save this! You'll need it to connect."
  echo ""
  echo "Start with: sudo systemctl start meilisearch"
  echo "Status:     sudo systemctl status meilisearch"
  echo "Logs:       sudo journalctl -u meilisearch -f"
fi

echo ""
echo "🚀 Quick test: meilisearch --env development &"
echo "   Then visit: http://localhost:7700"
