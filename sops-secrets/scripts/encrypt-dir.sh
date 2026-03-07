#!/bin/bash
set -euo pipefail

# Encrypt all secret files in a directory using SOPS

DIR="${1:-.}"
PUBKEY="${2:-$(bash "$(dirname "$0")/get-pubkey.sh" 2>/dev/null || true)}"

if [ -z "$PUBKEY" ]; then
  echo "❌ No age public key. Run: bash scripts/setup-keys.sh" >&2
  exit 1
fi

if [ ! -d "$DIR" ]; then
  echo "❌ Directory not found: $DIR" >&2
  exit 1
fi

COUNT=0
ERRORS=0

for f in "$DIR"/*.{yaml,yml,json,env,ini} 2>/dev/null; do
  [ -f "$f" ] || continue

  # Skip already-encrypted files
  if head -5 "$f" | grep -q "sops:" 2>/dev/null || head -1 "$f" | grep -q "ENC\[" 2>/dev/null; then
    echo "⏭️  Already encrypted: $f"
    continue
  fi

  if sops encrypt -i --age "$PUBKEY" "$f" 2>/dev/null; then
    echo "✅ Encrypted: $f"
    ((COUNT++))
  else
    echo "❌ Failed: $f"
    ((ERRORS++))
  fi
done

echo ""
echo "📊 Results: ${COUNT} encrypted, ${ERRORS} errors"
