#!/bin/bash
# Compare two load test reports
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: bash compare.sh <before.txt> <after.txt>"
  exit 1
fi

BEFORE="$1"
AFTER="$2"

echo "═══════════════════════════════════════════════════"
echo "  Load Test Comparison"
echo "═══════════════════════════════════════════════════"
echo ""
echo "BEFORE:"
grep -E "(Requests/sec|p50|p95|p99|Success Rate)" "$BEFORE" 2>/dev/null || echo "  (could not parse)"
echo ""
echo "AFTER:"
grep -E "(Requests/sec|p50|p95|p99|Success Rate)" "$AFTER" 2>/dev/null || echo "  (could not parse)"
echo ""
echo "═══════════════════════════════════════════════════"
