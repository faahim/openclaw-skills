#!/bin/bash
# Generate readability report for markdown/text files
set -euo pipefail

TARGET="${1:-.}"

if ! command -v vale &>/dev/null; then
  echo "❌ Vale not installed. Run: bash scripts/install.sh"
  exit 1
fi

echo "═══════════════════════════════════════════════════"
echo "  📊 Readability Report"
echo "  Target: $TARGET"
echo "  Generated: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "═══════════════════════════════════════════════════"
echo ""

TOTAL_FILES=0
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
TOTAL_SUGGESTIONS=0
TOTAL_WORDS=0

# Find all lintable files
FILES=$(find "$TARGET" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.html" -o -name "*.rst" \) | sort)

if [[ -z "$FILES" ]]; then
  echo "No lintable files found in $TARGET"
  exit 0
fi

while IFS= read -r file; do
  TOTAL_FILES=$((TOTAL_FILES + 1))

  # Word count
  WORDS=$(wc -w < "$file" 2>/dev/null || echo 0)
  TOTAL_WORDS=$((TOTAL_WORDS + WORDS))

  # Vale JSON output
  JSON=$(vale --output=JSON "$file" 2>/dev/null || echo "[]")

  ERRORS=$(echo "$JSON" | jq '[.[].Alerts[] | select(.Severity == "error")] | length' 2>/dev/null || echo 0)
  WARNINGS=$(echo "$JSON" | jq '[.[].Alerts[] | select(.Severity == "warning")] | length' 2>/dev/null || echo 0)
  SUGGESTIONS=$(echo "$JSON" | jq '[.[].Alerts[] | select(.Severity == "suggestion")] | length' 2>/dev/null || echo 0)

  TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))
  TOTAL_WARNINGS=$((TOTAL_WARNINGS + WARNINGS))
  TOTAL_SUGGESTIONS=$((TOTAL_SUGGESTIONS + SUGGESTIONS))

  # Status icon
  if [[ $ERRORS -gt 0 ]]; then
    ICON="❌"
  elif [[ $WARNINGS -gt 0 ]]; then
    ICON="⚠️ "
  else
    ICON="✅"
  fi

  printf "%s %-40s %5d words | %d err, %d warn, %d sug\n" \
    "$ICON" "$(basename "$file")" "$WORDS" "$ERRORS" "$WARNINGS" "$SUGGESTIONS"

done <<< "$FILES"

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Summary"
echo "───────────────────────────────────────────────────"
echo "  Files scanned:  $TOTAL_FILES"
echo "  Total words:    $TOTAL_WORDS"
echo "  Errors:         $TOTAL_ERRORS"
echo "  Warnings:       $TOTAL_WARNINGS"
echo "  Suggestions:    $TOTAL_SUGGESTIONS"

# Quality score (simple: 100 - (errors*10 + warnings*3 + suggestions*1), min 0)
DEDUCTIONS=$((TOTAL_ERRORS * 10 + TOTAL_WARNINGS * 3 + TOTAL_SUGGESTIONS))
SCORE=$((100 - DEDUCTIONS))
[[ $SCORE -lt 0 ]] && SCORE=0

echo "  Quality score:  ${SCORE}/100"
echo "═══════════════════════════════════════════════════"
