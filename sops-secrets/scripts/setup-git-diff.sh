#!/bin/bash
# Configure git to show decrypted diffs for SOPS files
set -euo pipefail

echo "🔧 Configuring git for SOPS decrypted diffs..."

# Set up git diff driver
git config --global diff.sopsdiffer.textconv "sops --decrypt"

# Create/update .gitattributes
GITATTR=".gitattributes"
RULES=(
  "secrets/**/*.yaml diff=sopsdiffer"
  "secrets/**/*.json diff=sopsdiffer"
  "*.enc.yaml diff=sopsdiffer"
  "*.enc.json diff=sopsdiffer"
)

for rule in "${RULES[@]}"; do
  if ! grep -qF "$rule" "$GITATTR" 2>/dev/null; then
    echo "$rule" >> "$GITATTR"
  fi
done

echo "✅ Git diff configured for SOPS files."
echo "   'git diff' will now show decrypted content for encrypted files."
echo "   Rules added to $GITATTR"
