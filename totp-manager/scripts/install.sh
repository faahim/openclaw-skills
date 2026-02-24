#!/bin/bash
# TOTP Manager — Install Dependencies
set -e

echo "🔐 TOTP Manager — Installing dependencies..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
elif [ "$(uname)" = "Darwin" ]; then
    OS="macos"
else
    OS="unknown"
fi

install_oathtool() {
    case "$OS" in
        ubuntu|debian|pop|linuxmint)
            echo "📦 Installing oathtool via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq oathtool jq gnupg2
            ;;
        fedora|rhel|centos|rocky|alma)
            echo "📦 Installing oathtool via dnf..."
            sudo dnf install -y oathtool jq gnupg2
            ;;
        arch|manjaro)
            echo "📦 Installing oath-toolkit via pacman..."
            sudo pacman -S --noconfirm oath-toolkit jq gnupg
            ;;
        alpine)
            echo "📦 Installing oathtool via apk..."
            sudo apk add oath-toolkit-oathtool jq gnupg
            ;;
        macos)
            echo "📦 Installing oath-toolkit via Homebrew..."
            brew install oath-toolkit jq gnupg
            ;;
        *)
            echo "❌ Unknown OS: $OS"
            echo "Please install manually: oathtool (oath-toolkit), jq, gpg"
            exit 1
            ;;
    esac
}

# Check if already installed
if command -v oathtool &>/dev/null; then
    echo "✅ oathtool already installed: $(oathtool --version 2>&1 | head -1)"
else
    install_oathtool
fi

# Verify
if ! command -v oathtool &>/dev/null; then
    echo "❌ oathtool installation failed"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "⚠️  jq not found — install it for JSON support"
fi

# Create config directory
STORE="${TOTP_STORE:-$HOME/.config/totp-manager}"
mkdir -p "$STORE"
chmod 700 "$STORE"

# Initialize empty secrets file if not exists
if [ ! -f "$STORE/secrets.json" ] && [ ! -f "$STORE/secrets.enc" ]; then
    echo '{"secrets":{}}' > "$STORE/secrets.json"
    chmod 600 "$STORE/secrets.json"
    echo "📁 Created secret store at $STORE/secrets.json"
fi

echo ""
echo "✅ TOTP Manager installed successfully!"
echo "   Store: $STORE"
echo "   Run: bash scripts/run.sh add --name <service> --secret <base32-secret>"
