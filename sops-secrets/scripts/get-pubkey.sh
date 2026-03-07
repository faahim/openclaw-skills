#!/bin/bash
set -euo pipefail

KEY_NAME="${1:-default}"
KEY_DIR="$HOME/.config/sops/age"

if [ "$KEY_NAME" = "default" ]; then
  KEY_FILE="$KEY_DIR/keys.txt"
else
  KEY_FILE="$KEY_DIR/${KEY_NAME}.txt"
fi

if [ ! -f "$KEY_FILE" ]; then
  echo "❌ No key found at $KEY_FILE" >&2
  echo "   Run: bash scripts/setup-keys.sh" >&2
  exit 1
fi

grep -oP 'age1\S+' "$KEY_FILE" | head -1
