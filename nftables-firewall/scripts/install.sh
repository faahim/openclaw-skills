#!/bin/bash
# nftables Firewall Manager — Installer
# Installs nftables and configures a safe default ruleset

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[nft-install]${NC} $*"; }
warn() { echo -e "${YELLOW}[nft-install]${NC} $*"; }
err()  { echo -e "${RED}[nft-install]${NC} $*" >&2; }

# Detect OS
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  elif [ -f /etc/redhat-release ]; then
    echo "rhel"
  else
    echo "unknown"
  fi
}

# Check root
if [ "$EUID" -ne 0 ]; then
  err "This script requires root. Run with: sudo bash scripts/install.sh"
  exit 1
fi

OS=$(detect_os)
log "Detected OS: $OS"

# Install nftables
case "$OS" in
  ubuntu|debian|pop|linuxmint)
    log "Installing nftables via apt..."
    apt-get update -qq
    apt-get install -y nftables jq
    ;;
  fedora|rhel|centos|rocky|alma)
    log "Installing nftables via dnf..."
    dnf install -y nftables jq
    ;;
  arch|manjaro)
    log "Installing nftables via pacman..."
    pacman -Sy --noconfirm nftables jq
    ;;
  alpine)
    log "Installing nftables via apk..."
    apk add nftables jq
    ;;
  opensuse*|sles)
    log "Installing nftables via zypper..."
    zypper install -y nftables jq
    ;;
  *)
    warn "Unknown OS '$OS'. Trying apt, then dnf..."
    if command -v apt-get &>/dev/null; then
      apt-get update -qq && apt-get install -y nftables jq
    elif command -v dnf &>/dev/null; then
      dnf install -y nftables jq
    else
      err "Cannot detect package manager. Install nftables manually."
      exit 1
    fi
    ;;
esac

# Verify installation
if ! command -v nft &>/dev/null; then
  err "nftables installation failed — 'nft' command not found"
  exit 1
fi

NFT_VERSION=$(nft --version 2>/dev/null | head -1)
log "Installed: $NFT_VERSION"

# Enable nftables service
if command -v systemctl &>/dev/null; then
  systemctl enable nftables 2>/dev/null || true
  systemctl start nftables 2>/dev/null || true
  log "nftables service enabled and started"
fi

# Create config directory
mkdir -p /etc/nftables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Backup existing rules
if nft list ruleset 2>/dev/null | grep -q "table"; then
  BACKUP="/etc/nftables/backup-$(date +%Y%m%d-%H%M%S).nft"
  nft list ruleset > "$BACKUP"
  log "Existing rules backed up to: $BACKUP"
fi

# Install the management script
chmod +x "$SCRIPT_DIR/nft-manage.sh"

# Create log directory
mkdir -p /var/log/nftables

# Switch iptables to nft backend if possible
if command -v update-alternatives &>/dev/null; then
  update-alternatives --set iptables /usr/sbin/iptables-nft 2>/dev/null || true
fi

log "✅ nftables installed and ready!"
log ""
log "Next steps:"
log "  1. Apply a preset:  sudo bash scripts/nft-manage.sh apply-preset server-basic"
log "  2. View rules:      sudo bash scripts/nft-manage.sh show"
log "  3. Add rules:       sudo bash scripts/nft-manage.sh allow --port 3000 --proto tcp"
