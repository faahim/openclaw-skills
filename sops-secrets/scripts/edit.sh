#!/bin/bash
# Edit encrypted file — decrypts in editor, re-encrypts on save
set -euo pipefail

FILE="${1:-}"

if [ -z "$FILE" ]; then
  echo "Usage: bash scripts/edit.sh <file>"
  echo "  Opens encrypted file in \$EDITOR, re-encrypts on save"
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

echo "📝 Opening $FILE for editing (decrypted)..."
sops "$FILE"
echo "✅ Changes saved and re-encrypted."
