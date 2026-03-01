#!/bin/bash
# Umami Analytics — Dependency Installer
set -euo pipefail

ACTION="${1:-check}"

check_docker() {
  if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+\.\d+')
    echo "✅ Docker installed: v$DOCKER_VERSION"
    return 0
  else
    echo "❌ Docker not installed"
    return 1
  fi
}

check_compose() {
  if docker compose version &>/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
    echo "✅ Docker Compose installed: v$COMPOSE_VERSION"
    return 0
  elif command -v docker-compose &>/dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | grep -oP '\d+\.\d+\.\d+')
    echo "✅ Docker Compose (standalone) installed: v$COMPOSE_VERSION"
    return 0
  else
    echo "❌ Docker Compose not installed"
    return 1
  fi
}

check_deps() {
  local all_ok=true
  check_docker || all_ok=false
  check_compose || all_ok=false

  for cmd in curl jq; do
    if command -v "$cmd" &>/dev/null; then
      echo "✅ $cmd installed"
    else
      echo "❌ $cmd not installed"
      all_ok=false
    fi
  done

  if $all_ok; then
    echo ""
    echo "🎉 All dependencies satisfied!"
    return 0
  else
    echo ""
    echo "⚠️  Some dependencies missing. Run: bash scripts/install.sh docker"
    return 1
  fi
}

install_docker() {
  echo "🐳 Installing Docker..."

  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
      ubuntu|debian)
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL "https://download.docker.com/linux/$ID/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ;;
      fedora|centos|rhel)
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo systemctl start docker
        sudo systemctl enable docker
        ;;
      *)
        echo "❌ Unsupported distro: $ID"
        echo "   Install Docker manually: https://docs.docker.com/engine/install/"
        exit 1
        ;;
    esac
  elif [[ "$(uname)" == "Darwin" ]]; then
    echo "❌ macOS detected. Install Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
    exit 1
  else
    echo "❌ Unknown OS. Install Docker manually: https://docs.docker.com/engine/install/"
    exit 1
  fi

  # Add current user to docker group
  if ! groups | grep -q docker; then
    sudo usermod -aG docker "$USER"
    echo "⚠️  Added $USER to docker group. Log out and back in, or run: newgrp docker"
  fi

  # Install jq if missing
  if ! command -v jq &>/dev/null; then
    echo "📦 Installing jq..."
    sudo apt-get install -y jq 2>/dev/null || sudo dnf install -y jq 2>/dev/null || true
  fi

  echo ""
  echo "✅ Docker installed successfully!"
  check_deps
}

case "$ACTION" in
  check) check_deps ;;
  docker) install_docker ;;
  *)
    echo "Usage: bash scripts/install.sh [check|docker]"
    exit 1
    ;;
esac
