#!/bin/bash
# Scheduled Nuclei security scan with summary report
# Usage: bash scheduled-scan.sh [targets-file] [output-dir]
set -euo pipefail

TARGETS_FILE="${1:-targets.txt}"
OUTPUT_DIR="${2:-$HOME/nuclei-reports}"
DATE=$(date +%Y-%m-%d)
REPORT_DIR="$OUTPUT_DIR/$DATE"
SEVERITY="${NUCLEI_SEVERITY:-critical,high,medium}"
RATE_LIMIT="${NUCLEI_RATE_LIMIT:-30}"
CONCURRENCY="${NUCLEI_CONCURRENCY:-10}"

# Validate
if [ ! -f "$TARGETS_FILE" ]; then
  echo "❌ Targets file not found: $TARGETS_FILE"
  echo "Create one with URLs (one per line):"
  echo "  echo 'https://example.com' > $TARGETS_FILE"
  exit 1
fi

if ! command -v nuclei &>/dev/null; then
  echo "❌ Nuclei not installed. Run: bash scripts/install.sh"
  exit 1
fi

mkdir -p "$REPORT_DIR"

TARGET_COUNT=$(wc -l < "$TARGETS_FILE" | tr -d ' ')
echo "🔍 Nuclei Scheduled Scan — $DATE"
echo "================================"
echo "📋 Targets: $TARGET_COUNT"
echo "🎯 Severity: $SEVERITY"
echo "⚡ Rate limit: ${RATE_LIMIT} req/s"
echo ""

# Update templates first
echo "📚 Updating templates..."
nuclei -update-templates -silent 2>/dev/null || true

# Run scan
echo "🔍 Scanning..."
SCAN_START=$(date +%s)

nuclei -l "$TARGETS_FILE" \
  -s "$SEVERITY" \
  -rl "$RATE_LIMIT" \
  -c "$CONCURRENCY" \
  -o "$REPORT_DIR/findings.txt" \
  -jsonl -o "$REPORT_DIR/findings.jsonl" \
  -silent \
  -stats 2>/dev/null || true

SCAN_END=$(date +%s)
SCAN_DURATION=$(( SCAN_END - SCAN_START ))

# Generate summary
TOTAL=$(wc -l < "$REPORT_DIR/findings.txt" 2>/dev/null | tr -d ' ' || echo "0")
CRITICAL=$(grep -c '\[critical\]' "$REPORT_DIR/findings.txt" 2>/dev/null || echo "0")
HIGH=$(grep -c '\[high\]' "$REPORT_DIR/findings.txt" 2>/dev/null || echo "0")
MEDIUM=$(grep -c '\[medium\]' "$REPORT_DIR/findings.txt" 2>/dev/null || echo "0")

cat > "$REPORT_DIR/summary.md" << EOF
# Nuclei Scan Report — $DATE

## Summary
- **Targets scanned:** $TARGET_COUNT
- **Duration:** ${SCAN_DURATION}s
- **Total findings:** $TOTAL
  - 🔴 Critical: $CRITICAL
  - 🟠 High: $HIGH
  - 🟡 Medium: $MEDIUM

## Findings

\`\`\`
$(cat "$REPORT_DIR/findings.txt" 2>/dev/null || echo "No findings")
\`\`\`

## Targets Scanned

\`\`\`
$(cat "$TARGETS_FILE")
\`\`\`
EOF

echo ""
echo "📊 Scan Complete"
echo "   Duration: ${SCAN_DURATION}s"
echo "   Findings: $TOTAL (🔴 $CRITICAL critical, 🟠 $HIGH high, 🟡 $MEDIUM medium)"
echo "   Report:   $REPORT_DIR/summary.md"
echo "   Raw data: $REPORT_DIR/findings.jsonl"

# Alert if critical findings
if [ "$CRITICAL" -gt 0 ]; then
  echo ""
  echo "🚨 CRITICAL VULNERABILITIES FOUND!"
  echo ""
  grep '\[critical\]' "$REPORT_DIR/findings.txt" 2>/dev/null
fi
