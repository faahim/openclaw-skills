#!/bin/bash
# vnstat-traffic installer — installs vnstat and initializes monitoring
set -euo pipefail

echo "╔══════════════════════════════════════════╗"
echo "║  Network Traffic Monitor — Installer     ║"
echo "╚══════════════════════════════════════════╝"

# Detect package manager and install vnstat
install_vnstat() {
  if command -v vnstat &>/dev/null; then
    echo "✅ vnstat already installed ($(vnstat --version 2>&1 | head -1))"
    return 0
  fi

  echo "📦 Installing vnstat..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq vnstat jq bc
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y vnstat jq bc
  elif command -v yum &>/dev/null; then
    sudo yum install -y vnstat jq bc
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm vnstat jq bc
  elif command -v apk &>/dev/null; then
    sudo apk add vnstat jq bc
  elif command -v brew &>/dev/null; then
    brew install vnstat jq bc
  else
    echo "❌ Could not detect package manager. Install vnstat manually."
    exit 1
  fi
  echo "✅ vnstat installed"
}

# Start vnstat daemon
start_daemon() {
  if command -v systemctl &>/dev/null; then
    sudo systemctl enable vnstatd 2>/dev/null || sudo systemctl enable vnstat 2>/dev/null || true
    sudo systemctl start vnstatd 2>/dev/null || sudo systemctl start vnstat 2>/dev/null || true
    echo "✅ vnstat daemon started (systemd)"
  elif command -v rc-service &>/dev/null; then
    sudo rc-update add vnstatd default 2>/dev/null || true
    sudo rc-service vnstatd start 2>/dev/null || true
    echo "✅ vnstat daemon started (OpenRC)"
  else
    # Start manually
    vnstatd -d 2>/dev/null || true
    echo "✅ vnstat daemon started (manual)"
  fi
}

# Initialize interfaces
init_interfaces() {
  echo ""
  echo "🔍 Detecting network interfaces..."
  local interfaces
  interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | head -10)

  if [ -z "$interfaces" ]; then
    echo "⚠️  No interfaces found. You may need to add them manually:"
    echo "    sudo vnstat --add -i <interface-name>"
    return
  fi

  for iface in $interfaces; do
    if vnstat -i "$iface" --json 2>/dev/null | jq -e '.interfaces[0]' &>/dev/null; then
      echo "  ✅ $iface — already being monitored"
    else
      sudo vnstat --add -i "$iface" 2>/dev/null && echo "  ✅ $iface — added to monitoring" || echo "  ⚠️  $iface — could not add (may need manual setup)"
    fi
  done
}

# Create config directory
setup_config() {
  local config_dir="${HOME}/.config/vnstat-traffic"
  mkdir -p "$config_dir"

  if [ ! -f "$config_dir/config.yaml" ]; then
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$script_dir/config-template.yaml" ]; then
      cp "$script_dir/config-template.yaml" "$config_dir/config.yaml"
      echo ""
      echo "📝 Config created at: $config_dir/config.yaml"
      echo "   Edit it to set data caps and alert preferences."
    fi
  else
    echo "📝 Config already exists at: $config_dir/config.yaml"
  fi
}

# Main
install_vnstat
start_daemon
init_interfaces
setup_config

echo ""
echo "════════════════════════════════════════════"
echo "✅ Installation complete!"
echo ""
echo "Quick commands:"
echo "  bash scripts/traffic.sh status    — Current usage"
echo "  bash scripts/traffic.sh daily     — Today's breakdown"
echo "  bash scripts/traffic.sh monthly   — This month's usage"
echo "  bash scripts/traffic.sh live      — Real-time monitor"
echo ""
echo "Note: vnstat needs ~5 minutes to collect initial data."
echo "════════════════════════════════════════════"
