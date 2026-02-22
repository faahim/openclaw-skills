#!/bin/bash
# WireGuard VPN - Installation Script
# Auto-detects OS and installs WireGuard tools + kernel module

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; exit 1; }

# Check root
[[ $EUID -ne 0 ]] && err "This script must be run as root (sudo bash scripts/install.sh)"

# Detect OS
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
  elif [ -f /etc/debian_version ]; then
    OS="debian"
    VER=$(cat /etc/debian_version)
  else
    err "Unsupported OS. Install WireGuard manually: https://www.wireguard.com/install/"
  fi
  echo "Detected: $OS $VER"
}

install_wireguard() {
  case "$OS" in
    ubuntu|pop)
      apt-get update -qq
      apt-get install -y wireguard wireguard-tools qrencode jq
      ;;
    debian)
      apt-get update -qq
      # Debian needs backports for older versions
      if [[ "${VER%%.*}" -lt 11 ]]; then
        echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" > /etc/apt/sources.list.d/backports.list
        apt-get update -qq
        apt-get install -y -t ${VERSION_CODENAME}-backports wireguard wireguard-tools
      else
        apt-get install -y wireguard wireguard-tools
      fi
      apt-get install -y qrencode jq
      ;;
    fedora)
      dnf install -y wireguard-tools qrencode jq
      ;;
    centos|rhel|rocky|alma)
      dnf install -y epel-release elrepo-release || true
      dnf install -y wireguard-tools qrencode jq
      ;;
    arch|manjaro)
      pacman -Sy --noconfirm wireguard-tools qrencode jq
      ;;
    alpine)
      apk add wireguard-tools qrencode jq
      ;;
    *)
      err "Unsupported OS: $OS. Install WireGuard manually: https://www.wireguard.com/install/"
      ;;
  esac
}

setup_directories() {
  mkdir -p /etc/wireguard/clients
  chmod 700 /etc/wireguard
  log "Config directory: /etc/wireguard"
}

enable_forwarding() {
  # Enable IPv4 forwarding
  if ! sysctl -n net.ipv4.ip_forward | grep -q 1; then
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/99-wireguard.conf
    log "Enabled IPv4 forwarding"
  else
    log "IPv4 forwarding already enabled"
  fi

  # Enable IPv6 forwarding
  if ! sysctl -n net.ipv6.conf.all.forwarding | grep -q 1 2>/dev/null; then
    sysctl -w net.ipv6.conf.all.forwarding=1
    echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.d/99-wireguard.conf
    log "Enabled IPv6 forwarding"
  fi
}

verify_install() {
  if command -v wg &>/dev/null; then
    log "WireGuard installed: $(wg --version 2>/dev/null || echo 'version unknown')"
  else
    err "WireGuard installation failed"
  fi

  if command -v wg-quick &>/dev/null; then
    log "wg-quick available"
  else
    warn "wg-quick not found — you may need to use 'wg' directly"
  fi

  if command -v qrencode &>/dev/null; then
    log "qrencode available (QR code generation)"
  else
    warn "qrencode not installed — QR codes won't be available"
  fi
}

main() {
  echo "========================================="
  echo "  WireGuard VPN — Installation"
  echo "========================================="
  echo ""

  detect_os
  echo ""

  echo "Installing WireGuard..."
  install_wireguard
  echo ""

  setup_directories
  enable_forwarding
  echo ""

  verify_install
  echo ""

  echo "========================================="
  log "WireGuard is ready!"
  echo "  Next: bash scripts/wg-manager.sh init-server --help"
  echo "========================================="
}

main "$@"
