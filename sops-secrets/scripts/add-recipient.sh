#!/bin/bash
# Add a team member's age public key to the project
set -euo pipefail

NEW_KEY="${1:-}"
PROJECT_DIR="${2:-.}"

if [ -z "$NEW_KEY" ]; then
  echo "Usage: bash scripts/add-recipient.sh <age-public-key> [project-dir]"
  echo "  Adds a team member's key and re-encrypts all secret files"
  exit 1
fi

if [[ ! "$NEW_KEY" == age1* ]]; then
  echo "❌ Invalid age public key. Must start with 'age1'"
  exit 1
fi

SOPS_CONFIG="$PROJECT_DIR/.sops.yaml"

if [ ! -f "$SOPS_CONFIG" ]; then
  echo "❌ No .sops.yaml found in $PROJECT_DIR"
  exit 1
fi

echo "🔑 Adding recipient: ${NEW_KEY:0:25}..."

# Check if key already exists
if grep -q "$NEW_KEY" "$SOPS_CONFIG"; then
  echo "⚠️  Key already exists in .sops.yaml"
  exit 0
fi

# Append key to first age block
sed -i "0,/age: >-/{/age: >-/a\\      ${NEW_KEY},}" "$SOPS_CONFIG"

# Re-encrypt files with new key set
echo "🔄 Re-encrypting files to include new recipient..."

find "$PROJECT_DIR" -type f \( -name "*.yaml" -o -name "*.json" -o -name "*.env" -o -name "*.env.*" \) \
  ! -name ".sops.yaml" ! -path "*/.git/*" ! -path "*/node_modules/*" | while read -r file; do
  if grep -q "ENC\[AES256_GCM" "$file" 2>/dev/null; then
    echo "  🔐 Updating: $file"
    sops updatekeys --yes "$file" 2>/dev/null || echo "  ⚠️  Failed: $file"
  fi
done

echo "✅ Recipient added. Commit .sops.yaml and updated encrypted files."
