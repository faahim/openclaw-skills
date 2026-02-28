#!/bin/bash
# Install Atuin shell history manager
set -e

echo "🔍 Checking for existing Atuin installation..."
if command -v atuin &>/dev/null; then
    CURRENT_VERSION=$(atuin --version 2>/dev/null | head -1)
    echo "✅ Atuin already installed: $CURRENT_VERSION"
    read -p "Reinstall/update? (y/N): " REPLY
    [[ "$REPLY" =~ ^[Yy]$ ]] || { echo "Keeping current installation."; exit 0; }
fi

echo "📦 Installing Atuin..."

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Use official install script
if command -v curl &>/dev/null; then
    bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)
elif command -v wget &>/dev/null; then
    bash <(wget -qO- https://setup.atuin.sh)
else
    echo "❌ Neither curl nor wget found. Install one first."
    exit 1
fi

# Verify installation
if command -v atuin &>/dev/null; then
    echo ""
    echo "✅ Atuin installed successfully!"
    atuin --version
    echo ""
    echo "Next steps:"
    echo "  1. Run: bash scripts/setup-shell.sh $(basename $SHELL)"
    echo "  2. Run: atuin import auto"
    echo "  3. Restart your shell: exec \$SHELL"
else
    echo "❌ Installation failed. Try manual install:"
    echo "   cargo install atuin"
    echo "   OR"
    echo "   brew install atuin"
    exit 1
fi
