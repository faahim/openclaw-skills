#!/bin/bash
# Incus Installation Script
# Supports: Ubuntu 22.04+, Debian 12+
# Source: Zabbly repository (official Incus packages)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[incus-install]${NC} $1"; }
warn() { echo -e "${YELLOW}[incus-install]${NC} $1"; }
err() { echo -e "${RED}[incus-install]${NC} $1" >&2; }

# Check if running as root or with sudo
check_root() {
    if [ "$EUID" -ne 0 ]; then
        err "This script must be run as root or with sudo."
        echo "Usage: sudo bash scripts/install.sh"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
        OS_CODENAME="${VERSION_CODENAME:-}"
    else
        err "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    log "Detected: $OS_ID $OS_VERSION ($OS_CODENAME)"
}

# Check if Incus is already installed
check_existing() {
    if command -v incus &>/dev/null; then
        CURRENT_VERSION=$(incus version 2>/dev/null || echo "unknown")
        warn "Incus is already installed (version: $CURRENT_VERSION)"
        read -p "Reinstall/upgrade? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Skipping installation."
            exit 0
        fi
    fi
}

# Install on Debian/Ubuntu via Zabbly repo
install_zabbly() {
    log "Adding Zabbly repository..."

    # Install prerequisites
    apt-get update -qq
    apt-get install -y -qq curl gpg lsb-release >/dev/null

    # Add Zabbly GPG key
    mkdir -p /etc/apt/keyrings/
    curl -fsSL https://pkgs.zabbly.com/key.asc | gpg --dearmor -o /etc/apt/keyrings/zabbly.gpg 2>/dev/null

    # Determine which repo to use
    local REPO_CODENAME="$OS_CODENAME"
    if [ -z "$REPO_CODENAME" ]; then
        err "Could not determine OS codename."
        exit 1
    fi

    # Add repository
    cat > /etc/apt/sources.list.d/zabbly-incus-stable.sources <<EOF
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: $REPO_CODENAME
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.gpg
EOF

    log "Installing Incus..."
    apt-get update -qq
    apt-get install -y incus incus-client >/dev/null

    log "Incus installed successfully."
}

# Post-install setup
post_install() {
    local REAL_USER="${SUDO_USER:-$USER}"

    # Add user to incus-admin group
    if getent group incus-admin >/dev/null 2>&1; then
        usermod -aG incus-admin "$REAL_USER"
        log "Added $REAL_USER to incus-admin group."
    fi

    # Run initial setup with defaults
    log "Running initial setup..."
    incus admin init --minimal 2>/dev/null || true

    log ""
    log "✅ Incus is ready!"
    log ""
    log "Quick test:"
    log "  incus launch images:ubuntu/24.04 test-container"
    log "  incus exec test-container -- bash"
    log "  incus delete test-container --force"
    log ""

    if [ "$REAL_USER" != "root" ]; then
        warn "Log out and back in (or run 'newgrp incus-admin') for group changes to take effect."
    fi
}

# Main
main() {
    log "Incus Container Manager — Installer"
    log "===================================="

    check_root
    detect_os
    check_existing

    case "$OS_ID" in
        ubuntu|debian)
            install_zabbly
            ;;
        *)
            err "Unsupported OS: $OS_ID"
            err "Supported: Ubuntu 22.04+, Debian 12+"
            err "For other distros, see: https://linuxcontainers.org/incus/docs/main/installing/"
            exit 1
            ;;
    esac

    post_install
}

main "$@"
