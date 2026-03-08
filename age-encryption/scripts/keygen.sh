#!/bin/bash
set -e

KEY_DIR="${AGE_KEY_DIR:-$HOME/.config/age}"
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

KEY_FILE="$KEY_DIR/key.txt"
PUB_FILE="$KEY_DIR/pubkey.txt"

if [ -f "$KEY_FILE" ]; then
  echo "⚠️  Key already exists at $KEY_FILE"
  echo "   Public key: $(age-keygen -y "$KEY_FILE")"
  echo "   Use AGE_KEY_DIR to generate in a different location"
  exit 0
fi

echo "🔑 Generating new age key pair..."
age-keygen -o "$KEY_FILE" 2>&1
chmod 600 "$KEY_FILE"

age-keygen -y "$KEY_FILE" > "$PUB_FILE"
echo ""
echo "✅ Key pair generated!"
echo "   Private key: $KEY_FILE"
echo "   Public key:  $PUB_FILE"
echo "   Share your public key: $(cat "$PUB_FILE")"
echo ""
echo "⚠️  BACK UP your private key! If lost, encrypted files cannot be recovered."
