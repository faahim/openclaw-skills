#!/bin/bash
# Timeshift Installer — detects distro and installs Timeshift
set -e

echo "🔧 Installing Timeshift System Backup..."

# Detect package manager
if command -v apt-get &>/dev/null; then
    echo "📦 Detected Debian/Ubuntu — installing via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y timeshift
elif command -v dnf &>/dev/null; then
    echo "📦 Detected Fedora/RHEL — installing via dnf..."
    sudo dnf install -y timeshift
elif command -v pacman &>/dev/null; then
    echo "📦 Detected Arch Linux — installing via pacman..."
    sudo pacman -S --noconfirm timeshift
elif command -v zypper &>/dev/null; then
    echo "📦 Detected openSUSE — installing via zypper..."
    sudo zypper install -y timeshift
else
    echo "❌ Unsupported package manager. Install timeshift manually:"
    echo "   https://github.com/linuxmint/timeshift"
    exit 1
fi

# Verify installation
if command -v timeshift &>/dev/null; then
    VERSION=$(timeshift --version 2>/dev/null || echo "unknown")
    echo "✅ Timeshift installed successfully! Version: $VERSION"
    echo ""
    echo "Next steps:"
    echo "  1. Create first snapshot: bash scripts/run.sh --create --comment 'Initial'"
    echo "  2. Enable schedule:       bash scripts/run.sh --schedule --daily 7 --weekly 4"
else
    echo "❌ Installation failed. Check errors above."
    exit 1
fi
