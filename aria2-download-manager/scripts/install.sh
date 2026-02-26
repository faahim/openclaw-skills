#!/bin/bash
# Install aria2 and configure defaults
set -e

echo "🔧 Installing aria2 download manager..."

# Detect OS and install
if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq aria2 jq
elif command -v apk &>/dev/null; then
    sudo apk add --quiet aria2 jq
elif command -v dnf &>/dev/null; then
    sudo dnf install -y -q aria2 jq
elif command -v yum &>/dev/null; then
    sudo yum install -y -q aria2 jq
elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm aria2 jq
elif command -v brew &>/dev/null; then
    brew install aria2 jq
else
    echo "❌ Unsupported package manager. Install aria2 manually."
    exit 1
fi

# Create config directory
mkdir -p ~/.aria2

# Create default config if it doesn't exist
if [ ! -f ~/.aria2/aria2.conf ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    cp "$SCRIPT_DIR/aria2.conf.template" ~/.aria2/aria2.conf
    echo "📝 Created default config at ~/.aria2/aria2.conf"
fi

# Create default download directory
mkdir -p ~/Downloads

# Create session file for resume support
touch ~/.aria2/aria2.session

echo "✅ aria2 installed successfully!"
echo "   Version: $(aria2c --version | head -1)"
echo "   Config:  ~/.aria2/aria2.conf"
echo "   Downloads: ~/Downloads"
