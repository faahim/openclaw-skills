#!/bin/bash
# Install tmate for terminal session sharing
set -e

echo "🔧 Installing tmate..."

# Detect OS and install
if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq tmate
elif command -v dnf &>/dev/null; then
    sudo dnf install -y tmate
elif command -v yum &>/dev/null; then
    sudo yum install -y tmate
elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm tmate
elif command -v brew &>/dev/null; then
    brew install tmate
elif command -v apk &>/dev/null; then
    sudo apk add tmate
else
    echo "❌ Unsupported package manager. Install tmate manually:"
    echo "   https://tmate.io/#installation"
    exit 1
fi

# Verify
if command -v tmate &>/dev/null; then
    echo "✅ tmate installed: $(tmate -V)"
else
    echo "❌ Installation failed. Try manual install: https://tmate.io/#installation"
    exit 1
fi
