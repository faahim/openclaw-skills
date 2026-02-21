#!/bin/bash
# Tailscale VPN Installer — Auto-detects OS and installs Tailscale
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[tailscale-vpn]${NC} $1"; }
warn() { echo -e "${YELLOW}[tailscale-vpn]${NC} $1"; }
err() { echo -e "${RED}[tailscale-vpn]${NC} $1" >&2; }

# Check if already installed
if command -v tailscale &>/dev/null; then
    CURRENT_VERSION=$(tailscale version 2>/dev/null | head -1)
    log "Tailscale already installed: $CURRENT_VERSION"
    
    # Check if tailscaled is running
    if systemctl is-active --quiet tailscaled 2>/dev/null; then
        log "tailscaled service is running"
        tailscale status 2>/dev/null && true
    else
        warn "tailscaled is not running. Starting..."
        sudo systemctl start tailscaled
        sudo systemctl enable tailscaled
        log "tailscaled started and enabled"
    fi
    exit 0
fi

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ "$(uname)" == "Darwin" ]]; then
        echo "macos"
    else
        err "Unsupported OS"
        exit 1
    fi
}

OS=$(detect_os)
log "Detected OS: $OS"

case "$OS" in
    ubuntu|debian|raspbian|pop|linuxmint|kali)
        log "Installing via official Tailscale script (Debian/Ubuntu family)..."
        curl -fsSL https://tailscale.com/install.sh | sh
        ;;
    fedora|rhel|centos|rocky|alma|ol)
        log "Installing via official Tailscale script (RHEL family)..."
        curl -fsSL https://tailscale.com/install.sh | sh
        ;;
    arch|manjaro|endeavouros)
        log "Installing via pacman..."
        sudo pacman -Sy --noconfirm tailscale
        ;;
    alpine)
        log "Installing via apk..."
        sudo apk add tailscale
        ;;
    macos)
        if command -v brew &>/dev/null; then
            log "Installing via Homebrew..."
            brew install tailscale
        else
            err "Homebrew not found. Install from https://tailscale.com/download/mac"
            exit 1
        fi
        ;;
    opensuse*|sles)
        log "Installing via official Tailscale script (openSUSE)..."
        curl -fsSL https://tailscale.com/install.sh | sh
        ;;
    *)
        warn "Unknown distro '$OS'. Trying official install script..."
        curl -fsSL https://tailscale.com/install.sh | sh
        ;;
esac

# Enable and start tailscaled
if [[ "$OS" != "macos" ]]; then
    log "Enabling tailscaled service..."
    sudo systemctl enable --now tailscaled
fi

# Verify installation
if command -v tailscale &>/dev/null; then
    VERSION=$(tailscale version 2>/dev/null | head -1)
    log "✅ Tailscale installed successfully: $VERSION"
    echo ""
    log "Next step: Run 'sudo tailscale up' to connect to your tailnet"
else
    err "❌ Installation failed. Check errors above."
    exit 1
fi
