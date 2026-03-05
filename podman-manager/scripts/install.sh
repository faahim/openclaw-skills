#!/bin/bash
# Podman Manager — Install Script
# Installs Podman and configures rootless container runtime
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

# Detect OS
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID}"
    OS_VERSION="${VERSION_ID:-}"
    OS_LIKE="${ID_LIKE:-$ID}"
  elif [ "$(uname)" = "Darwin" ]; then
    OS_ID="macos"
    OS_LIKE="macos"
  else
    err "Unsupported OS"
    exit 1
  fi
}

# Check if podman is already installed
check_existing() {
  if command -v podman &>/dev/null; then
    local ver
    ver=$(podman --version 2>/dev/null | awk '{print $NF}')
    warn "Podman $ver is already installed"
    read -rp "Reinstall/upgrade? [y/N] " ans
    [[ "$ans" =~ ^[Yy] ]] || { log "Keeping existing installation"; exit 0; }
  fi
}

# Install on Debian/Ubuntu
install_debian() {
  log "Installing Podman on Debian/Ubuntu..."
  
  # Ubuntu 24.04+ and Debian 12+ have podman in repos
  sudo apt-get update -qq
  sudo apt-get install -y -qq podman fuse-overlayfs slirp4netns uidmap 2>/dev/null || {
    # Fallback: add kubic repo for older distros
    warn "Adding Kubic repository for older distro..."
    local os_ver="${OS_ID}_${OS_VERSION}"
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/${os_ver}/ /" \
      | sudo tee /etc/apt/sources.list.d/podman.list
    curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/${os_ver}/Release.key" \
      | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/podman.gpg
    sudo apt-get update -qq
    sudo apt-get install -y -qq podman fuse-overlayfs slirp4netns uidmap
  }
}

# Install on Fedora/RHEL/CentOS
install_fedora() {
  log "Installing Podman on Fedora/RHEL..."
  sudo dnf install -y podman fuse-overlayfs slirp4netns
}

# Install on Arch
install_arch() {
  log "Installing Podman on Arch Linux..."
  sudo pacman -Sy --noconfirm podman fuse-overlayfs slirp4netns
}

# Install on macOS
install_macos() {
  log "Installing Podman on macOS..."
  if command -v brew &>/dev/null; then
    brew install podman
    log "Initializing Podman machine..."
    podman machine init --cpus 2 --memory 2048 --disk-size 20
    podman machine start
  else
    err "Homebrew required. Install from https://brew.sh"
    exit 1
  fi
}

# Configure rootless
configure_rootless() {
  log "Configuring rootless containers..."
  
  # Ensure subuid/subgid
  if ! grep -q "^$(whoami):" /etc/subuid 2>/dev/null; then
    sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$(whoami)" 2>/dev/null || true
    log "Configured subuid/subgid ranges"
  fi
  
  # Create config directories
  mkdir -p ~/.config/containers
  
  # Set up registries (search Docker Hub, GitHub, Quay by default)
  if [ ! -f ~/.config/containers/registries.conf ]; then
    cat > ~/.config/containers/registries.conf << 'REGEOF'
unqualified-search-registries = ["docker.io", "ghcr.io", "quay.io"]
REGEOF
    log "Created registries.conf"
  fi
  
  # Storage config for rootless
  if [ ! -f ~/.config/containers/storage.conf ]; then
    cat > ~/.config/containers/storage.conf << 'STOREOF'
[storage]
driver = "overlay"

[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
STOREOF
    log "Created storage.conf"
  fi
  
  # Enable lingering for systemd user services
  if command -v loginctl &>/dev/null; then
    loginctl enable-linger "$(whoami)" 2>/dev/null || true
    log "Enabled systemd linger (containers survive logout)"
  fi
}

# Verify installation
verify() {
  echo ""
  log "Podman installed successfully!"
  echo ""
  podman --version
  echo ""
  
  # Quick test
  log "Running test container..."
  if podman run --rm docker.io/library/alpine echo "Hello from Podman!" 2>/dev/null; then
    log "Container runtime working correctly"
  else
    warn "Test container failed — check 'podman info' for details"
  fi
  
  echo ""
  log "Rootless status:"
  podman info --format '  Rootless: {{.Host.Security.Rootless}}'
  podman info --format '  Storage driver: {{.Store.GraphDriverName}}'
  podman info --format '  Storage root: {{.Store.GraphRoot}}'
  echo ""
  log "Ready! Try: podman run -d --name test -p 8080:80 nginx"
}

# Main
main() {
  echo "🐙 Podman Manager — Installation"
  echo "================================="
  echo ""
  
  detect_os
  check_existing
  
  case "$OS_ID" in
    ubuntu|debian|pop|linuxmint) install_debian ;;
    fedora|rhel|centos|rocky|alma) install_fedora ;;
    arch|manjaro|endeavouros) install_arch ;;
    macos) install_macos ;;
    *)
      if [[ "$OS_LIKE" == *"debian"* ]]; then
        install_debian
      elif [[ "$OS_LIKE" == *"fedora"* ]] || [[ "$OS_LIKE" == *"rhel"* ]]; then
        install_fedora
      else
        err "Unsupported distro: $OS_ID"
        err "Install manually: https://podman.io/docs/installation"
        exit 1
      fi
      ;;
  esac
  
  configure_rootless
  verify
}

main "$@"
