#!/bin/bash
set -euo pipefail

# Generate age key pair for SOPS encryption

KEY_NAME="${1:-default}"
KEY_DIR="$HOME/.config/sops/age"
KEY_FILE="$KEY_DIR/keys.txt"

mkdir -p "$KEY_DIR"

if [ -f "$KEY_FILE" ] && [ "$KEY_NAME" = "default" ]; then
  echo "⚠️  Key file already exists at $KEY_FILE"
  echo "   Public key: $(grep -oP 'age1\S+' "$KEY_FILE" | head -1)"
  echo "   To generate an additional key, run: bash scripts/setup-keys.sh <name>"
  exit 0
fi

if [ "$KEY_NAME" != "default" ]; then
  KEY_FILE="$KEY_DIR/${KEY_NAME}.txt"
fi

echo "🔑 Generating age key pair..."
age-keygen -o "$KEY_FILE" 2>&1

chmod 600 "$KEY_FILE"

PUBKEY=$(grep -oP 'age1\S+' "$KEY_FILE" | head -1)

echo ""
echo "✅ Key generated!"
echo "   Private key: $KEY_FILE (keep this SECRET)"
echo "   Public key:  $PUBKEY"
echo ""
echo "📋 Copy your public key for .sops.yaml:"
echo "   $PUBKEY"
echo ""
echo "⚠️  BACKUP your private key! If lost, encrypted files are unrecoverable."

# Set SOPS_AGE_KEY_FILE if not already set
if ! grep -q "SOPS_AGE_KEY_FILE" "$HOME/.bashrc" 2>/dev/null; then
  echo "" >> "$HOME/.bashrc"
  echo "# SOPS age key" >> "$HOME/.bashrc"
  echo "export SOPS_AGE_KEY_FILE=\"$KEY_DIR/keys.txt\"" >> "$HOME/.bashrc"
  echo "📝 Added SOPS_AGE_KEY_FILE to ~/.bashrc"
fi
