#!/bin/bash
# Stunnel TLS Wrapper — Installer
set -euo pipefail

echo "🔒 Stunnel TLS Wrapper — Installing..."

# Detect package manager
install_stunnel() {
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq stunnel4 openssl
    # Enable stunnel on Debian/Ubuntu
    sudo sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null || true
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y -q stunnel openssl
  elif command -v yum &>/dev/null; then
    sudo yum install -y -q stunnel openssl
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm stunnel openssl
  elif command -v apk &>/dev/null; then
    sudo apk add stunnel openssl
  elif command -v brew &>/dev/null; then
    brew install stunnel openssl
  else
    echo "❌ Unsupported package manager. Install stunnel manually."
    exit 1
  fi
}

# Check if already installed
if command -v stunnel &>/dev/null || command -v stunnel4 &>/dev/null; then
  STUNNEL_BIN=$(command -v stunnel 2>/dev/null || command -v stunnel4 2>/dev/null)
  STUNNEL_VER=$($STUNNEL_BIN -version 2>&1 | head -1 || echo "unknown")
  echo "✅ Stunnel already installed: $STUNNEL_VER"
else
  install_stunnel
  echo "✅ Stunnel installed successfully"
fi

# Create directory structure
CERT_DIR="${STUNNEL_CERT_DIR:-/etc/stunnel/certs}"
CONF_DIR="${STUNNEL_CONF_DIR:-/etc/stunnel/conf.d}"

sudo mkdir -p "$CERT_DIR" "$CONF_DIR" /var/log/stunnel

# Set permissions
sudo chmod 700 "$CERT_DIR"
sudo chown root:root "$CERT_DIR"

# Create global config if not exists
GLOBAL_CONF="/etc/stunnel/stunnel.conf"
if [ ! -f "$GLOBAL_CONF" ]; then
  sudo tee "$GLOBAL_CONF" > /dev/null << 'CONF'
; Stunnel TLS Wrapper — Global Configuration
; Managed by stunnel-tls-wrapper skill

pid = /var/run/stunnel.pid

; Logging
output = /var/log/stunnel/stunnel.log
debug = 5

; Security
fips = no

; Include per-tunnel configs
include = /etc/stunnel/conf.d
CONF
  echo "✅ Global config created: $GLOBAL_CONF"
else
  echo "ℹ️  Global config exists: $GLOBAL_CONF"
fi

# Enable and start service
if command -v systemctl &>/dev/null; then
  SVC_NAME=""
  if systemctl list-unit-files stunnel4.service &>/dev/null 2>&1; then
    SVC_NAME="stunnel4"
  elif systemctl list-unit-files stunnel.service &>/dev/null 2>&1; then
    SVC_NAME="stunnel"
  fi
  
  if [ -n "$SVC_NAME" ]; then
    sudo systemctl enable "$SVC_NAME" 2>/dev/null || true
    echo "✅ Service '$SVC_NAME' enabled"
  fi
fi

echo ""
echo "🔒 Stunnel TLS Wrapper installed!"
echo "   Cert dir:  $CERT_DIR"
echo "   Conf dir:  $CONF_DIR"
echo "   Logs:      /var/log/stunnel/stunnel.log"
echo ""
echo "Next: bash scripts/tunnel.sh create --name myservice --accept 8443 --connect 127.0.0.1:8080 --mode server --cert auto"
