#!/bin/bash
set -e

DIR="${1:-.}"
PUB_FILE="${AGE_PUB_FILE:-$HOME/.config/age/pubkey.txt}"

if [ ! -f "$PUB_FILE" ]; then
  echo "❌ No public key found at $PUB_FILE"
  echo "   Run: bash scripts/keygen.sh"
  exit 1
fi

PUBKEY=$(cat "$PUB_FILE")
PATTERNS=("*.env" "*.pem" "*.key" "*.p12" "*.pfx" "*.jks" "*.secret" "*.credentials")
COUNT=0

echo "🔒 Scanning $DIR for sensitive files..."

for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r -d '' file; do
    [[ "$file" == *.age ]] && continue
    OUTFILE="${file}.age"
    if [ -f "$OUTFILE" ]; then
      echo "   ⏭️  $file (already encrypted)"
      continue
    fi
    age -r "$PUBKEY" -o "$OUTFILE" "$file"
    echo "   ✅ $file → $OUTFILE"
    COUNT=$((COUNT + 1))
  done < <(find "$DIR" -name "$pattern" -type f -print0 2>/dev/null)
done

echo ""
echo "🔒 Encrypted $COUNT file(s)"
[ $COUNT -gt 0 ] && echo "   💡 Consider removing originals: find $DIR -name '*.env' -delete (etc.)"
