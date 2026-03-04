#!/bin/bash
# Install Monit process supervisor
set -e

echo "=== Monit Manager — Install ==="

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "❌ Cannot detect OS. Install monit manually."
  exit 1
fi

# Install monit
case "$OS" in
  ubuntu|debian|pop|linuxmint)
    echo "📦 Installing monit via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq monit
    ;;
  centos|rhel|fedora|rocky|alma)
    echo "📦 Installing monit via yum/dnf..."
    if command -v dnf &>/dev/null; then
      sudo dnf install -y epel-release 2>/dev/null || true
      sudo dnf install -y monit
    else
      sudo yum install -y epel-release 2>/dev/null || true
      sudo yum install -y monit
    fi
    ;;
  alpine)
    echo "📦 Installing monit via apk..."
    sudo apk add monit
    ;;
  arch|manjaro)
    echo "📦 Installing monit via pacman..."
    sudo pacman -S --noconfirm monit
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    echo "Install monit manually: https://mmonit.com/monit/#download"
    exit 1
    ;;
esac

# Verify installation
if ! command -v monit &>/dev/null; then
  echo "❌ monit installation failed"
  exit 1
fi

MONIT_VERSION=$(monit --version 2>/dev/null | head -1)
echo "✅ Installed: $MONIT_VERSION"

# Create conf.d directory if missing
sudo mkdir -p /etc/monit/conf.d
sudo mkdir -p /etc/monit/conf-enabled

# Ensure conf.d is included in main config
MONITRC="/etc/monit/monitrc"
if [ -f "$MONITRC" ]; then
  if ! grep -q 'include /etc/monit/conf.d' "$MONITRC"; then
    echo "" | sudo tee -a "$MONITRC" >/dev/null
    echo "include /etc/monit/conf.d/*" | sudo tee -a "$MONITRC" >/dev/null
    echo "📝 Added conf.d include to monitrc"
  fi
fi

# Set proper permissions
sudo chmod 700 "$MONITRC" 2>/dev/null || true

# Set default check interval (30 seconds)
if grep -q "^set daemon" "$MONITRC" 2>/dev/null; then
  echo "⏱️  Check interval already configured"
else
  sudo sed -i '1i set daemon 30' "$MONITRC" 2>/dev/null || true
fi

# Set log file
if ! grep -q "set log" "$MONITRC" 2>/dev/null; then
  echo 'set log /var/log/monit.log' | sudo tee -a "$MONITRC" >/dev/null
fi

# Enable and start monit
if command -v systemctl &>/dev/null; then
  sudo systemctl enable monit 2>/dev/null || true
  sudo systemctl start monit 2>/dev/null || true
  echo "🚀 Monit service enabled and started"
elif command -v rc-service &>/dev/null; then
  sudo rc-update add monit default 2>/dev/null || true
  sudo rc-service monit start 2>/dev/null || true
  echo "🚀 Monit service enabled and started"
fi

# Validate config
sudo monit -t 2>/dev/null && echo "✅ Configuration valid" || echo "⚠️  Config check failed — review /etc/monit/monitrc"

echo ""
echo "=== Installation Complete ==="
echo "Next steps:"
echo "  1. Add a service: bash scripts/add-service.sh --name nginx --pidfile /var/run/nginx.pid --start 'systemctl start nginx' --stop 'systemctl stop nginx'"
echo "  2. Check status:  sudo monit status"
echo "  3. View logs:     tail -f /var/log/monit.log"
