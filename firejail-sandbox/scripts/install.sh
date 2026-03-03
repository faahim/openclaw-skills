#!/bin/bash
# Install Firejail application sandbox
set -e

echo "🔒 Firejail Sandbox — Installer"
echo "================================"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Cannot detect OS. Install firejail manually."
    exit 1
fi

# Install firejail
case "$OS" in
    ubuntu|debian|pop|linuxmint|elementary)
        echo "📦 Installing via apt..."
        sudo apt-get update -qq
        sudo apt-get install -y firejail firejail-profiles
        ;;
    fedora)
        echo "📦 Installing via dnf..."
        sudo dnf install -y firejail
        ;;
    centos|rhel|rocky|alma)
        echo "📦 Installing via yum..."
        sudo yum install -y epel-release
        sudo yum install -y firejail
        ;;
    arch|manjaro|endeavouros)
        echo "📦 Installing via pacman..."
        sudo pacman -Sy --noconfirm firejail
        ;;
    opensuse*|sles)
        echo "📦 Installing via zypper..."
        sudo zypper install -y firejail
        ;;
    *)
        echo "⚠️  Unknown OS: $OS"
        echo "Try: sudo apt install firejail OR sudo dnf install firejail"
        exit 1
        ;;
esac

# Verify installation
if ! command -v firejail &>/dev/null; then
    echo "❌ Firejail installation failed"
    exit 1
fi

# Check SUID bit
if [ ! -u /usr/bin/firejail ]; then
    echo "⚠️  Setting SUID bit on firejail..."
    sudo chmod 4755 /usr/bin/firejail
fi

# Create user config directory
mkdir -p ~/.config/firejail

# Show version
VERSION=$(firejail --version | head -1)
PROFILES=$(ls /etc/firejail/*.profile 2>/dev/null | wc -l)

echo ""
echo "✅ Firejail installed successfully!"
echo "   Version: $VERSION"
echo "   Built-in profiles: $PROFILES"
echo "   User profiles: ~/.config/firejail/"
echo ""
echo "Quick test:"
echo "   firejail --private echo 'Hello from sandbox!'"
echo ""
echo "Sandbox a browser:"
echo "   firejail firefox"
echo ""
echo "Run untrusted code:"
echo "   firejail --net=none --private bash script.sh"
