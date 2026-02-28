#!/bin/bash
# Install Glances with all optional dependencies
set -e

echo "🔍 Checking Python3..."
if ! command -v python3 &>/dev/null; then
    echo "❌ Python3 not found. Installing..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv
    elif command -v brew &>/dev/null; then
        brew install python3
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y python3 python3-pip
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm python python-pip
    else
        echo "❌ Cannot detect package manager. Install python3 manually."
        exit 1
    fi
fi

echo "📦 Installing Glances..."
pip3 install --user --upgrade 'glances[all]' 2>/dev/null || \
pip3 install --user --upgrade glances

# Try installing optional extras individually (some may fail on certain platforms)
echo "📦 Installing optional plugins..."
pip3 install --user 'glances[web]' 2>/dev/null || echo "⚠️  Web plugin failed (bottle not available)"
pip3 install --user 'glances[docker]' 2>/dev/null || echo "⚠️  Docker plugin skipped"
pip3 install --user 'glances[export]' 2>/dev/null || echo "⚠️  Export plugins skipped"
pip3 install --user 'glances[sensors]' 2>/dev/null || echo "⚠️  Sensors plugin skipped"

# Create config directory
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/glances"
mkdir -p "$CONFIG_DIR"

# Verify installation
if command -v glances &>/dev/null; then
    VERSION=$(glances --version 2>&1 | head -1)
    echo ""
    echo "✅ Glances installed successfully!"
    echo "   Version: $VERSION"
    echo "   Config dir: $CONFIG_DIR"
    echo ""
    echo "Quick start:"
    echo "  Terminal:  glances"
    echo "  Web UI:    glances -w"
    echo "  With Docker: glances -w --enable-plugin docker"
else
    # Check if it's in user local bin
    USER_BIN="$HOME/.local/bin"
    if [ -f "$USER_BIN/glances" ]; then
        echo ""
        echo "✅ Glances installed at $USER_BIN/glances"
        echo "   Add to PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
    else
        echo "❌ Glances installation may have failed. Try: pip3 install glances"
        exit 1
    fi
fi
