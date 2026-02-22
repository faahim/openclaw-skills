#!/bin/bash
# Compare two scan reports and show differences
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: diff.sh <baseline.json> <current.json>"
  exit 1
fi

BASELINE="$1"
CURRENT="$2"

if [[ ! -f "$BASELINE" || ! -f "$CURRENT" ]]; then
  echo "❌ Both files must exist"
  exit 1
fi

echo ""
echo "🔄 Scan Comparison"
echo "   Baseline: $BASELINE"
echo "   Current:  $CURRENT"
echo "─────────────────────────────────────"

# Get open ports from each
BASELINE_PORTS=$(jq -r '[.ports[] | select(.state == "open") | .port] | sort | .[]' "$BASELINE" 2>/dev/null)
CURRENT_PORTS=$(jq -r '[.ports[] | select(.state == "open") | .port] | sort | .[]' "$CURRENT" 2>/dev/null)

# Find new ports (in current but not baseline)
NEW_COUNT=0
while read -r port; do
  [[ -z "$port" ]] && continue
  if ! echo "$BASELINE_PORTS" | grep -qx "$port"; then
    svc=$(jq -r --argjson p "$port" '.ports[] | select(.port == $p) | .service' "$CURRENT" 2>/dev/null || echo "unknown")
    echo "  🆕 NEW:    $port/tcp ($svc) — opened since baseline"
    ((NEW_COUNT++))
  fi
done <<< "$CURRENT_PORTS"

# Find closed ports (in baseline but not current)
CLOSED_COUNT=0
while read -r port; do
  [[ -z "$port" ]] && continue
  if ! echo "$CURRENT_PORTS" | grep -qx "$port"; then
    svc=$(jq -r --argjson p "$port" '.ports[] | select(.port == $p) | .service' "$BASELINE" 2>/dev/null || echo "unknown")
    echo "  ❌ CLOSED: $port/tcp ($svc) — no longer accessible"
    ((CLOSED_COUNT++))
  fi
done <<< "$BASELINE_PORTS"

# Find version changes
while read -r port; do
  [[ -z "$port" ]] && continue
  if echo "$BASELINE_PORTS" | grep -qx "$port"; then
    old_ver=$(jq -r --argjson p "$port" '.ports[] | select(.port == $p) | .version' "$BASELINE" 2>/dev/null)
    new_ver=$(jq -r --argjson p "$port" '.ports[] | select(.port == $p) | .version' "$CURRENT" 2>/dev/null)
    if [[ "$old_ver" != "$new_ver" && -n "$old_ver" && -n "$new_ver" ]]; then
      echo "  🔄 CHANGED: $port/tcp — version: \"$old_ver\" → \"$new_ver\""
    fi
  fi
done <<< "$CURRENT_PORTS"

if [[ "$NEW_COUNT" -eq 0 && "$CLOSED_COUNT" -eq 0 ]]; then
  echo "  ✅ No changes detected"
fi

echo ""
echo "Summary: $NEW_COUNT new, $CLOSED_COUNT closed"
