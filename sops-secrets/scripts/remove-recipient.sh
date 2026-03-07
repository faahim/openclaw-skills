#!/bin/bash
set -euo pipefail

PROJECT_DIR="${1:-.}"
OLD_PUBKEY="${2:-}"

if [ -z "$OLD_PUBKEY" ]; then
  echo "Usage: bash scripts/remove-recipient.sh <project-dir> <age-pubkey>"
  exit 1
fi

SOPS_YAML="$PROJECT_DIR/.sops.yaml"

if [ ! -f "$SOPS_YAML" ]; then
  echo "❌ No .sops.yaml found in $PROJECT_DIR"
  exit 1
fi

# Remove key from .sops.yaml
sed -i "/${OLD_PUBKEY}/d" "$SOPS_YAML"

echo "✅ Removed recipient from .sops.yaml"
echo ""
echo "⚠️  IMPORTANT: Re-encrypt ALL files to revoke access:"
echo "   find $PROJECT_DIR -name '*.yaml' -exec sops updatekeys -y {} \\;"
