#!/bin/bash
# Decrypt a SOPS-encrypted file
set -euo pipefail

FILE="${1:-}"
OUTPUT=""

if [ -z "$FILE" ]; then
  echo "Usage: bash scripts/decrypt.sh <file> [--output <outfile>]"
  exit 1
fi

shift
while [[ $# -gt 0 ]]; do
  case $1 in
    --output|-o) OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ ! -f "$FILE" ]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

if [ -n "$OUTPUT" ]; then
  echo "🔓 Decrypting $FILE → $OUTPUT"
  sops --decrypt "$FILE" > "$OUTPUT"
  echo "✅ Decrypted to: $OUTPUT"
else
  echo "🔓 Decrypting $FILE in-place..."
  sops --decrypt --in-place "$FILE"
  echo "✅ Decrypted: $FILE"
  echo "   ⚠️  File is now plaintext — don't commit to git!"
fi
