#!/bin/bash
# Uninstall Scrutiny
set -euo pipefail

INSTALL_DIR="${1:-/opt/scrutiny}"

echo "🗑️  Uninstalling Scrutiny..."

cd "$INSTALL_DIR" 2>/dev/null && docker compose down --rmi all 2>/dev/null || true

read -p "Delete data and config at $INSTALL_DIR? [y/N] " -r
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  sudo rm -rf "$INSTALL_DIR"
  echo "✅ Scrutiny fully removed (data deleted)"
else
  echo "✅ Scrutiny containers removed (data kept at $INSTALL_DIR)"
fi
