#!/bin/bash
# Import bank CSV statement into hledger journal
# Usage: import-csv.sh <csv-file> [--rules <rules-file>] [--dry-run]
set -euo pipefail

JOURNAL="${LEDGER_FILE:-$HOME/finances/main.journal}"
RULES_FILE="$HOME/finances/import-rules.csv"
DRY_RUN=false
CSV_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rules) RULES_FILE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) CSV_FILE="$1"; shift ;;
    esac
done

if [[ -z "$CSV_FILE" ]]; then
    echo "Usage: import-csv.sh <csv-file> [--rules <rules-file>] [--dry-run]" >&2
    exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
    echo "CSV file not found: $CSV_FILE" >&2
    exit 1
fi

if [[ ! -f "$RULES_FILE" ]]; then
    echo "Rules file not found: $RULES_FILE" >&2
    echo "Create one at $RULES_FILE or specify with --rules" >&2
    exit 1
fi

ROW_COUNT=$(wc -l < "$CSV_FILE")
echo "📥 Importing $CSV_FILE ($ROW_COUNT rows)"
echo "   Rules: $RULES_FILE"
echo "   Journal: $JOURNAL"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 Dry run — showing what would be imported:"
    echo ""
    hledger import "$CSV_FILE" --rules-file "$RULES_FILE" --dry-run 2>&1 || {
        echo "⚠️  Import preview failed. Check your CSV format and rules file." >&2
        exit 1
    }
else
    BEFORE_COUNT=$(hledger -f "$JOURNAL" stats 2>/dev/null | grep "transactions" | head -1 || echo "0")

    hledger import "$CSV_FILE" --rules-file "$RULES_FILE" 2>&1 || {
        echo "❌ Import failed. Try --dry-run first to debug." >&2
        exit 1
    }

    AFTER_COUNT=$(hledger -f "$JOURNAL" stats 2>/dev/null | grep "transactions" | head -1 || echo "0")

    echo "✅ Import complete"
    echo "   Before: $BEFORE_COUNT"
    echo "   After: $AFTER_COUNT"
    echo ""
    echo "Review recent entries:"
    hledger -f "$JOURNAL" register --last 5 2>/dev/null || true
fi
