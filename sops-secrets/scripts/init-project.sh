#!/bin/bash
set -euo pipefail

# Initialize SOPS encryption in a project

PROJECT_DIR="${1:-.}"
PUBKEY="${2:-$(bash "$(dirname "$0")/get-pubkey.sh" 2>/dev/null || true)}"

if [ -z "$PUBKEY" ]; then
  echo "❌ No age public key found."
  echo "   Run: bash scripts/setup-keys.sh"
  echo "   Or pass key: bash scripts/init-project.sh /path age1..."
  exit 1
fi

cd "$PROJECT_DIR"

# Create .sops.yaml
if [ -f ".sops.yaml" ]; then
  echo "⚠️  .sops.yaml already exists. Skipping."
else
  cat > .sops.yaml <<EOF
# SOPS Configuration
# Docs: https://github.com/getsops/sops
creation_rules:
  # Encrypt files in secrets/ directory
  - path_regex: secrets/.*\.(yaml|yml|json|env|ini)$
    age: >-
      ${PUBKEY}

  # Encrypt .env.encrypted files
  - path_regex: \.env\.encrypted$
    age: >-
      ${PUBKEY}

  # Partial encryption — only encrypt sensitive keys
  # Uncomment to use:
  # - path_regex: config/.*\.yaml$
  #   encrypted_regex: "^(password|secret|key|token|api_key|private|credential)$"
  #   age: >-
  #     ${PUBKEY}
EOF
  echo "✅ Created .sops.yaml"
fi

# Create secrets directory
mkdir -p secrets
echo "✅ Created secrets/ directory"

# Update .gitignore
GITIGNORE_ENTRIES=(
  "# Decrypted secrets (NEVER commit these)"
  "*.decrypted.*"
  "secrets/*.decrypted"
  "# age private keys"
  ".age-keys/"
)

if [ -f ".gitignore" ]; then
  if ! grep -q "Decrypted secrets" .gitignore; then
    echo "" >> .gitignore
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
      echo "$entry" >> .gitignore
    done
    echo "✅ Updated .gitignore"
  fi
else
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    echo "$entry" >> .gitignore
  done
  echo "✅ Created .gitignore"
fi

echo ""
echo "🎉 SOPS initialized in $(pwd)"
echo ""
echo "Next steps:"
echo "  1. Create a secret file: echo 'api_key: sk-123' > secrets/keys.yaml"
echo "  2. Encrypt it: sops encrypt -i secrets/keys.yaml"
echo "  3. Commit the encrypted file: git add secrets/ .sops.yaml"
