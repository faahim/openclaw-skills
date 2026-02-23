#!/bin/bash
# Install BorgBackup and Borgmatic
set -euo pipefail

echo "🔧 Installing BorgBackup and Borgmatic..."

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
fi

install_borg() {
  case "$OS" in
    ubuntu|debian|pop|linuxmint)
      echo "📦 Detected Debian/Ubuntu — using apt..."
      sudo apt-get update -qq
      sudo apt-get install -y -qq borgbackup python3-pip
      ;;
    fedora)
      echo "📦 Detected Fedora — using dnf..."
      sudo dnf install -y borgbackup python3-pip
      ;;
    centos|rhel|rocky|alma)
      echo "📦 Detected RHEL-based — using yum/dnf..."
      sudo yum install -y epel-release || true
      sudo yum install -y borgbackup python3-pip
      ;;
    arch|manjaro)
      echo "📦 Detected Arch — using pacman..."
      sudo pacman -Sy --noconfirm borg python-pip
      ;;
    darwin)
      echo "📦 Detected macOS — using brew..."
      brew install borgbackup
      ;;
    *)
      echo "⚠️  Unknown OS ($OS). Trying pip install..."
      ;;
  esac
}

install_borgmatic() {
  echo "📦 Installing borgmatic via pip..."
  pip3 install --user borgmatic 2>/dev/null || pip3 install borgmatic 2>/dev/null || sudo pip3 install borgmatic
}

setup_dirs() {
  sudo mkdir -p /etc/borgmatic
  sudo mkdir -p /etc/borgmatic/hooks
  sudo mkdir -p /var/log/borgmatic
}

# Run installation
install_borg
install_borgmatic
setup_dirs

# Verify
echo ""
echo "✅ Installation complete!"
echo "   borg version:      $(borg --version 2>/dev/null || echo 'NOT FOUND')"
echo "   borgmatic version: $(borgmatic --version 2>/dev/null || echo 'NOT FOUND')"
echo ""
echo "Next steps:"
echo "  1. Initialize a repo:  bash scripts/run.sh init --repo /path/to/backup --encryption repokey"
echo "  2. Create config:      bash scripts/run.sh configure --repo /path/to/backup --source /home"
echo "  3. Run first backup:   bash scripts/run.sh backup"
