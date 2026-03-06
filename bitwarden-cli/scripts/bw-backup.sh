#!/bin/bash
set -euo pipefail

# Bitwarden Vault Backup

FORMAT="encrypted_json"
OUTPUT="$HOME/backups"
TIMESTAMP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --timestamp) TIMESTAMP=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "${BW_SESSION:-}" ]; then
  echo "❌ Vault is locked. Run: export BW_SESSION=\$(bw unlock --raw)"
  exit 1
fi

# Create output directory
mkdir -p "$OUTPUT"

# Generate filename
if $TIMESTAMP; then
  TS=$(date -u +%Y-%m-%dT%H-%M-%S)
  case "$FORMAT" in
    csv) FILENAME="bw-export-${TS}.csv" ;;
    json) FILENAME="bw-export-${TS}.json" ;;
    encrypted_json) FILENAME="bw-export-${TS}.encrypted.json" ;;
    *) echo "❌ Unknown format: $FORMAT (use csv, json, or encrypted_json)"; exit 1 ;;
  esac
else
  case "$FORMAT" in
    csv) FILENAME="bw-export.csv" ;;
    json) FILENAME="bw-export.json" ;;
    encrypted_json) FILENAME="bw-export.encrypted.json" ;;
    *) echo "❌ Unknown format: $FORMAT"; exit 1 ;;
  esac
fi

OUTPATH="$OUTPUT/$FILENAME"

echo "📦 Exporting Bitwarden vault..."
echo "   Format: $FORMAT"

# Export
bw export --format "$FORMAT" --output "$OUTPATH" --session "$BW_SESSION"

if [ -f "$OUTPATH" ]; then
  SIZE=$(du -h "$OUTPATH" | cut -f1)
  ITEMS=$(bw list items --session "$BW_SESSION" | jq 'length')
  
  echo ""
  echo "✅ Vault exported successfully!"
  echo "   Items: $ITEMS"
  echo "   Output: $OUTPATH"
  echo "   Size: $SIZE"
  
  # Set restrictive permissions
  chmod 600 "$OUTPATH"
  echo "   Permissions: 600 (owner-only)"
  
  if [ "$FORMAT" != "encrypted_json" ]; then
    echo ""
    echo "   ⚠️  WARNING: This file contains plaintext passwords!"
    echo "   Store it securely and delete after use."
  fi
else
  echo "❌ Export failed. Check Bitwarden CLI output."
  exit 1
fi
