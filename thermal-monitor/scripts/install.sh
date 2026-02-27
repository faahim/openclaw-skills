#!/bin/bash
# Thermal Monitor — Install Dependencies
set -e

echo "🌡️ Thermal Monitor — Installing dependencies..."

# Detect OS
if [ -f /etc/debian_version ]; then
    PKG_MGR="apt-get"
    INSTALL_CMD="sudo apt-get install -y lm-sensors"
elif [ -f /etc/redhat-release ]; then
    PKG_MGR="yum"
    INSTALL_CMD="sudo yum install -y lm_sensors"
elif [ -f /etc/arch-release ]; then
    PKG_MGR="pacman"
    INSTALL_CMD="sudo pacman -S --noconfirm lm_sensors"
elif command -v brew &>/dev/null; then
    # macOS — lm-sensors not available, use sysfs fallback
    echo "⚠️  macOS detected. lm-sensors not available."
    echo "   The monitor will use system_profiler and sysctl for temperature data."
    exit 0
else
    echo "❌ Unsupported OS. Install lm-sensors manually."
    exit 1
fi

# Check if already installed
if command -v sensors &>/dev/null; then
    echo "✅ lm-sensors already installed: $(sensors --version 2>/dev/null | head -1)"
else
    echo "📦 Installing lm-sensors via $PKG_MGR..."
    $INSTALL_CMD
fi

# Detect sensors
echo ""
echo "🔍 Detecting hardware sensors..."
if command -v sensors-detect &>/dev/null; then
    sudo sensors-detect --auto 2>/dev/null || true
fi

# Verify
echo ""
echo "🌡️ Current sensor readings:"
sensors 2>/dev/null || echo "   (run 'sudo sensors-detect' manually if no sensors found)"

echo ""
echo "✅ Installation complete. Run: bash scripts/run.sh --once"
