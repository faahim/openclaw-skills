#!/bin/bash
# Encrypt a file using SOPS
set -euo pipefail

FILE="${1:-}"
ENCRYPTED_REGEX=""

if [ -z "$FILE" ]; then
  echo "Usage: bash scripts/encrypt.sh <file> [--encrypted-regex <pattern>]"
  echo "  Encrypts values in YAML/JSON/ENV files in-place"
  exit 1
fi

shift
while [[ $# -gt 0 ]]; do
  case $1 in
    --encrypted-regex) ENCRYPTED_REGEX="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ ! -f "$FILE" ]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

# Check if already encrypted
if grep -q "ENC\[AES256_GCM" "$FILE" 2>/dev/null; then
  echo "⚠️  File appears to already be encrypted: $FILE"
  echo "   Use 'bash scripts/edit.sh $FILE' to modify encrypted files."
  exit 1
fi

SOPS_ARGS=(--encrypt --in-place)

if [ -n "$ENCRYPTED_REGEX" ]; then
  SOPS_ARGS+=(--encrypted-regex "$ENCRYPTED_REGEX")
fi

echo "🔐 Encrypting $FILE..."
sops "${SOPS_ARGS[@]}" "$FILE"
echo "✅ Encrypted: $FILE"
echo "   Keys are readable, values are encrypted."
echo "   Safe to commit to git."
