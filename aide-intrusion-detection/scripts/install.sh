#!/bin/bash
# AIDE Intrusion Detection — Installer
set -euo pipefail

echo "=== AIDE Intrusion Detection — Installer ==="

# Detect package manager
install_aide() {
  if command -v apt-get &>/dev/null; then
    echo "[*] Installing AIDE via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y aide aide-common
  elif command -v yum &>/dev/null; then
    echo "[*] Installing AIDE via yum..."
    sudo yum install -y aide
  elif command -v dnf &>/dev/null; then
    echo "[*] Installing AIDE via dnf..."
    sudo dnf install -y aide
  elif command -v pacman &>/dev/null; then
    echo "[*] Installing AIDE via pacman..."
    sudo pacman -S --noconfirm aide
  elif command -v apk &>/dev/null; then
    echo "[*] Installing AIDE via apk..."
    sudo apk add aide
  elif command -v brew &>/dev/null; then
    echo "[*] Installing AIDE via brew..."
    brew install aide
  else
    echo "[!] Could not detect package manager. Install AIDE manually."
    exit 1
  fi
}

# Check if already installed
if command -v aide &>/dev/null; then
  AIDE_VERSION=$(aide --version 2>&1 | head -1)
  echo "[✓] AIDE already installed: $AIDE_VERSION"
else
  install_aide
  if command -v aide &>/dev/null; then
    AIDE_VERSION=$(aide --version 2>&1 | head -1)
    echo "[✓] AIDE installed successfully: $AIDE_VERSION"
  else
    echo "[!] AIDE installation failed"
    exit 1
  fi
fi

# Create directories
AIDE_DIR="${AIDE_DB_DIR:-/var/lib/aide}"
AIDE_CONF_DIR="/etc/aide"
sudo mkdir -p "$AIDE_DIR" "$AIDE_CONF_DIR" 2>/dev/null || true

# Install default config if none exists
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$AIDE_CONF_DIR/aide.conf" ] && [ -f "$SCRIPT_DIR/aide-config.conf" ]; then
  echo "[*] Installing default AIDE configuration..."
  sudo cp "$SCRIPT_DIR/aide-config.conf" "$AIDE_CONF_DIR/aide.conf"
  echo "[✓] Config installed at $AIDE_CONF_DIR/aide.conf"
else
  echo "[i] Config already exists at $AIDE_CONF_DIR/aide.conf"
fi

# Install helper tools
for tool in curl jq; do
  if ! command -v "$tool" &>/dev/null; then
    echo "[*] Installing $tool..."
    if command -v apt-get &>/dev/null; then
      sudo apt-get install -y "$tool" 2>/dev/null
    elif command -v yum &>/dev/null; then
      sudo yum install -y "$tool" 2>/dev/null
    fi
  fi
done

echo ""
echo "=== Installation Complete ==="
echo "Next steps:"
echo "  1. Review config:    sudo cat /etc/aide/aide.conf"
echo "  2. Initialize DB:    bash scripts/run.sh init"
echo "  3. Schedule checks:  bash scripts/run.sh schedule --interval 6h"
