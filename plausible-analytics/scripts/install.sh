#!/bin/bash
# Plausible Analytics — Dependency checker and installer
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_deps() {
    local missing=0
    echo "🔍 Checking dependencies..."
    
    for cmd in docker curl openssl jq; do
        if command -v "$cmd" &>/dev/null; then
            echo -e "  ${GREEN}✅${NC} $cmd $(command -v "$cmd")"
        else
            echo -e "  ${RED}❌${NC} $cmd — NOT FOUND"
            missing=1
        fi
    done
    
    # Check docker compose (v2)
    if docker compose version &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} docker compose $(docker compose version --short 2>/dev/null)"
    elif docker-compose version &>/dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠️${NC}  docker-compose (v1) found — v2 recommended"
    else
        echo -e "  ${RED}❌${NC} docker compose — NOT FOUND"
        missing=1
    fi
    
    # Check Docker daemon
    if docker info &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} Docker daemon running"
    else
        echo -e "  ${RED}❌${NC} Docker daemon not running (try: sudo systemctl start docker)"
        missing=1
    fi
    
    if [ $missing -eq 0 ]; then
        echo -e "\n${GREEN}All dependencies satisfied!${NC}"
        return 0
    else
        echo -e "\n${RED}Missing dependencies. Run: bash scripts/install.sh --install-deps${NC}"
        return 1
    fi
}

install_deps() {
    echo "📦 Installing dependencies..."
    
    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ Cannot detect OS. Install Docker manually: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            echo "→ Detected $OS"
            sudo apt-get update -qq
            sudo apt-get install -y -qq curl openssl jq ca-certificates gnupg
            
            # Docker official repo
            if ! command -v docker &>/dev/null; then
                echo "→ Installing Docker..."
                sudo install -m 0755 -d /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                sudo chmod a+r /etc/apt/keyrings/docker.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update -qq
                sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
                sudo systemctl enable docker
                sudo systemctl start docker
                echo -e "${GREEN}✅ Docker installed${NC}"
            fi
            ;;
        fedora|centos|rhel)
            echo "→ Detected $OS"
            sudo dnf install -y curl openssl jq
            if ! command -v docker &>/dev/null; then
                sudo dnf install -y dnf-plugins-core
                sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                sudo systemctl enable docker
                sudo systemctl start docker
            fi
            ;;
        *)
            echo "⚠️ Unsupported OS: $OS. Install Docker manually: https://docs.docker.com/engine/install/"
            sudo apt-get install -y curl openssl jq 2>/dev/null || true
            ;;
    esac
    
    # Add current user to docker group
    if ! groups | grep -q docker; then
        sudo usermod -aG docker "$USER"
        echo -e "${YELLOW}⚠️ Added $USER to docker group. Log out and back in, or run: newgrp docker${NC}"
    fi
    
    echo -e "\n${GREEN}✅ Dependencies installed!${NC}"
    check_deps
}

case "${1:-}" in
    --check) check_deps ;;
    --install-deps) install_deps ;;
    *)
        echo "Usage: bash scripts/install.sh [--check|--install-deps]"
        echo "  --check         Check if all dependencies are installed"
        echo "  --install-deps  Install missing dependencies"
        ;;
esac
