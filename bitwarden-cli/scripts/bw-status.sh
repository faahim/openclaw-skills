#!/bin/bash
set -euo pipefail

# Bitwarden Vault Status

STATUS=$(bw status 2>/dev/null)
STATE=$(echo "$STATUS" | jq -r '.status')
EMAIL=$(echo "$STATUS" | jq -r '.userEmail // "N/A"')
SERVER=$(echo "$STATUS" | jq -r '.serverUrl // "https://vault.bitwarden.com"')
LAST_SYNC=$(echo "$STATUS" | jq -r '.lastSync // "Never"')

echo "📊 Bitwarden Vault Status"
echo "========================="
echo "   Status: $STATE"
echo "   Email: $EMAIL"
echo "   Server: $SERVER"
echo "   Last sync: $LAST_SYNC"

if [ "$STATE" = "unlocked" ] && [ -n "${BW_SESSION:-}" ]; then
  ITEMS=$(bw list items --session "$BW_SESSION" 2>/dev/null)
  TOTAL=$(echo "$ITEMS" | jq 'length')
  LOGINS=$(echo "$ITEMS" | jq '[.[] | select(.type == 1)] | length')
  CARDS=$(echo "$ITEMS" | jq '[.[] | select(.type == 3)] | length')
  IDENTITIES=$(echo "$ITEMS" | jq '[.[] | select(.type == 4)] | length')
  NOTES=$(echo "$ITEMS" | jq '[.[] | select(.type == 2)] | length')
  FOLDERS=$(bw list folders --session "$BW_SESSION" | jq 'length')
  
  echo "   Total items: $TOTAL"
  echo "   Logins: $LOGINS | Cards: $CARDS | Identities: $IDENTITIES | Secure Notes: $NOTES"
  echo "   Folders: $FOLDERS"
elif [ "$STATE" = "locked" ]; then
  echo ""
  echo "🔒 Vault is locked. Unlock with:"
  echo "   export BW_SESSION=\$(bw unlock --raw)"
elif [ "$STATE" = "unauthenticated" ]; then
  echo ""
  echo "🔑 Not logged in. Log in with:"
  echo "   bw login"
fi
