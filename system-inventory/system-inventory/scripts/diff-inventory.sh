#!/bin/bash
# Compare two system inventory JSON snapshots
# Usage: bash diff-inventory.sh baseline.json current.json

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: diff-inventory.sh <baseline.json> <current.json>"
  exit 1
fi

BASELINE="$1"
CURRENT="$2"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required for diff. Install with: sudo apt install jq"
  exit 1
fi

echo "# Inventory Diff"
echo ""
echo "**Baseline:** $BASELINE"
echo "**Current:** $CURRENT"
echo "**Compared at:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Compare system info
echo "## System Changes"
echo ""
for key in hostname os kernel arch timezone; do
  old=$(jq -r ".system.$key // .${key} // \"n/a\"" "$BASELINE" 2>/dev/null)
  new=$(jq -r ".system.$key // .${key} // \"n/a\"" "$CURRENT" 2>/dev/null)
  if [[ "$old" != "$new" ]]; then
    echo "~ **$key:** \`$old\` → \`$new\`"
  fi
done
echo ""

# Compare hardware
echo "## Hardware Changes"
echo ""
for key in cpu_cores ram_total swap_total; do
  old=$(jq -r ".hardware.$key // \"n/a\"" "$BASELINE" 2>/dev/null)
  new=$(jq -r ".hardware.$key // \"n/a\"" "$CURRENT" 2>/dev/null)
  if [[ "$old" != "$new" ]]; then
    echo "~ **$key:** \`$old\` → \`$new\`"
  fi
done
echo ""

# Compare package counts
echo "## Package Changes"
echo ""
old_count=$(jq -r '.packages.count // 0' "$BASELINE" 2>/dev/null)
new_count=$(jq -r '.packages.count // 0' "$CURRENT" 2>/dev/null)
diff_count=$((new_count - old_count))
if [[ $diff_count -gt 0 ]]; then
  echo "+ **$diff_count packages added** ($old_count → $new_count)"
elif [[ $diff_count -lt 0 ]]; then
  echo "- **${diff_count#-} packages removed** ($old_count → $new_count)"
else
  echo "= **No change** ($old_count packages)"
fi
echo ""

# Compare storage
echo "## Storage Changes"
echo ""
old_disks=$(jq -r '.storage | length // 0' "$BASELINE" 2>/dev/null)
new_disks=$(jq -r '.storage | length // 0' "$CURRENT" 2>/dev/null)
echo "Disk entries: $old_disks → $new_disks"
echo ""

# Compare services
echo "## Service Changes"
echo ""
old_svcs=$(jq -r '.services | length // 0' "$BASELINE" 2>/dev/null)
new_svcs=$(jq -r '.services | length // 0' "$CURRENT" 2>/dev/null)
echo "Services: $old_svcs → $new_svcs"
echo ""

# Compare users
echo "## User Changes"
echo ""
old_users=$(jq -r '[.users[].name] | sort | join(",")' "$BASELINE" 2>/dev/null || echo "")
new_users=$(jq -r '[.users[].name] | sort | join(",")' "$CURRENT" 2>/dev/null || echo "")
if [[ "$old_users" != "$new_users" ]]; then
  echo "~ User list changed"
  # Show added users
  comm -13 <(echo "$old_users" | tr ',' '\n' | sort) <(echo "$new_users" | tr ',' '\n' | sort) | while read -r u; do
    [[ -n "$u" ]] && echo "+ Added: $u"
  done
  # Show removed users
  comm -23 <(echo "$old_users" | tr ',' '\n' | sort) <(echo "$new_users" | tr ',' '\n' | sort) | while read -r u; do
    [[ -n "$u" ]] && echo "- Removed: $u"
  done
else
  echo "= No user changes"
fi
echo ""
