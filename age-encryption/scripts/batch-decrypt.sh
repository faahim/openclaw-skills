#!/bin/bash
set -e

DIR="${1:-.}"
KEY_FILE="${AGE_KEY_FILE:-$HOME/.config/age/key.txt}"

if [ ! -f "$KEY_FILE" ]; then
  echo "❌ No private key found at $KEY_FILE"
  echo "   Set AGE_KEY_FILE or place key at $KEY_FILE"
  exit 1
fi

COUNT=0

echo "🔓 Decrypting .age files in $DIR..."

while IFS= read -r -d '' file; do
  OUTFILE="${file%.age}"
  if [ -f "$OUTFILE" ]; then
    echo "   ⏭️  $file (decrypted file exists)"
    continue
  fi
  age -d -i "$KEY_FILE" -o "$OUTFILE" "$file"
  echo "   ✅ $file → $OUTFILE"
  COUNT=$((COUNT + 1))
done < <(find "$DIR" -name "*.age" -type f -print0 2>/dev/null)

echo ""
echo "🔓 Decrypted $COUNT file(s)"
