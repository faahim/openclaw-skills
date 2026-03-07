#!/bin/bash
set -euo pipefail

# Decrypt all SOPS-encrypted files in a directory

DIR="${1:-.}"
OUTPUT_DIR="${2:-}"  # Optional: output to different dir

if [ ! -d "$DIR" ]; then
  echo "❌ Directory not found: $DIR" >&2
  exit 1
fi

COUNT=0
ERRORS=0

for f in "$DIR"/*.{yaml,yml,json,env,ini} 2>/dev/null; do
  [ -f "$f" ] || continue

  # Check if file is SOPS-encrypted
  if ! head -20 "$f" | grep -q "sops:" 2>/dev/null && ! head -1 "$f" | grep -q "ENC\[" 2>/dev/null; then
    continue
  fi

  if [ -n "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    OUT_FILE="$OUTPUT_DIR/$(basename "$f")"
    if sops decrypt "$f" > "$OUT_FILE" 2>/dev/null; then
      echo "✅ Decrypted: $f → $OUT_FILE"
      ((COUNT++))
    else
      echo "❌ Failed: $f"
      ((ERRORS++))
    fi
  else
    if sops decrypt -i "$f" 2>/dev/null; then
      echo "✅ Decrypted in-place: $f"
      ((COUNT++))
    else
      echo "❌ Failed: $f"
      ((ERRORS++))
    fi
  fi
done

echo ""
echo "📊 Results: ${COUNT} decrypted, ${ERRORS} errors"
