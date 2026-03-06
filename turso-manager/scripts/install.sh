#!/bin/bash
# Turso CLI Installer
# Installs the official Turso CLI and verifies the installation

set -euo pipefail

TURSO_MIN_VERSION="0.90.0"

echo "🔧 Turso Database Manager — Installer"
echo "======================================="

# Check if turso is already installed
if command -v turso &>/dev/null; then
    CURRENT_VERSION=$(turso --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "unknown")
    echo "✅ Turso CLI already installed (v${CURRENT_VERSION})"
    echo "   To update: turso update"
    exit 0
fi

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)
        echo "❌ Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "📦 Installing Turso CLI for ${OS}/${ARCH}..."

# Install using official installer
if curl -sSfL https://get.tur.so/install.sh | bash; then
    echo ""
    
    # Reload PATH
    export PATH="$HOME/.turso:$PATH"
    
    if command -v turso &>/dev/null; then
        VERSION=$(turso --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "unknown")
        echo "✅ Turso CLI v${VERSION} installed successfully"
        echo ""
        echo "Next steps:"
        echo "  1. Authenticate:  turso auth login"
        echo "  2. Create a DB:   turso db create myapp"
        echo "  3. Or use:        bash scripts/turso-manage.sh create myapp"
        echo ""
        echo "💡 Add to PATH permanently:"
        echo '   echo "export PATH=\"\$HOME/.turso:\$PATH\"" >> ~/.bashrc'
    else
        echo "⚠️  Turso installed but not in PATH."
        echo "   Try: export PATH=\"\$HOME/.turso:\$PATH\""
    fi
else
    echo "❌ Installation failed."
    echo ""
    echo "Manual install:"
    echo "  curl -sSfL https://get.tur.so/install.sh | bash"
    echo ""
    echo "Or download from: https://github.com/tursodatabase/turso-cli/releases"
    exit 1
fi

# Install optional dependencies
echo ""
echo "📦 Checking optional dependencies..."

if ! command -v jq &>/dev/null; then
    echo "   ⚠️  jq not found (optional, for JSON formatting)"
    echo "      Install: sudo apt-get install jq  OR  brew install jq"
fi

if ! command -v sqlite3 &>/dev/null; then
    echo "   ⚠️  sqlite3 not found (optional, for local backup inspection)"
    echo "      Install: sudo apt-get install sqlite3  OR  brew install sqlite"
fi

echo ""
echo "🎉 Setup complete!"
