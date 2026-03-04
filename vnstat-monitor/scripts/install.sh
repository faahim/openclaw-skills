#!/bin/bash
# vnstat-monitor: Install and configure vnstat
set -euo pipefail

CONFIG_DIR="$HOME/.vnstat-monitor"
mkdir -p "$CONFIG_DIR"

# Parse arguments
ACTION="install"
TARGET_IFACE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --add) ACTION="add"; TARGET_IFACE="$2"; shift 2 ;;
    --reset) ACTION="reset"; TARGET_IFACE="$2"; shift 2 ;;
    --help) echo "Usage: install.sh [--add <iface>] [--reset <iface>]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  elif [ -f /etc/redhat-release ]; then
    echo "rhel"
  else
    echo "unknown"
  fi
}

install_vnstat() {
  if command -v vnstat &>/dev/null; then
    echo "✅ vnstat already installed: $(vnstat --version 2>&1 | head -1)"
    return 0
  fi

  OS=$(detect_os)
  echo "📦 Installing vnstat on $OS..."

  case "$OS" in
    ubuntu|debian|linuxmint|pop)
      sudo apt-get update -qq
      sudo apt-get install -y -qq vnstat jq bc
      ;;
    fedora)
      sudo dnf install -y vnstat jq bc
      ;;
    centos|rhel|rocky|almalinux)
      sudo yum install -y epel-release
      sudo yum install -y vnstat jq bc
      ;;
    arch|manjaro)
      sudo pacman -Sy --noconfirm vnstat jq bc
      ;;
    alpine)
      sudo apk add vnstat jq bc
      ;;
    *)
      echo "❌ Unsupported OS: $OS"
      echo "Install vnstat manually: https://humdi.net/vnstat/"
      exit 1
      ;;
  esac

  echo "✅ vnstat installed successfully"
}

start_daemon() {
  echo "🔧 Starting vnstat daemon..."
  if command -v systemctl &>/dev/null; then
    sudo systemctl enable vnstatd 2>/dev/null || sudo systemctl enable vnstat 2>/dev/null || true
    sudo systemctl start vnstatd 2>/dev/null || sudo systemctl start vnstat 2>/dev/null || true
    echo "✅ vnstat daemon started (systemd)"
  elif command -v rc-service &>/dev/null; then
    sudo rc-update add vnstatd default 2>/dev/null || true
    sudo rc-service vnstatd start 2>/dev/null || true
    echo "✅ vnstat daemon started (OpenRC)"
  else
    sudo vnstatd -d 2>/dev/null || true
    echo "✅ vnstat daemon started (manual)"
  fi
}

init_interfaces() {
  echo "🔍 Detecting network interfaces..."
  
  # Get active interfaces (exclude lo)
  IFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | sed 's/@.*//')
  
  for iface in $IFACES; do
    if vnstat --iflist 2>/dev/null | grep -q "$iface"; then
      echo "  ✅ $iface — already monitored"
    else
      echo "  📡 Adding $iface to monitoring..."
      sudo vnstat --add -i "$iface" 2>/dev/null || vnstat -i "$iface" 2>/dev/null || true
    fi
  done
}

add_interface() {
  echo "📡 Adding interface $TARGET_IFACE..."
  sudo vnstat --add -i "$TARGET_IFACE" 2>/dev/null || vnstat -i "$TARGET_IFACE" 2>/dev/null
  echo "✅ $TARGET_IFACE added to monitoring"
}

reset_interface() {
  echo "⚠️  Resetting statistics for $TARGET_IFACE..."
  sudo vnstat --remove -i "$TARGET_IFACE" --force 2>/dev/null
  sudo vnstat --add -i "$TARGET_IFACE" 2>/dev/null
  echo "✅ $TARGET_IFACE statistics reset"
}

create_default_config() {
  if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    FIRST_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | sed 's/@.*//' | head -1)
    cat > "$CONFIG_DIR/config.yaml" << EOF
# vnstat-monitor configuration
interfaces:
  - name: ${FIRST_IFACE:-eth0}
    cap: 0
    warn_pct: 80
    crit_pct: 95

alerts:
  telegram: false
  log: true
  log_path: $CONFIG_DIR/alerts.log

report:
  default_period: monthly
  default_format: table
EOF
    echo "📝 Default config created at $CONFIG_DIR/config.yaml"
  fi
}

case "$ACTION" in
  install)
    install_vnstat
    start_daemon
    init_interfaces
    create_default_config
    echo ""
    echo "🎉 vnstat-monitor setup complete!"
    echo "   Run 'bash scripts/report.sh' to see your first report."
    echo "   Note: vnstat needs ~5 minutes to collect initial data."
    ;;
  add)
    add_interface
    ;;
  reset)
    reset_interface
    ;;
esac
