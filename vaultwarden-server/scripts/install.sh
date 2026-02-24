#!/bin/bash
# Vaultwarden Server — Dependency Installer
set -euo pipefail

ACTION="${1:-check}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

check_cmd() { command -v "$1" &>/dev/null; }

check_deps() {
    echo "🔍 Checking dependencies..."
    local all_ok=true

    for cmd in docker curl openssl jq; do
        if check_cmd "$cmd"; then
            echo -e "  ${GREEN}✅${NC} $cmd: $(command -v $cmd)"
        else
            echo -e "  ${RED}❌${NC} $cmd: NOT FOUND"
            all_ok=false
        fi
    done

    # Check docker compose v2
    if docker compose version &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} docker compose: $(docker compose version --short 2>/dev/null || echo 'available')"
    else
        echo -e "  ${RED}❌${NC} docker compose v2: NOT FOUND"
        all_ok=false
    fi

    # Check if docker daemon is running
    if docker info &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} docker daemon: running"
    else
        echo -e "  ${YELLOW}⚠️${NC}  docker daemon: not running (start with 'sudo systemctl start docker')"
        all_ok=false
    fi

    if $all_ok; then
        echo -e "\n${GREEN}✅ All dependencies satisfied.${NC}"
        return 0
    else
        echo -e "\n${YELLOW}⚠️  Missing dependencies. Run: bash scripts/install.sh docker${NC}"
        return 1
    fi
}

install_docker() {
    echo "🐳 Installing Docker..."

    if check_cmd docker; then
        echo "Docker already installed."
    else
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    sudo apt-get update
                    sudo apt-get install -y ca-certificates curl gnupg
                    sudo install -m 0755 -d /etc/apt/keyrings
                    curl -fsSL "https://download.docker.com/linux/$ID/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                    sudo chmod a+r /etc/apt/keyrings/docker.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                    sudo apt-get update
                    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                    ;;
                fedora|centos|rhel)
                    sudo dnf -y install dnf-plugins-core
                    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                    ;;
                *)
                    echo "Unsupported OS: $ID. Install Docker manually: https://docs.docker.com/engine/install/"
                    exit 1
                    ;;
            esac
        elif [[ "$(uname)" == "Darwin" ]]; then
            echo "macOS detected. Install Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
            exit 1
        fi

        sudo systemctl enable --now docker
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        echo -e "${GREEN}✅ Docker installed. You may need to log out/in for group changes.${NC}"
    fi

    # Install other deps
    if check_cmd apt-get; then
        sudo apt-get install -y curl openssl jq
    elif check_cmd dnf; then
        sudo dnf install -y curl openssl jq
    fi

    echo -e "${GREEN}✅ All dependencies installed.${NC}"
}

case "$ACTION" in
    check) check_deps ;;
    docker) install_docker ;;
    *) echo "Usage: bash scripts/install.sh [check|docker]"; exit 1 ;;
esac
