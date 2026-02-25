#!/bin/bash
# GoAccess Web Log Analyzer — Installation Script
# Installs GoAccess with GeoIP support on Linux/macOS

set -euo pipefail

echo "🔍 Detecting operating system..."

install_debian() {
    echo "📦 Installing GoAccess on Debian/Ubuntu..."
    # Add official GoAccess repo for latest version
    if ! command -v goaccess &>/dev/null; then
        echo "deb https://deb.goaccess.io/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/goaccess.list
        wget -O - https://deb.goaccess.io/gnupg.key 2>/dev/null | sudo gpg --dearmor -o /etc/apt/keyrings/goaccess.gpg 2>/dev/null || true
        sudo apt-get update -qq
        sudo apt-get install -y -qq goaccess libmaxminddb0 libmaxminddb-dev mmdb-bin 2>/dev/null || \
            sudo apt-get install -y -qq goaccess
    fi
}

install_rhel() {
    echo "📦 Installing GoAccess on RHEL/CentOS/Fedora..."
    if ! command -v goaccess &>/dev/null; then
        sudo yum install -y epel-release 2>/dev/null || true
        sudo yum install -y goaccess
    fi
}

install_alpine() {
    echo "📦 Installing GoAccess on Alpine..."
    if ! command -v goaccess &>/dev/null; then
        sudo apk add goaccess
    fi
}

install_arch() {
    echo "📦 Installing GoAccess on Arch Linux..."
    if ! command -v goaccess &>/dev/null; then
        sudo pacman -Sy --noconfirm goaccess
    fi
}

install_macos() {
    echo "📦 Installing GoAccess on macOS..."
    if ! command -v goaccess &>/dev/null; then
        if command -v brew &>/dev/null; then
            brew install goaccess
        else
            echo "❌ Homebrew not found. Install it first: https://brew.sh"
            exit 1
        fi
    fi
}

install_from_source() {
    echo "📦 Building GoAccess from source..."
    local VERSION="1.9.3"
    local TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    curl -sL "https://tar.goaccess.io/goaccess-${VERSION}.tar.gz" | tar xz
    cd "goaccess-${VERSION}"
    ./configure --enable-utf8 --enable-geoip=mmdb 2>/dev/null || \
        ./configure --enable-utf8
    make -j$(nproc 2>/dev/null || echo 2)
    sudo make install
    cd /
    rm -rf "$TMP_DIR"
}

# Detect OS and install
if [[ "$OSTYPE" == "darwin"* ]]; then
    install_macos
elif [ -f /etc/debian_version ]; then
    install_debian
elif [ -f /etc/redhat-release ]; then
    install_rhel
elif [ -f /etc/alpine-release ]; then
    install_alpine
elif [ -f /etc/arch-release ]; then
    install_arch
else
    echo "⚠️  Unknown OS. Attempting source build..."
    install_from_source
fi

# Verify installation
if command -v goaccess &>/dev/null; then
    VERSION=$(goaccess --version 2>&1 | head -1)
    echo "✅ GoAccess installed: $VERSION"
else
    echo "❌ Installation failed. Trying source build as fallback..."
    install_from_source
    if command -v goaccess &>/dev/null; then
        echo "✅ GoAccess installed from source"
    else
        echo "❌ Could not install GoAccess. Please install manually."
        exit 1
    fi
fi

# Create config directory
mkdir -p ~/.goaccess
echo "✅ Config directory: ~/.goaccess"
echo ""
echo "🎉 GoAccess is ready! Try:"
echo "   bash scripts/analyze.sh --log /var/log/nginx/access.log --format COMBINED --terminal"
