#!/bin/bash
# ACME.sh SSL Manager — Uninstaller

set -euo pipefail

ACME="$HOME/.acme.sh/acme.sh"

echo "🗑️  Uninstalling acme.sh..."

if [[ -f "$ACME" ]]; then
  "$ACME" --uninstall
  echo "✅ acme.sh uninstalled"
  echo "   Certificates remain in $HOME/.acme.sh/ until manually deleted"
  
  read -p "Delete all certificates too? [y/N] " DEL_CERTS
  if [[ "${DEL_CERTS:-n}" =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/.acme.sh"
    echo "✅ All certificates deleted"
  fi
else
  echo "ℹ️  acme.sh not found at $ACME"
fi
