#!/bin/bash
# SSHFS Remote Mount Manager — Install Script
set -e

echo "🔧 Installing SSHFS Remote Mount Manager..."

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
elif [ "$(uname)" = "Darwin" ]; then
  OS="macos"
else
  OS="unknown"
fi

echo "   Detected OS: $OS"

# Install sshfs
case $OS in
  ubuntu|debian|pop|linuxmint)
    echo "   Installing sshfs via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq sshfs fuse3 2>/dev/null || sudo apt-get install -y -qq sshfs fuse
    ;;
  fedora|rhel|centos|rocky|alma)
    echo "   Installing sshfs via dnf..."
    sudo dnf install -y -q sshfs fuse3 2>/dev/null || sudo dnf install -y -q sshfs fuse
    ;;
  arch|manjaro|endeavouros)
    echo "   Installing sshfs via pacman..."
    sudo pacman -Sy --noconfirm sshfs
    ;;
  alpine)
    echo "   Installing sshfs via apk..."
    sudo apk add sshfs
    ;;
  macos)
    echo "   Installing macFUSE + sshfs via brew..."
    if ! command -v brew &>/dev/null; then
      echo "   ❌ Homebrew required. Install: https://brew.sh"
      exit 1
    fi
    brew install --cask macfuse 2>/dev/null || true
    brew install sshfs 2>/dev/null || brew install gromgit/fuse/sshfs-mac
    ;;
  *)
    echo "   ⚠️ Unknown OS. Please install sshfs manually."
    echo "   Common: sudo apt install sshfs / sudo dnf install sshfs / brew install sshfs"
    exit 1
    ;;
esac

# Create config directory
CONFIG_DIR="$HOME/.config/sshfs-manager"
mkdir -p "$CONFIG_DIR"

# Create default profiles file if not exists
if [ ! -f "$CONFIG_DIR/profiles.yaml" ]; then
  cat > "$CONFIG_DIR/profiles.yaml" << 'YAML'
# SSHFS Mount Manager Profiles
# Add your remote mounts here
profiles: {}
  # example:
  #   host: user@server.com
  #   remote: /var/www
  #   local: ~/remote/server
  #   port: 22
  #   identity: ~/.ssh/id_rsa
  #   options:
  #     - reconnect
  #     - ServerAliveInterval=15
  #   auto_mount: false
YAML
  echo "   Created config: $CONFIG_DIR/profiles.yaml"
fi

# Create default mount base directory
mkdir -p "$HOME/remote"

# Verify installation
if command -v sshfs &>/dev/null; then
  SSHFS_VER=$(sshfs --version 2>&1 | head -1)
  echo ""
  echo "✅ SSHFS installed successfully!"
  echo "   Version: $SSHFS_VER"
  echo "   Config:  $CONFIG_DIR/profiles.yaml"
  echo "   Mounts:  ~/remote/"
  echo ""
  echo "   Quick start:"
  echo "   bash scripts/sshfs-manager.sh mount --host user@server --remote /path --local ~/remote/name"
else
  echo ""
  echo "❌ sshfs installation failed. Please install manually."
  exit 1
fi
