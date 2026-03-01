#!/bin/bash
# UV Python Manager — Install Script
# Installs uv (the fast Python package manager by Astral)

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[uv-install]${NC} $*"; }
warn()  { echo -e "${YELLOW}[uv-install]${NC} $*"; }
error() { echo -e "${RED}[uv-install]${NC} $*" >&2; }

# Check if uv is already installed
if command -v uv &>/dev/null; then
    CURRENT=$(uv --version 2>/dev/null || echo "unknown")
    info "uv is already installed: $CURRENT"
    
    read -rp "Update to latest? [y/N] " update
    if [[ "$update" =~ ^[Yy]$ ]]; then
        info "Updating uv..."
        uv self update 2>/dev/null || {
            warn "Self-update failed, reinstalling..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
        }
        info "Updated to: $(uv --version)"
    fi
    exit 0
fi

# Install uv
info "Installing uv..."

if ! command -v curl &>/dev/null; then
    error "curl is required. Install it first:"
    error "  Ubuntu/Debian: sudo apt-get install curl"
    error "  Mac: brew install curl"
    exit 1
fi

curl -LsSf https://astral.sh/uv/install.sh | sh

# Ensure PATH is set
UV_BIN="$HOME/.local/bin"
if [[ ":$PATH:" != *":$UV_BIN:"* ]]; then
    warn "Adding $UV_BIN to PATH..."
    
    SHELL_RC=""
    if [[ -f "$HOME/.bashrc" ]]; then
        SHELL_RC="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ -f "$HOME/.profile" ]]; then
        SHELL_RC="$HOME/.profile"
    fi
    
    if [[ -n "$SHELL_RC" ]]; then
        if ! grep -q 'uv' "$SHELL_RC" 2>/dev/null; then
            echo '' >> "$SHELL_RC"
            echo '# uv - Python package manager' >> "$SHELL_RC"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
            info "Added to $SHELL_RC"
        fi
    fi
    
    export PATH="$UV_BIN:$PATH"
fi

# Verify
if command -v uv &>/dev/null; then
    info "✅ uv installed successfully: $(uv --version)"
    echo ""
    info "Quick start:"
    info "  uv python install 3.12    # Install Python 3.12"
    info "  uv init my-project        # Create a new project"
    info "  uv add requests           # Add a dependency"
    info "  uv run python main.py     # Run your code"
    info "  uvx ruff check .          # Run a tool without installing"
else
    error "Installation failed. Try manually:"
    error "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi
