#!/bin/bash
# Install Unbound DNS resolver
set -euo pipefail

echo "🔍 Detecting OS..."

install_unbound() {
    if command -v apt-get &>/dev/null; then
        echo "📦 Installing Unbound (Debian/Ubuntu)..."
        sudo apt-get update -qq
        sudo apt-get install -y unbound unbound-host dns-root-data
    elif command -v dnf &>/dev/null; then
        echo "📦 Installing Unbound (Fedora/RHEL)..."
        sudo dnf install -y unbound
    elif command -v yum &>/dev/null; then
        echo "📦 Installing Unbound (CentOS/RHEL)..."
        sudo yum install -y unbound
    elif command -v apk &>/dev/null; then
        echo "📦 Installing Unbound (Alpine)..."
        sudo apk add unbound
    elif command -v pacman &>/dev/null; then
        echo "📦 Installing Unbound (Arch)..."
        sudo pacman -S --noconfirm unbound
    elif command -v brew &>/dev/null; then
        echo "📦 Installing Unbound (macOS)..."
        brew install unbound
    else
        echo "❌ Unsupported OS. Install Unbound manually: https://nlnetlabs.nl/projects/unbound/download/"
        exit 1
    fi
}

download_root_hints() {
    echo "🌐 Downloading root hints..."
    local hints_dir="/etc/unbound"
    if [[ "$(uname)" == "Darwin" ]]; then
        hints_dir="$(brew --prefix)/etc/unbound"
    fi
    sudo mkdir -p "$hints_dir"
    sudo curl -sS -o "$hints_dir/root.hints" https://www.internic.net/domain/named.root
    echo "✅ Root hints saved to $hints_dir/root.hints"
}

# Check if already installed
if command -v unbound &>/dev/null; then
    echo "✅ Unbound is already installed: $(unbound -V 2>&1 | head -1)"
    echo "   Updating root hints..."
    download_root_hints
    exit 0
fi

install_unbound
download_root_hints

# Generate root key for DNSSEC
echo "🔐 Setting up DNSSEC trust anchor..."
if command -v unbound-anchor &>/dev/null; then
    sudo unbound-anchor -a /etc/unbound/root.key 2>/dev/null || true
fi

echo ""
echo "✅ Unbound installed successfully!"
echo "   Version: $(unbound -V 2>&1 | head -1)"
echo ""
echo "Next steps:"
echo "  1. Configure: sudo bash scripts/configure.sh --mode recursive"
echo "  2. Start: sudo systemctl enable --now unbound"
echo "  3. Set as DNS: sudo bash scripts/set-system-dns.sh"
