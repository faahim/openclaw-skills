#!/bin/bash
# Rotate encryption keys — re-encrypt all secret files with updated key set
set -euo pipefail

PROJECT_DIR="${1:-.}"
REMOVE_KEY=""
ADD_KEY=""

shift || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --remove-key) REMOVE_KEY="$2"; shift 2 ;;
    --add-key) ADD_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SOPS_CONFIG="$PROJECT_DIR/.sops.yaml"

if [ ! -f "$SOPS_CONFIG" ]; then
  echo "❌ No .sops.yaml found in $PROJECT_DIR"
  exit 1
fi

# Update .sops.yaml
if [ -n "$REMOVE_KEY" ]; then
  echo "🔑 Removing key: ${REMOVE_KEY:0:20}..."
  sed -i "/$REMOVE_KEY/d" "$SOPS_CONFIG"
  # Clean up empty lines and trailing commas
  sed -i '/^[[:space:]]*$/d' "$SOPS_CONFIG"
fi

if [ -n "$ADD_KEY" ]; then
  echo "🔑 Adding key: ${ADD_KEY:0:20}..."
  # Add key to first creation rule's age field
  sed -i "0,/age: >-/{/age: >-/a\\      ${ADD_KEY},}" "$SOPS_CONFIG"
fi

# Find all encrypted files and re-encrypt
echo "🔄 Re-encrypting files with updated keys..."
COUNT=0

find "$PROJECT_DIR" -type f \( -name "*.yaml" -o -name "*.json" -o -name "*.env" -o -name "*.env.*" \) \
  ! -name ".sops.yaml" ! -path "*/.git/*" ! -path "*/node_modules/*" | while read -r file; do
  if grep -q "ENC\[AES256_GCM" "$file" 2>/dev/null; then
    echo "  🔐 Rotating: $file"
    sops updatekeys --yes "$file" 2>/dev/null || {
      echo "  ⚠️  Failed to rotate: $file"
      continue
    }
    COUNT=$((COUNT + 1))
  fi
done

echo "✅ Key rotation complete."
echo "   Updated .sops.yaml and re-encrypted matching files."
echo "   Commit both .sops.yaml and the encrypted files."
