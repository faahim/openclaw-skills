#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer currently supports Debian/Ubuntu (apt-get)." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y openssh-server ufw fail2ban

echo "Installed: openssh-server ufw fail2ban"
