#!/bin/bash
# Install podman-compose for docker-compose compatibility
set -euo pipefail

echo "Installing podman-compose..."

if command -v pip3 &>/dev/null; then
  pip3 install --user podman-compose
elif command -v pipx &>/dev/null; then
  pipx install podman-compose
else
  echo "Installing pip first..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y python3-pip
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y python3-pip
  elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm python-pip
  fi
  pip3 install --user podman-compose
fi

echo "✅ podman-compose installed: $(podman-compose --version 2>/dev/null || echo 'check PATH')"
echo "Usage: podman-compose -f docker-compose.yml up -d"
