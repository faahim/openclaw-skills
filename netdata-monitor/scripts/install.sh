#!/bin/bash
# Install Netdata — real-time system monitoring
set -e

echo "🔍 Checking system..."

# Check if already installed
if command -v netdata &>/dev/null || command -v netdatacli &>/dev/null; then
    echo "✅ Netdata is already installed"
    netdata -v 2>/dev/null || true
    echo ""
    echo "To reinstall, run: bash scripts/uninstall.sh first"
    exit 0
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
    echo "   OS: $PRETTY_NAME"
elif [ "$(uname)" = "Darwin" ]; then
    OS="macos"
    echo "   OS: macOS $(sw_vers -productVersion)"
else
    echo "❌ Unsupported OS"
    exit 1
fi

echo "📦 Installing Netdata..."

# macOS: use Homebrew
if [ "$OS" = "macos" ]; then
    if ! command -v brew &>/dev/null; then
        echo "❌ Homebrew required. Install: https://brew.sh"
        exit 1
    fi
    brew install netdata
    brew services start netdata
    echo "✅ Netdata installed and started"
    echo "   Dashboard: http://localhost:19999"
    exit 0
fi

# Linux: use official kickstart script
# Non-interactive, stable channel, don't claim to cloud
curl -fsSL https://get.netdata.cloud/kickstart.sh -o /tmp/netdata-kickstart.sh

echo "   Running official installer (this may take 1-3 minutes)..."
bash /tmp/netdata-kickstart.sh \
    --non-interactive \
    --stable-channel \
    --dont-start-it 2>&1 | tail -5

rm -f /tmp/netdata-kickstart.sh

# Start Netdata
echo "🚀 Starting Netdata..."
if command -v systemctl &>/dev/null; then
    sudo systemctl enable netdata 2>/dev/null || true
    sudo systemctl start netdata
elif command -v service &>/dev/null; then
    sudo service netdata start
fi

# Wait for startup
sleep 3

# Verify
if curl -sf http://localhost:19999/api/v1/info >/dev/null 2>&1; then
    VERSION=$(curl -sf http://localhost:19999/api/v1/info | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    echo ""
    echo "✅ Netdata installed successfully!"
    echo "   Version: $VERSION"
    echo "   Dashboard: http://${IP}:19999"
    echo "   Local: http://localhost:19999"
    echo ""
    echo "Next steps:"
    echo "  • Configure alerts: bash scripts/configure-alerts.sh telegram --bot-token TOKEN --chat-id ID"
    echo "  • Check status: bash scripts/status.sh"
    echo "  • Query metrics: bash scripts/query.sh system.cpu"
else
    echo "⚠️  Netdata installed but may not be running yet."
    echo "   Try: sudo systemctl start netdata"
    echo "   Logs: sudo journalctl -u netdata -n 20"
fi
