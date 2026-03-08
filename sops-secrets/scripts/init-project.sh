#!/bin/bash
# Initialize SOPS in a project directory
set -euo pipefail

PROJECT_DIR="${1:-.}"
MULTI_ENV=false

shift || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --multi-env) MULTI_ENV=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

if [ ! -f "$KEY_FILE" ]; then
  echo "❌ No age key found. Run 'bash scripts/setup-key.sh' first."
  exit 1
fi

PUBLIC_KEY=$(age-keygen -y "$KEY_FILE")
SOPS_CONFIG="$PROJECT_DIR/.sops.yaml"

if [ -f "$SOPS_CONFIG" ]; then
  echo "⚠️  .sops.yaml already exists at $SOPS_CONFIG"
  echo "   Delete it first to reinitialize."
  exit 1
fi

if [ "$MULTI_ENV" = true ]; then
  cat > "$SOPS_CONFIG" << EOF
# SOPS configuration — multi-environment
creation_rules:
  # Development secrets — all developers
  - path_regex: secrets/dev/.*\.(yaml|json|env)$
    age: >-
      ${PUBLIC_KEY}

  # Staging secrets
  - path_regex: secrets/staging/.*\.(yaml|json|env)$
    age: >-
      ${PUBLIC_KEY}

  # Production secrets — restricted
  - path_regex: secrets/prod/.*\.(yaml|json|env)$
    age: >-
      ${PUBLIC_KEY}

  # Default: catch-all
  - path_regex: .*\.(yaml|json|env)$
    age: >-
      ${PUBLIC_KEY}
EOF

  mkdir -p "$PROJECT_DIR/secrets/dev" "$PROJECT_DIR/secrets/staging" "$PROJECT_DIR/secrets/prod"
  echo "✅ Multi-environment SOPS initialized in $PROJECT_DIR"
  echo "   Created: secrets/dev/, secrets/staging/, secrets/prod/"
else
  cat > "$SOPS_CONFIG" << EOF
# SOPS configuration
creation_rules:
  - path_regex: .*\.(yaml|json|env)$
    age: >-
      ${PUBLIC_KEY}
EOF

  echo "✅ SOPS initialized in $PROJECT_DIR"
fi

echo "   Config: $SOPS_CONFIG"
echo "   Public key: $PUBLIC_KEY"
echo ""
echo "💡 Add more team members' public keys to .sops.yaml (comma-separated)"
echo "   Then encrypt files with: bash scripts/encrypt.sh <file>"
