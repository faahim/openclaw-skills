#!/bin/bash
# Compare two Trivy JSON reports and show new/fixed vulnerabilities
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: diff.sh <old-report.json> <new-report.json>"
  exit 1
fi

OLD="$1"
NEW="$2"

if ! command -v jq &>/dev/null; then
  echo "❌ jq required. Install: sudo apt install jq"
  exit 1
fi

echo "📊 Comparing vulnerability reports"
echo "   Old: $OLD"
echo "   New: $NEW"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Extract CVE IDs
OLD_CVES=$(jq -r '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | sort | unique | .[]' "$OLD" 2>/dev/null)
NEW_CVES=$(jq -r '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | sort | unique | .[]' "$NEW" 2>/dev/null)

# New vulnerabilities (in new but not old)
NEW_ONLY=$(comm -13 <(echo "$OLD_CVES" | sort) <(echo "$NEW_CVES" | sort) | grep -v '^$' || true)
# Fixed vulnerabilities (in old but not new)
FIXED=$(comm -23 <(echo "$OLD_CVES" | sort) <(echo "$NEW_CVES" | sort) | grep -v '^$' || true)

echo ""
if [ -n "$NEW_ONLY" ]; then
  COUNT=$(echo "$NEW_ONLY" | wc -l | tr -d ' ')
  echo "🆕 New vulnerabilities ($COUNT):"
  echo "$NEW_ONLY" | while read -r cve; do
    SEV=$(jq -r --arg cve "$cve" '[.Results[]?.Vulnerabilities[]? | select(.VulnerabilityID==$cve)] | .[0].Severity // "UNKNOWN"' "$NEW")
    PKG=$(jq -r --arg cve "$cve" '[.Results[]?.Vulnerabilities[]? | select(.VulnerabilityID==$cve)] | .[0].PkgName // "unknown"' "$NEW")
    echo "   [$SEV] $cve ($PKG)"
  done
else
  echo "✅ No new vulnerabilities"
fi

echo ""
if [ -n "$FIXED" ]; then
  COUNT=$(echo "$FIXED" | wc -l | tr -d ' ')
  echo "🔧 Fixed vulnerabilities ($COUNT):"
  echo "$FIXED" | while read -r cve; do
    echo "   $cve"
  done
else
  echo "ℹ️  No vulnerabilities fixed"
fi

OLD_COUNT=$(echo "$OLD_CVES" | grep -c . || echo 0)
NEW_COUNT=$(echo "$NEW_CVES" | grep -c . || echo 0)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total: $OLD_COUNT → $NEW_COUNT vulnerabilities"
