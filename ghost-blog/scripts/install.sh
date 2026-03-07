#!/bin/bash
# Ghost Blog Manager — Install Dependencies
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[ghost-blog]${NC} $1"; }
warn() { echo -e "${YELLOW}[ghost-blog]${NC} $1"; }
err() { echo -e "${RED}[ghost-blog]${NC} $1" >&2; }

check_docker() {
    if command -v docker &>/dev/null; then
        local ver=$(docker --version | grep -oP '\d+\.\d+' | head -1)
        log "Docker found: v$ver"
        return 0
    fi
    return 1
}

check_compose() {
    if docker compose version &>/dev/null 2>&1; then
        log "Docker Compose v2 found"
        return 0
    elif command -v docker-compose &>/dev/null; then
        log "Docker Compose v1 found (v2 recommended)"
        return 0
    fi
    return 1
}

install_docker() {
    log "Installing Docker..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|pop|linuxmint|raspbian)
                curl -fsSL https://get.docker.com | sudo sh
                sudo usermod -aG docker "$USER"
                ;;
            fedora|rhel|centos|rocky|alma)
                sudo dnf install -y dnf-plugins-core
                sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || true
                sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                sudo systemctl enable --now docker
                sudo usermod -aG docker "$USER"
                ;;
            arch|manjaro)
                sudo pacman -Sy --noconfirm docker docker-compose
                sudo systemctl enable --now docker
                sudo usermod -aG docker "$USER"
                ;;
            *)
                err "Auto-install not supported for $ID. Install Docker manually: https://docs.docker.com/engine/install/"
                exit 1
                ;;
        esac
    elif [ "$(uname)" = "Darwin" ]; then
        if command -v brew &>/dev/null; then
            brew install --cask docker
            log "Docker Desktop installed. Please start it from Applications."
        else
            err "Install Docker Desktop from https://docker.com/products/docker-desktop"
            exit 1
        fi
    fi
}

main() {
    log "=== Ghost Blog Manager — Dependency Check ==="

    if ! check_docker; then
        install_docker
    fi

    if ! check_compose; then
        warn "Docker Compose plugin not found. It should come with Docker."
        warn "Try: sudo apt install docker-compose-plugin"
    fi

    # Verify
    if check_docker && check_compose; then
        log "✅ All dependencies ready"
        log "Next: bash scripts/deploy.sh --domain blog.example.com --email you@example.com"
    else
        err "Some dependencies missing. Check above."
        exit 1
    fi
}

main "$@"
