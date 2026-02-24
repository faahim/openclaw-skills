#!/bin/bash
# Bandwidth Monitor — Install Dependencies
set -e

echo "📡 Installing Bandwidth Monitor dependencies..."

# Detect package manager
if command -v apt-get &>/dev/null; then
    PKG_MGR="apt"
    INSTALL="sudo apt-get install -y"
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
    INSTALL="sudo yum install -y"
elif command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
    INSTALL="sudo dnf install -y"
elif command -v pacman &>/dev/null; then
    PKG_MGR="pacman"
    INSTALL="sudo pacman -S --noconfirm"
elif command -v brew &>/dev/null; then
    PKG_MGR="brew"
    INSTALL="brew install"
else
    echo "❌ No supported package manager found (apt/yum/dnf/pacman/brew)"
    exit 1
fi

echo "Using package manager: $PKG_MGR"

# Install vnstat
if ! command -v vnstat &>/dev/null; then
    echo "Installing vnstat..."
    $INSTALL vnstat
else
    echo "✅ vnstat already installed ($(vnstat --version 2>&1 | head -1))"
fi

# Install nethogs (optional, for per-process monitoring)
if ! command -v nethogs &>/dev/null; then
    echo "Installing nethogs..."
    $INSTALL nethogs 2>/dev/null || echo "⚠️  nethogs not available — per-process monitoring disabled"
else
    echo "✅ nethogs already installed"
fi

# Install jq if missing
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    $INSTALL jq
else
    echo "✅ jq already installed"
fi

# Enable and start vnstat daemon
if command -v systemctl &>/dev/null; then
    sudo systemctl enable vnstat 2>/dev/null || true
    sudo systemctl start vnstat 2>/dev/null || true
    echo "✅ vnstat daemon started"
elif command -v service &>/dev/null; then
    sudo service vnstat start 2>/dev/null || true
    echo "✅ vnstat service started"
fi

# Create config directory
CONFIG_DIR="${HOME}/.config/bandwidth-monitor"
mkdir -p "$CONFIG_DIR"

# Copy default config if not exists
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    cp "$SCRIPT_DIR/config-template.yaml" "$CONFIG_DIR/config.yaml"
    echo "✅ Config created at $CONFIG_DIR/config.yaml"
fi

# Auto-detect primary interface
IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
if [ -n "$IFACE" ]; then
    echo "✅ Detected primary interface: $IFACE"
    # Update config
    sed -i "s/^interface:.*/interface: $IFACE/" "$CONFIG_DIR/config.yaml" 2>/dev/null || true
fi

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Bandwidth Monitor installed!"
echo "  Interface: ${IFACE:-auto}"
echo "  Config: $CONFIG_DIR/config.yaml"
echo ""
echo "  Wait ~5 min for vnstat to collect"
echo "  initial data, then run:"
echo "    bash scripts/run.sh --status"
echo "═══════════════════════════════════════"
