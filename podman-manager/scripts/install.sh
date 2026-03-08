#!/bin/bash
# Podman Installation Script
# Detects OS and installs Podman + dependencies

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[podman-manager]${NC} $1"; }
warn() { echo -e "${YELLOW}[podman-manager]${NC} $1"; }
error() { echo -e "${RED}[podman-manager]${NC} $1" >&2; }

# Check if Podman is already installed
if command -v podman &>/dev/null; then
    CURRENT_VERSION=$(podman --version | awk '{print $3}')
    log "Podman $CURRENT_VERSION is already installed"
    
    read -p "Reinstall/upgrade? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Skipping installation"
        exit 0
    fi
fi

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [[ "$(uname)" == "Darwin" ]]; then
        OS="macos"
        OS_VERSION=$(sw_vers -productVersion)
    else
        error "Unsupported operating system"
        exit 1
    fi
}

install_debian_ubuntu() {
    log "Installing Podman on $OS $OS_VERSION..."
    
    # Add Podman repository for older Ubuntu versions
    if [[ "$OS" == "ubuntu" ]] && [[ "${OS_VERSION%%.*}" -lt 22 ]]; then
        warn "Ubuntu < 22.04 detected — adding Kubic repository"
        . /etc/os-release
        sudo sh -c "echo 'deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
        curl -fsSL "https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
    fi
    
    sudo apt-get update -qq
    sudo apt-get install -y -qq podman slirp4netns fuse-overlayfs uidmap
    
    # Install podman-compose
    if command -v pip3 &>/dev/null; then
        pip3 install --user podman-compose 2>/dev/null || warn "podman-compose install failed (optional)"
    fi
}

install_fedora() {
    log "Installing Podman on Fedora $OS_VERSION..."
    sudo dnf install -y podman podman-compose slirp4netns fuse-overlayfs
}

install_arch() {
    log "Installing Podman on Arch Linux..."
    sudo pacman -Sy --noconfirm podman slirp4netns fuse-overlayfs
    pip install --user podman-compose 2>/dev/null || warn "podman-compose install failed (optional)"
}

install_macos() {
    log "Installing Podman on macOS $OS_VERSION..."
    
    if ! command -v brew &>/dev/null; then
        error "Homebrew is required. Install from https://brew.sh"
        exit 1
    fi
    
    brew install podman
    
    log "Initializing Podman machine..."
    podman machine init 2>/dev/null || warn "Podman machine already initialized"
    podman machine start 2>/dev/null || warn "Podman machine already running"
}

setup_rootless() {
    log "Configuring rootless environment..."
    
    # Ensure subuid/subgid are set
    if ! grep -q "^$USER:" /etc/subuid 2>/dev/null; then
        sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"
        log "Added subuid/subgid mappings for $USER"
    fi
    
    # Create containers config directory
    mkdir -p ~/.config/containers
    
    # Set up default registries if not exists
    if [[ ! -f ~/.config/containers/registries.conf ]]; then
        cat > ~/.config/containers/registries.conf <<'EOF'
unqualified-search-registries = ["docker.io", "quay.io", "ghcr.io"]
EOF
        log "Created default registries.conf"
    fi
    
    # Enable lingering for systemd user services
    if command -v loginctl &>/dev/null; then
        loginctl enable-linger "$USER" 2>/dev/null || warn "Could not enable lingering (needs systemd)"
    fi
}

# Main
detect_os

case $OS in
    ubuntu|debian|linuxmint|pop)
        install_debian_ubuntu
        ;;
    fedora|centos|rhel|rocky|alma)
        install_fedora
        ;;
    arch|manjaro|endeavouros)
        install_arch
        ;;
    macos)
        install_macos
        ;;
    *)
        error "Unsupported OS: $OS"
        error "Manual install: https://podman.io/getting-started/installation"
        exit 1
        ;;
esac

# Post-install setup (Linux only)
if [[ "$OS" != "macos" ]]; then
    setup_rootless
fi

# Verify installation
if command -v podman &>/dev/null; then
    VERSION=$(podman --version | awk '{print $3}')
    log "✅ Podman $VERSION installed successfully"
    log ""
    log "Quick test: podman run --rm docker.io/library/hello-world"
    log "Run containers: bash scripts/run.sh run --name test --image nginx:alpine --port 8080:80"
else
    error "❌ Installation failed"
    exit 1
fi
