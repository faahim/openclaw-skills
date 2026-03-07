#!/bin/bash
set -euo pipefail

# Set up multi-environment SOPS encryption (dev/staging/prod)

PROJECT_DIR="${1:-.}"
PUBKEY="${2:-$(bash "$(dirname "$0")/get-pubkey.sh" 2>/dev/null || true)}"

if [ -z "$PUBKEY" ]; then
  echo "❌ No age public key. Run: bash scripts/setup-keys.sh"
  exit 1
fi

cd "$PROJECT_DIR"

mkdir -p secrets/{dev,staging,prod}

cat > .sops.yaml <<EOF
# Multi-environment SOPS configuration
creation_rules:
  # Dev secrets — all team members
  - path_regex: secrets/dev/.*
    age: >-
      ${PUBKEY}

  # Staging secrets — ops team only
  - path_regex: secrets/staging/.*
    age: >-
      ${PUBKEY}

  # Production secrets — restricted access
  - path_regex: secrets/prod/.*
    age: >-
      ${PUBKEY}

  # Default rule for other secret files
  - path_regex: \.env\.encrypted$
    age: >-
      ${PUBKEY}
EOF

echo "✅ Multi-environment structure created:"
echo "   secrets/dev/     — development secrets"
echo "   secrets/staging/ — staging secrets"
echo "   secrets/prod/    — production secrets (add restricted key)"
echo ""
echo "📝 Edit .sops.yaml to add different keys per environment."
echo "   Tip: Use separate age keys for dev/staging/prod teams."
