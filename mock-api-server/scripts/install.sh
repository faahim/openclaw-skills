#!/bin/bash
# Mock API Server — Installer
# Installs json-server and prism for mock API development

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

echo "🔧 Mock API Server — Installing dependencies..."
echo ""

# Check Node.js
if ! command -v node &>/dev/null; then
    error "Node.js not found. Install Node.js 18+ first:"
    echo "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
    echo "  sudo apt-get install -y nodejs"
    exit 1
fi

NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 18 ]; then
    error "Node.js 18+ required (found v$(node -v))"
    exit 1
fi
info "Node.js $(node -v) found"

# Install json-server (pinned to 0.17.x for stable REST API — v1.x changed API)
if command -v json-server &>/dev/null; then
    info "json-server already installed ($(json-server --version 2>/dev/null || echo 'unknown'))"
else
    echo "📦 Installing json-server..."
    npm install -g json-server@0.17.4
    info "json-server installed"
fi

# Install Prism (OpenAPI mock server) — optional
echo ""
read -p "Install Prism (OpenAPI mock server)? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v prism &>/dev/null; then
        info "Prism already installed"
    else
        echo "📦 Installing @stoplight/prism-cli..."
        npm install -g @stoplight/prism-cli
        info "Prism installed"
    fi
else
    warn "Skipping Prism (you can install later with: npm install -g @stoplight/prism-cli)"
fi

# Create working directory
MOCK_DIR="${MOCK_API_DIR:-$HOME/.mock-api-server}"
mkdir -p "$MOCK_DIR"/{data,logs,pids,scaffolds}
info "Working directory: $MOCK_DIR"

echo ""
echo "✅ Mock API Server installed!"
echo ""
echo "Quick start:"
echo "  bash scripts/mock.sh init my-api"
echo "  bash scripts/mock.sh start my-api"
echo ""
