#!/bin/bash
# Compare two audit reports (JSON) and show changes
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: compare.sh <old-report.json> <new-report.json>"
  exit 1
fi

OLD="$1"
NEW="$2"

echo "📊 Audit Comparison"
echo "  Old: $OLD"
echo "  New: $NEW"
echo ""

old_out=$(jq '.summary.total_outdated' "$OLD" 2>/dev/null || echo 0)
new_out=$(jq '.summary.total_outdated' "$NEW" 2>/dev/null || echo 0)
old_vuln=$(jq '.summary.total_vulnerable' "$OLD" 2>/dev/null || echo 0)
new_vuln=$(jq '.summary.total_vulnerable' "$NEW" 2>/dev/null || echo 0)

diff_out=$((new_out - old_out))
diff_vuln=$((new_vuln - old_vuln))

echo "Outdated:    $old_out → $new_out (${diff_out:+$diff_out})"
echo "Vulnerable:  $old_vuln → $new_vuln (${diff_vuln:+$diff_vuln})"

if [[ $diff_vuln -gt 0 ]]; then
  echo ""
  echo "⚠️  New vulnerabilities detected!"
elif [[ $diff_vuln -lt 0 ]]; then
  echo ""
  echo "✅ Vulnerabilities reduced!"
fi
