#!/bin/bash
# ZeroTier VPN — Installation Script
# Installs ZeroTier One on Linux, macOS, or FreeBSD

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[ZT]${NC} $*"; }
warn() { echo -e "${YELLOW}[ZT]${NC} $*"; }
err()  { echo -e "${RED}[ZT]${NC} $*" >&2; }

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == "freebsd"* ]]; then
    echo "freebsd"
  else
    err "Unsupported OS: $OSTYPE"
    exit 1
  fi
}

# Check if ZeroTier is already installed
check_existing() {
  if command -v zerotier-cli &>/dev/null; then
    local version
    version=$(zerotier-cli -v 2>/dev/null || echo "unknown")
    log "ZeroTier already installed (version: $version)"
    
    # Check if service is running
    if sudo zerotier-cli info &>/dev/null; then
      log "Service is running"
      sudo zerotier-cli info
    else
      warn "Service not running. Starting..."
      start_service
    fi
    return 0
  fi
  return 1
}

# Install on Linux
install_linux() {
  log "Installing ZeroTier on Linux..."
  
  # Official install script (supports Debian, Ubuntu, CentOS, Fedora, RHEL, Arch, etc.)
  curl -s https://install.zerotier.com | sudo bash
  
  log "Installation complete."
}

# Install on macOS
install_macos() {
  log "Installing ZeroTier on macOS..."
  
  if command -v brew &>/dev/null; then
    brew install --cask zerotier-one
  else
    err "Homebrew not found. Install from https://www.zerotier.com/download/"
    exit 1
  fi
  
  log "Installation complete."
}

# Install on FreeBSD
install_freebsd() {
  log "Installing ZeroTier on FreeBSD..."
  sudo pkg install -y zerotier
  log "Installation complete."
}

# Start and enable service
start_service() {
  local os
  os=$(detect_os)
  
  if [[ "$os" == "linux" ]]; then
    sudo systemctl enable zerotier-one 2>/dev/null || true
    sudo systemctl start zerotier-one
  elif [[ "$os" == "macos" ]]; then
    # macOS service starts automatically after install
    log "ZeroTier service managed by launchd on macOS"
  elif [[ "$os" == "freebsd" ]]; then
    sudo sysrc zerotier_enable="YES"
    sudo service zerotier start
  fi
}

# Verify installation
verify() {
  log "Verifying installation..."
  
  if ! command -v zerotier-cli &>/dev/null; then
    err "zerotier-cli not found in PATH"
    exit 1
  fi
  
  # Wait for service to start
  local attempts=0
  while ! sudo zerotier-cli info &>/dev/null; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge 10 ]]; then
      err "Service failed to start after 10 seconds"
      exit 1
    fi
    sleep 1
  done
  
  local node_id
  node_id=$(sudo zerotier-cli info | awk '{print $3}')
  local version
  version=$(sudo zerotier-cli info | awk '{print $4}')
  
  log "✅ ZeroTier installed successfully"
  log "   Node ID: $node_id"
  log "   Version: $version"
  log "   Status:  ONLINE"
  echo ""
  log "Next steps:"
  log "  1. Get API token from https://my.zerotier.com/account"
  log "  2. Create network: bash scripts/manage.sh create --name my-network"
  log "  3. Join network:   sudo zerotier-cli join <network-id>"
}

# Main
main() {
  log "ZeroTier VPN — Installer"
  echo ""
  
  if check_existing; then
    log "Already installed. Nothing to do."
    exit 0
  fi
  
  local os
  os=$(detect_os)
  
  case "$os" in
    linux)   install_linux   ;;
    macos)   install_macos   ;;
    freebsd) install_freebsd ;;
  esac
  
  start_service
  verify
}

main "$@"
