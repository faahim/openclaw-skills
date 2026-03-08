#!/bin/bash
# Export decrypted SOPS secrets as shell environment variables
set -euo pipefail

FILE="${1:-}"

if [ -z "$FILE" ]; then
  echo "Usage: eval \$(bash scripts/export-env.sh <file>)" >&2
  echo "  Outputs export statements for all secret values" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "❌ File not found: $FILE" >&2
  exit 1
fi

EXT="${FILE##*.}"

case "$EXT" in
  yaml|yml)
    sops --decrypt "$FILE" | grep -E "^\s*\w+:" | while IFS=: read -r key value; do
      key=$(echo "$key" | xargs | tr '[:lower:]' '[:upper:]' | tr '-' '_' | tr '.' '_')
      value=$(echo "$value" | xargs | sed "s/^['\"]//;s/['\"]$//")
      [ -n "$value" ] && echo "export ${key}=\"${value}\""
    done
    ;;
  json)
    sops --decrypt "$FILE" | jq -r 'to_entries | .[] | select(.value | type == "string" or type == "number") | "export \(.key | ascii_upcase | gsub("-";"_"))=\"\(.value)\""'
    ;;
  env|env.*)
    sops --decrypt "$FILE" | grep -v "^#" | grep "=" | while IFS= read -r line; do
      echo "export $line"
    done
    ;;
  *)
    echo "❌ Unsupported file type: $EXT (use yaml, json, or env)" >&2
    exit 1
    ;;
esac
