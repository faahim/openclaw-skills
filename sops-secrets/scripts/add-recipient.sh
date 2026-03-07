#!/bin/bash
set -euo pipefail

PROJECT_DIR="${1:-.}"
NEW_PUBKEY="${2:-}"

if [ -z "$NEW_PUBKEY" ]; then
  echo "Usage: bash scripts/add-recipient.sh <project-dir> <age-pubkey>"
  exit 1
fi

SOPS_YAML="$PROJECT_DIR/.sops.yaml"

if [ ! -f "$SOPS_YAML" ]; then
  echo "❌ No .sops.yaml found in $PROJECT_DIR"
  exit 1
fi

# Add key to .sops.yaml
if grep -q "$NEW_PUBKEY" "$SOPS_YAML"; then
  echo "ℹ️  Key already exists in .sops.yaml"
  exit 0
fi

# Append key to existing age recipients
sed -i "s|\(age:.*>\-\)|\1\n      ${NEW_PUBKEY},|" "$SOPS_YAML"

echo "✅ Added recipient to .sops.yaml"
echo "   Key: $NEW_PUBKEY"
echo ""
echo "Now re-encrypt files to include new recipient:"
echo "   find $PROJECT_DIR -name '*.yaml' -exec sops updatekeys -y {} \\;"
