#!/bin/bash
# Initialize .sops.yaml in current directory
set -euo pipefail

KEYS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --key) KEYS+=("$2"); shift 2 ;;
    *) echo "Usage: bash scripts/init-repo.sh --key <age-public-key> [--key <key2>]"; exit 1 ;;
  esac
done

if [[ ${#KEYS[@]} -eq 0 ]]; then
  echo "❌ At least one --key is required"
  echo "Usage: bash scripts/init-repo.sh --key age1xxxxxxx"
  exit 1
fi

if [[ -f ".sops.yaml" ]]; then
  echo "⚠️  .sops.yaml already exists. Overwrite? (y/N)"
  read -r CONFIRM
  [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && exit 0
fi

# Build comma-separated key list
KEY_LIST=$(printf "%s," "${KEYS[@]}")
KEY_LIST="${KEY_LIST%,}"

cat > .sops.yaml <<EOF
# SOPS configuration — defines which files to encrypt and with which keys
# Docs: https://github.com/getsops/sops#using-sopsyaml-conf-to-select-kms-pgp-and-age-for-new-files

creation_rules:
  # Encrypt all YAML/JSON files in secrets/ directory
  - path_regex: secrets/.*\.(yaml|json)$
    age: >-
      ${KEY_LIST}

  # Encrypt .env files
  - path_regex: \.env(\..+)?$
    age: >-
      ${KEY_LIST}

  # Default rule — catch-all for any file encrypted with sops
  - age: >-
      ${KEY_LIST}
EOF

echo "✅ Created .sops.yaml with ${#KEYS[@]} recipient(s)"
echo ""
echo "Edit .sops.yaml to customize path_regex rules for your project."
echo "Then encrypt files with: bash scripts/run.sh encrypt <file>"
