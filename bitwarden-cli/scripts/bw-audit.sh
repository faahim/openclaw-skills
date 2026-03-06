#!/bin/bash
set -euo pipefail

# Bitwarden Password Audit — Check for breached passwords via HIBP k-anonymity API

ITEM_FILTER=""
OLD_PASSWORDS=false
OLD_DAYS=180

while [[ $# -gt 0 ]]; do
  case "$1" in
    --item) ITEM_FILTER="$2"; shift 2 ;;
    --old-passwords) OLD_PASSWORDS=true; shift ;;
    --days) OLD_DAYS="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "${BW_SESSION:-}" ]; then
  echo "❌ Vault is locked. Run: export BW_SESSION=\$(bw unlock --raw)"
  exit 1
fi

# Get items
if [ -n "$ITEM_FILTER" ]; then
  ITEMS=$(bw list items --search "$ITEM_FILTER" --session "$BW_SESSION")
else
  ITEMS=$(bw list items --session "$BW_SESSION")
fi

TOTAL=$(echo "$ITEMS" | jq '[.[] | select(.type == 1 and .login.password != null)] | length')
echo "🔍 Auditing $TOTAL login items..."
echo ""

BREACHED=0
WEAK=0
REUSED_COUNT=0

# Check for breached passwords using HIBP k-anonymity
echo "$ITEMS" | jq -r '.[] | select(.type == 1 and .login.password != null) | "\(.name)\t\(.login.password)\t\(.revisionDate)"' | while IFS=$'\t' read -r NAME PASS REV_DATE; do
  # SHA1 hash of password
  HASH=$(echo -n "$PASS" | sha1sum | awk '{print toupper($1)}')
  PREFIX="${HASH:0:5}"
  SUFFIX="${HASH:5}"
  
  # Query HIBP
  RESPONSE=$(curl -s "https://api.pwnedpasswords.com/range/$PREFIX" 2>/dev/null)
  
  # Check if our suffix appears
  MATCH=$(echo "$RESPONSE" | grep -i "^$SUFFIX:" | cut -d: -f2 | tr -d '\r' || echo "0")
  
  if [ "$MATCH" -gt 0 ]; then
    echo "⚠️  $NAME — seen $MATCH times in breaches"
    BREACHED=$((BREACHED + 1))
  fi
  
  # Check password length (weak if <8 chars)
  if [ ${#PASS} -lt 8 ]; then
    echo "🔑 $NAME — weak password (${#PASS} chars)"
    WEAK=$((WEAK + 1))
  fi
  
  # Rate limit: don't hammer HIBP
  sleep 0.2
done

echo ""
echo "📊 Audit complete"
echo "   Total items checked: $TOTAL"
echo "   ⚠️  Breached passwords found above (if any)"
echo ""
echo "💡 To rotate a breached password:"
echo "   bw edit item <item-id> --session \$BW_SESSION"

# Check for old passwords
if $OLD_PASSWORDS; then
  echo ""
  echo "📅 Passwords older than $OLD_DAYS days:"
  CUTOFF=$(date -u -d "$OLD_DAYS days ago" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-${OLD_DAYS}d +%Y-%m-%dT%H:%M:%S 2>/dev/null || echo "")
  if [ -n "$CUTOFF" ]; then
    echo "$ITEMS" | jq -r --arg cutoff "$CUTOFF" '
      .[] | select(.type == 1 and .revisionDate < $cutoff) |
      "   \(.name) — last modified \(.revisionDate[:10])"
    '
  else
    echo "   (date calculation not supported on this OS)"
  fi
fi
