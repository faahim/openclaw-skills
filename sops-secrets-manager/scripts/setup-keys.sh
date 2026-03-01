#!/bin/bash
# Generate age key pair for SOPS encryption
set -euo pipefail

KEY_DIR="${HOME}/.config/sops/age"
KEY_FILE="${KEY_DIR}/keys.txt"

if [[ -f "$KEY_FILE" ]] && [[ "${1:-}" != "--force" ]]; then
  echo "⚠️  Key already exists at $KEY_FILE"
  echo "   Use --force to generate a new one (will overwrite!)"
  echo ""
  PUBLIC_KEY=$(grep "public key:" "$KEY_FILE" | awk '{print $NF}')
  echo "📋 Your public key: $PUBLIC_KEY"
  exit 0
fi

# Ensure age-keygen is available
if ! command -v age-keygen &>/dev/null; then
  echo "❌ age-keygen not found. Run: bash scripts/install.sh"
  exit 1
fi

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

echo "🔑 Generating new age key pair..."
age-keygen -o "$KEY_FILE" 2>&1
chmod 600 "$KEY_FILE"

PUBLIC_KEY=$(grep "public key:" "$KEY_FILE" | awk '{print $NF}')

echo ""
echo "✅ age key generated at $KEY_FILE"
echo "📋 Public key: $PUBLIC_KEY"
echo ""
echo "Share this public key with your team."
echo "Add it to .sops.yaml in your repos."
echo ""
echo "⚠️  NEVER share the private key file ($KEY_FILE)"
echo "    Back it up securely — if lost, encrypted files cannot be decrypted."
