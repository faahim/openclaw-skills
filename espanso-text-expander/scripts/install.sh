#!/bin/bash
set -euo pipefail

echo "🔤 Espanso Text Expander — Installer"
echo "======================================"

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

install_linux() {
    echo "📦 Detected Linux ($ARCH)"
    
    # Check if already installed
    if command -v espanso &>/dev/null; then
        CURRENT=$(espanso --version 2>/dev/null || echo "unknown")
        echo "✅ Espanso already installed: $CURRENT"
        read -p "Reinstall/update? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi

    # Try snap first (most common)
    if command -v snap &>/dev/null; then
        echo "📦 Installing via snap..."
        sudo snap install espanso --classic --channel=latest/edge 2>/dev/null || true
        if command -v espanso &>/dev/null; then
            echo "✅ Installed via snap"
            return 0
        fi
    fi

    # Try downloading binary
    echo "📦 Downloading Espanso binary..."
    
    case "$ARCH" in
        x86_64|amd64)
            DEB_URL="https://github.com/espanso/espanso/releases/latest/download/espanso-debian-x11-amd64.deb"
            ;;
        aarch64|arm64)
            echo "⚠️  No official ARM64 binary. Trying to build from source..."
            install_from_source
            return $?
            ;;
        *)
            echo "❌ Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    # Try .deb package
    if command -v dpkg &>/dev/null; then
        TMPFILE=$(mktemp /tmp/espanso-XXXXX.deb)
        curl -fsSL "$DEB_URL" -o "$TMPFILE" 2>/dev/null
        if [ -s "$TMPFILE" ]; then
            sudo dpkg -i "$TMPFILE" || sudo apt-get install -f -y
            rm -f "$TMPFILE"
            echo "✅ Installed via .deb"
            return 0
        fi
        rm -f "$TMPFILE"
    fi

    # Try AppImage
    echo "📦 Trying AppImage..."
    APPIMAGE_URL="https://github.com/espanso/espanso/releases/latest/download/Espanso-X11.AppImage"
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    curl -fsSL "$APPIMAGE_URL" -o "$INSTALL_DIR/espanso" 2>/dev/null
    chmod +x "$INSTALL_DIR/espanso"
    
    if [ -x "$INSTALL_DIR/espanso" ]; then
        echo "✅ Installed AppImage to $INSTALL_DIR/espanso"
        echo "   Make sure $INSTALL_DIR is in your PATH"
        return 0
    fi

    echo "❌ Could not install automatically."
    echo "   Visit: https://espanso.org/install/"
    exit 1
}

install_from_source() {
    echo "🔧 Building Espanso from source..."
    
    if ! command -v cargo &>/dev/null; then
        echo "📦 Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    # Install build deps
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y libx11-dev libxtst-dev libxkbcommon-dev \
            libdbus-1-dev libwxgtk3.0-gtk3-dev 2>/dev/null || true
    fi

    cargo install espanso --force 2>/dev/null || {
        echo "❌ Build failed. Visit: https://espanso.org/install/"
        exit 1
    }
    echo "✅ Built from source"
}

install_macos() {
    echo "🍎 Detected macOS ($ARCH)"
    
    if command -v espanso &>/dev/null; then
        CURRENT=$(espanso --version 2>/dev/null || echo "unknown")
        echo "✅ Espanso already installed: $CURRENT"
        read -p "Reinstall/update? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi

    if command -v brew &>/dev/null; then
        echo "📦 Installing via Homebrew..."
        brew install espanso
        echo "✅ Installed via Homebrew"
    else
        echo "📦 Downloading from GitHub..."
        curl -fsSL "https://github.com/espanso/espanso/releases/latest/download/Espanso-Mac-Intel.dmg" -o /tmp/espanso.dmg
        echo "📦 Downloaded to /tmp/espanso.dmg — please open and install manually"
        open /tmp/espanso.dmg 2>/dev/null || true
    fi
}

case "$OS" in
    Linux)  install_linux ;;
    Darwin) install_macos ;;
    *)
        echo "❌ Unsupported OS: $OS"
        echo "   Visit: https://espanso.org/install/"
        exit 1
        ;;
esac

# Verify
if command -v espanso &>/dev/null; then
    echo ""
    echo "✅ Espanso $(espanso --version 2>/dev/null || echo '') installed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Start espanso:  espanso start"
    echo "  2. Add a snippet:  bash scripts/add-snippet.sh ':email' 'you@example.com'"
    echo "  3. Import starters: bash scripts/import-pack.sh starter"
else
    echo "⚠️  Installation completed but 'espanso' not found in PATH."
    echo "   You may need to restart your shell or add ~/.local/bin to PATH."
fi
