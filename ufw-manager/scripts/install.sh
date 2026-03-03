#!/usr/bin/env bash
set -euo pipefail

need_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Run as root: sudo bash scripts/install.sh" >&2
    exit 1
  fi
}

need_root
if command -v ufw >/dev/null 2>&1; then
  echo "ufw already installed"
  exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y ufw iptables jq
  echo "Installed ufw + dependencies"
else
  echo "Unsupported package manager. Install ufw manually." >&2
  exit 1
fi
