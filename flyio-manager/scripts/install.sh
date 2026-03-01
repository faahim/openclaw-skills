#!/bin/bash
# Fly.io CLI (flyctl) installer
# Detects OS/arch, downloads latest, adds to PATH

set -euo pipefail

PREFIX="[flyio-manager]"

# Check if already installed
if command -v fly &>/dev/null; then
    CURRENT=$(fly version 2>/dev/null | head -1)
    echo "$PREFIX flyctl already installed: $CURRENT"
    read -p "Reinstall/update? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "$PREFIX Keeping current version."
        exit 0
    fi
fi

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l) ARCH="arm_7" ;;
    *) echo "$PREFIX Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
    linux) OS="Linux" ;;
    darwin) OS="macOS" ;;
    *) echo "$PREFIX Unsupported OS: $OS"; exit 1 ;;
esac

echo "$PREFIX Detected: $OS $ARCH"

# Install via official script
echo "$PREFIX Installing flyctl..."
curl -L https://fly.io/install.sh | sh

# Add to PATH if not already
FLYCTL_BIN="$HOME/.fly/bin"
if [[ -d "$FLYCTL_BIN" ]] && [[ ":$PATH:" != *":$FLYCTL_BIN:"* ]]; then
    echo "$PREFIX Adding $FLYCTL_BIN to PATH..."
    
    # Detect shell config
    SHELL_RC=""
    if [[ -f "$HOME/.bashrc" ]]; then
        SHELL_RC="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ -f "$HOME/.profile" ]]; then
        SHELL_RC="$HOME/.profile"
    fi

    if [[ -n "$SHELL_RC" ]]; then
        if ! grep -q "fly/bin" "$SHELL_RC" 2>/dev/null; then
            echo 'export FLYCTL_INSTALL="$HOME/.fly"' >> "$SHELL_RC"
            echo 'export PATH="$FLYCTL_INSTALL/bin:$PATH"' >> "$SHELL_RC"
            echo "$PREFIX Added to $SHELL_RC — run 'source $SHELL_RC' or start a new shell"
        fi
    fi
    
    export PATH="$FLYCTL_BIN:$PATH"
fi

# Verify
if command -v fly &>/dev/null; then
    echo "$PREFIX ✅ flyctl installed: $(fly version 2>/dev/null | head -1)"
else
    echo "$PREFIX ✅ Installed to $FLYCTL_BIN"
    echo "$PREFIX Run: export PATH=\"$FLYCTL_BIN:\$PATH\""
fi

echo ""
echo "$PREFIX Next: authenticate with 'fly auth login'"
echo "$PREFIX   Or set FLY_API_TOKEN for non-interactive use"
