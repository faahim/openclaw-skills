#!/bin/bash
# Disk Usage Analyzer — Dependency Installer
set -e

echo "📦 Installing disk analysis tools..."

OS="$(uname -s)"
ARCH="$(uname -m)"

install_duf() {
    if command -v duf &>/dev/null; then
        echo "  ✅ duf already installed ($(duf --version 2>&1 | head -1))"
        return 0
    fi

    echo "  📥 Installing duf..."
    if command -v apt-get &>/dev/null; then
        # Try apt first (Ubuntu 22.04+, Debian 12+)
        if sudo apt-get install -y duf 2>/dev/null; then return 0; fi
        # Fallback: download binary
        DUF_VERSION="0.8.1"
        case "$ARCH" in
            x86_64|amd64) DUF_ARCH="amd64" ;;
            aarch64|arm64) DUF_ARCH="arm64" ;;
            armv7l) DUF_ARCH="armv7" ;;
            *) echo "  ❌ Unsupported architecture: $ARCH"; return 1 ;;
        esac
        curl -sLo /tmp/duf.deb "https://github.com/muesli/duf/releases/download/v${DUF_VERSION}/duf_${DUF_VERSION}_linux_${DUF_ARCH}.deb"
        sudo dpkg -i /tmp/duf.deb && rm /tmp/duf.deb
    elif command -v brew &>/dev/null; then
        brew install duf
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm duf
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y duf
    else
        echo "  ⚠️  Could not auto-install duf. Install manually: https://github.com/muesli/duf"
        return 1
    fi
    echo "  ✅ duf installed"
}

install_dust() {
    if command -v dust &>/dev/null; then
        echo "  ✅ dust already installed"
        return 0
    fi

    echo "  📥 Installing dust..."
    if command -v brew &>/dev/null; then
        brew install dust
    elif command -v cargo &>/dev/null; then
        cargo install du-dust
    else
        # Download binary
        DUST_VERSION="1.1.1"
        case "$ARCH" in
            x86_64|amd64) DUST_TARGET="x86_64-unknown-linux-musl" ;;
            aarch64|arm64) DUST_TARGET="aarch64-unknown-linux-musl" ;;
            *) echo "  ❌ Unsupported architecture: $ARCH"; return 1 ;;
        esac
        curl -sLo /tmp/dust.tar.gz "https://github.com/bootandy/dust/releases/download/v${DUST_VERSION}/dust-v${DUST_VERSION}-${DUST_TARGET}.tar.gz"
        tar xzf /tmp/dust.tar.gz -C /tmp/
        sudo mv /tmp/dust-v${DUST_VERSION}-${DUST_TARGET}/dust /usr/local/bin/
        rm -rf /tmp/dust* 
    fi
    echo "  ✅ dust installed"
}

install_ncdu() {
    if command -v ncdu &>/dev/null; then
        echo "  ✅ ncdu already installed ($(ncdu --version 2>&1 | head -1))"
        return 0
    fi

    echo "  📥 Installing ncdu..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y ncdu
    elif command -v brew &>/dev/null; then
        brew install ncdu
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm ncdu
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y ncdu
    else
        echo "  ⚠️  Could not auto-install ncdu. Install manually: https://dev.yorhel.nl/ncdu"
        return 1
    fi
    echo "  ✅ ncdu installed"
}

install_duf
install_dust
install_ncdu

echo ""
echo "✅ All disk analysis tools installed!"
echo ""
echo "Quick test:"
echo "  duf           # Disk overview"
echo "  dust /home    # Directory sizes"
echo "  ncdu /home    # Interactive explorer"
