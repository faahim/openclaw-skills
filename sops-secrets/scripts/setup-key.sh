#!/bin/bash
# Generate age encryption key for SOPS
set -euo pipefail

KEY_DIR="${SOPS_AGE_KEY_DIR:-$HOME/.config/sops/age}"
KEY_FILE="$KEY_DIR/keys.txt"

if [ -f "$KEY_FILE" ]; then
  echo "⚠️  Age key already exists at $KEY_FILE"
  echo "   To generate a new key, delete the existing one first."
  PUBLIC_KEY=$(grep -oP 'public key: \K.*' "$KEY_FILE" 2>/dev/null || age-keygen -y "$KEY_FILE")
  echo ""
  echo "📋 Your public key: $PUBLIC_KEY"
  echo "   Share this with team members to let them encrypt secrets for you."
  exit 0
fi

echo "🔑 Generating age encryption key..."

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

age-keygen -o "$KEY_FILE" 2>&1 | tee /dev/stderr | grep -q "."
chmod 600 "$KEY_FILE"

PUBLIC_KEY=$(age-keygen -y "$KEY_FILE")

echo ""
echo "✅ Age key generated at $KEY_FILE"
echo "📋 Public key: $PUBLIC_KEY"
echo ""
echo "🔒 Keep your private key safe! Back it up securely."
echo "📤 Share the PUBLIC key above with team members."
echo ""
echo "Next: Run 'bash scripts/init-project.sh /path/to/project' to set up SOPS in a project."
