#!/bin/bash
# Interactive transaction entry for plain-text ledger
set -euo pipefail

JOURNAL="${LEDGER_FILE:-$HOME/finances/main.journal}"

if [[ ! -f "$JOURNAL" ]]; then
    echo "Journal not found at $JOURNAL" >&2
    echo "Run install.sh first or set LEDGER_FILE" >&2
    exit 1
fi

# Defaults
DEFAULT_DATE=$(date +%Y-%m-%d)

echo "📝 Add Transaction"
echo "─────────────────"

# Date
read -p "Date [$DEFAULT_DATE]: " DATE
DATE="${DATE:-$DEFAULT_DATE}"

# Description
read -p "Description: " DESC
if [[ -z "$DESC" ]]; then
    echo "Description required" >&2
    exit 1
fi

# From account (where money goes)
read -p "Expense/destination account [expenses:misc]: " ACCT1
ACCT1="${ACCT1:-expenses:misc}"

# To account (where money comes from)
read -p "Source account [assets:bank:checking]: " ACCT2
ACCT2="${ACCT2:-assets:bank:checking}"

# Amount
read -p "Amount: \$" AMOUNT
if [[ -z "$AMOUNT" ]]; then
    echo "Amount required" >&2
    exit 1
fi

# Optional tag
read -p "Tags (optional, e.g. client:acme): " TAGS
TAG_STR=""
if [[ -n "$TAGS" ]]; then
    TAG_STR="  ; $TAGS"
fi

# Write transaction
cat >> "$JOURNAL" << EOF

$DATE $DESC$TAG_STR
    $ACCT1$(printf '%*s' $((40 - ${#ACCT1})) '')  \$$AMOUNT
    $ACCT2

EOF

echo ""
echo "✅ Added: $DATE $DESC — \$$AMOUNT"
echo "   $ACCT1 → $ACCT2"

# Show updated balance for the expense account
echo ""
echo "Updated balance for $ACCT1:"
hledger -f "$JOURNAL" balance "$ACCT1" 2>/dev/null || echo "  (run 'hledger balance' to verify)"
