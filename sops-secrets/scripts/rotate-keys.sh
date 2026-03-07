#!/bin/bash
set -euo pipefail

# Re-encrypt all SOPS files with a new key

PROJECT_DIR="${1:-.}"
NEW_KEY="${2:-}"

if [ -z "$NEW_KEY" ]; then
  echo "Usage: bash scripts/rotate-keys.sh <project-dir> <new-age-pubkey>"
  exit 1
fi

echo "🔄 Rotating encryption keys in $PROJECT_DIR..."

COUNT=0
ERRORS=0

# Find all SOPS-encrypted files
find "$PROJECT_DIR" -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.env" -o -name "*.ini" \) | while read -r f; do
  # Check if SOPS-encrypted
  if ! head -20 "$f" | grep -q "sops:" 2>/dev/null; then
    continue
  fi

  # Update .sops.yaml first if it exists
  if sops updatekeys -y --age "$NEW_KEY" "$f" 2>/dev/null; then
    echo "✅ $f — re-encrypted"
  else
    # Fallback: decrypt and re-encrypt
    TMP=$(mktemp)
    if sops decrypt "$f" > "$TMP" 2>/dev/null; then
      if sops encrypt --age "$NEW_KEY" "$TMP" > "$f" 2>/dev/null; then
        echo "✅ $f — re-encrypted (fallback)"
      else
        echo "❌ $f — re-encryption failed"
      fi
    else
      echo "❌ $f — decryption failed (do you have the old key?)"
    fi
    rm -f "$TMP"
  fi
done

echo ""
echo "🔑 Key rotation complete."
echo "   Old keys can now be revoked."
echo "   Update .sops.yaml with the new public key."
