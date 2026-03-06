#!/bin/bash
set -euo pipefail

# Bitwarden Search — Find credentials quickly

QUERY="${1:-}"
SHOW_PASS=false

for arg in "$@"; do
  case "$arg" in
    --show-password) SHOW_PASS=true ;;
  esac
done

if [ -z "$QUERY" ]; then
  echo "Usage: bw-search.sh <query> [--show-password]"
  echo "  Search your Bitwarden vault by name, username, or URL"
  exit 1
fi

# Check session
if [ -z "${BW_SESSION:-}" ]; then
  echo "❌ Vault is locked. Run: export BW_SESSION=\$(bw unlock --raw)"
  exit 1
fi

# Search
RESULTS=$(bw list items --search "$QUERY" --session "$BW_SESSION" 2>/dev/null)
COUNT=$(echo "$RESULTS" | jq 'length')

if [ "$COUNT" -eq 0 ]; then
  echo "🔍 No items found matching \"$QUERY\""
  exit 0
fi

echo "🔍 Found $COUNT item(s) matching \"$QUERY\":"
echo ""

echo "$RESULTS" | jq -r --argjson show "$SHOW_PASS" '
  to_entries[] |
  "\(.key + 1). \(.value.name)" +
  (if .value.login then
    "\n   Username: \(.value.login.username // "N/A")" +
    (if $show then "\n   Password: \(.value.login.password // "N/A")" else "" end) +
    "\n   URL: \(.value.login.uris[0].uri // "N/A" | if . == "N/A" then . else . end)"
  elif .value.type == 2 then
    "\n   Type: Secure Note"
  elif .value.type == 3 then
    "\n   Type: Card"
  elif .value.type == 4 then
    "\n   Type: Identity"
  else "" end) +
  "\n   Last modified: \(.value.revisionDate[:10])\n"
'
