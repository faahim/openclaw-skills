#!/bin/bash
# Dokku Installation Script
# Installs Dokku PaaS on Ubuntu/Debian systems
set -euo pipefail

DOKKU_VERSION="${DOKKU_VERSION:-v0.34.8}"
DOKKU_HOSTNAME="${DOKKU_HOSTNAME:-}"
DOKKU_VHOST_ENABLE="${DOKKU_VHOST_ENABLE:-true}"
DOKKU_KEY_FILE="${DOKKU_KEY_FILE:-$HOME/.ssh/id_rsa.pub}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[dokku-install]${NC} $1"; }
warn() { echo -e "${YELLOW}[dokku-install]${NC} $1"; }
err() { echo -e "${RED}[dokku-install]${NC} $1" >&2; }

# Check prerequisites
check_prereqs() {
    if [[ $EUID -ne 0 ]]; then
        err "This script must be run as root (use sudo)"
        exit 1
    fi

    if ! command -v docker &>/dev/null; then
        log "Docker not found. Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
        log "Docker installed successfully"
    fi

    if ! command -v git &>/dev/null; then
        log "Installing git..."
        apt-get update -qq && apt-get install -y -qq git
    fi

    # Check OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
            warn "Dokku is optimized for Ubuntu/Debian. Current OS: $ID"
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] || exit 1
        fi
    fi
}

# Install Dokku
install_dokku() {
    if command -v dokku &>/dev/null; then
        local current_version
        current_version=$(dokku version 2>/dev/null || echo "unknown")
        warn "Dokku is already installed (version: $current_version)"
        read -p "Reinstall/upgrade? (y/N) " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || { log "Skipping installation."; return 0; }
    fi

    log "Installing Dokku ${DOKKU_VERSION}..."

    # Download and run bootstrap script
    wget -NP /tmp "https://dokku.com/install/${DOKKU_VERSION}/bootstrap.sh"
    DOKKU_TAG="${DOKKU_VERSION}" bash /tmp/bootstrap.sh

    log "Dokku installed successfully!"
}

# Configure Dokku
configure_dokku() {
    # Set hostname
    if [[ -n "$DOKKU_HOSTNAME" ]]; then
        log "Setting hostname to ${DOKKU_HOSTNAME}..."
        dokku domains:set-global "$DOKKU_HOSTNAME"
    else
        local detected_hostname
        detected_hostname=$(hostname -f 2>/dev/null || hostname)
        log "No DOKKU_HOSTNAME set. Using detected: ${detected_hostname}"
        dokku domains:set-global "$detected_hostname"
    fi

    # Enable/disable vhost routing
    if [[ "$DOKKU_VHOST_ENABLE" == "true" ]]; then
        dokku domains:enable-global 2>/dev/null || true
    fi

    # Add SSH key
    if [[ -f "$DOKKU_KEY_FILE" ]]; then
        log "Adding SSH key from ${DOKKU_KEY_FILE}..."
        dokku ssh-keys:add admin "$DOKKU_KEY_FILE" 2>/dev/null || \
            warn "SSH key already added or invalid"
    else
        warn "No SSH key found at ${DOKKU_KEY_FILE}"
        warn "Add your key later: dokku ssh-keys:add admin /path/to/key.pub"
    fi
}

# Print summary
print_summary() {
    local version
    version=$(dokku version)
    local hostname
    hostname=$(dokku domains:report --global 2>/dev/null | grep "Global domains" | awk '{print $NF}' || hostname -f)

    echo ""
    echo "=========================================="
    echo "  Dokku Installation Complete!"
    echo "=========================================="
    echo ""
    echo "  Version:  ${version}"
    echo "  Hostname: ${hostname}"
    echo ""
    echo "  Quick start:"
    echo "    dokku apps:create myapp"
    echo "    git remote add dokku dokku@${hostname}:myapp"
    echo "    git push dokku main"
    echo ""
    echo "  Install plugins:"
    echo "    dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres"
    echo "    dokku plugin:install https://github.com/dokku/dokku-redis.git redis"
    echo "    dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git letsencrypt"
    echo ""
    echo "=========================================="
}

# Main
main() {
    log "Starting Dokku installation..."
    check_prereqs
    install_dokku
    configure_dokku
    print_summary
}

main "$@"
