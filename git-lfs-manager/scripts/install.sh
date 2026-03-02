#!/bin/bash
set -euo pipefail

# Git LFS Manager — Install Script
# Detects OS and installs git-lfs

echo "🔧 Git LFS Manager — Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if already installed
if command -v git-lfs &>/dev/null; then
    VERSION=$(git-lfs --version 2>/dev/null | head -1)
    echo "✅ Git LFS already installed: $VERSION"
    git lfs install --skip-smudge 2>/dev/null || git lfs install
    echo "✅ Git LFS hooks installed"
    exit 0
fi

echo "📦 Installing Git LFS..."

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-$OS_ID}"
elif [[ "$(uname)" == "Darwin" ]]; then
    OS_ID="macos"
    OS_LIKE="macos"
else
    OS_ID="unknown"
    OS_LIKE="unknown"
fi

install_success=false

case "$OS_ID" in
    ubuntu|debian|pop|linuxmint|elementary)
        echo "  Detected: Debian/Ubuntu-based ($OS_ID)"
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y -qq git-lfs
            install_success=true
        fi
        ;;
    fedora|rhel|centos|rocky|alma)
        echo "  Detected: RHEL/Fedora-based ($OS_ID)"
        if command -v dnf &>/dev/null; then
            sudo dnf install -y git-lfs
            install_success=true
        elif command -v yum &>/dev/null; then
            sudo yum install -y git-lfs
            install_success=true
        fi
        ;;
    arch|manjaro|endeavouros)
        echo "  Detected: Arch-based ($OS_ID)"
        if command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm git-lfs
            install_success=true
        fi
        ;;
    alpine)
        echo "  Detected: Alpine"
        sudo apk add git-lfs
        install_success=true
        ;;
    opensuse*|sles)
        echo "  Detected: openSUSE/SLES"
        sudo zypper install -y git-lfs
        install_success=true
        ;;
    macos)
        echo "  Detected: macOS"
        if command -v brew &>/dev/null; then
            brew install git-lfs
            install_success=true
        else
            echo "❌ Homebrew not found. Install it first: https://brew.sh"
            exit 1
        fi
        ;;
    *)
        # Try ID_LIKE fallback
        if [[ "$OS_LIKE" == *debian* ]] || [[ "$OS_LIKE" == *ubuntu* ]]; then
            echo "  Detected: Debian-like ($OS_ID)"
            sudo apt-get update -qq
            sudo apt-get install -y -qq git-lfs
            install_success=true
        elif [[ "$OS_LIKE" == *rhel* ]] || [[ "$OS_LIKE" == *fedora* ]]; then
            echo "  Detected: RHEL-like ($OS_ID)"
            sudo dnf install -y git-lfs 2>/dev/null || sudo yum install -y git-lfs
            install_success=true
        fi
        ;;
esac

if [[ "$install_success" != "true" ]]; then
    echo "⚠️  Could not auto-install. Trying packagecloud script..."
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
    sudo apt-get install -y git-lfs
fi

# Initialize
git lfs install
echo ""
echo "✅ Git LFS installed successfully!"
git-lfs --version
echo "✅ Git LFS hooks configured"
