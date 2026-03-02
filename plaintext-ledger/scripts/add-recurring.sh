#!/bin/bash
# Add a recurring transaction (periodic rule) to the journal
# Usage: add-recurring.sh "Description" amount account [frequency]
set -euo pipefail

JOURNAL="${LEDGER_FILE:-$HOME/finances/main.journal}"

DESC="${1:?Usage: add-recurring.sh \"Description\" amount account [monthly|weekly|yearly]}"
AMOUNT="${2:?Amount required}"
ACCT="${3:-expenses:subscriptions}"
FREQ="${4:-monthly}"

# Map frequency to hledger periodic syntax
case "$FREQ" in
    monthly)  PERIOD="~ monthly" ;;
    weekly)   PERIOD="~ weekly" ;;
    yearly)   PERIOD="~ yearly" ;;
    daily)    PERIOD="~ daily" ;;
    *)        PERIOD="~ $FREQ" ;;  # Allow custom like "every 2 weeks"
esac

cat >> "$JOURNAL" << EOF

; Recurring: $DESC ($FREQ)
$PERIOD $DESC
    $ACCT$(printf '%*s' $((40 - ${#ACCT})) '')  \$$AMOUNT
    assets:bank:checking

EOF

echo "✅ Added recurring $FREQ transaction: $DESC — \$$AMOUNT"
echo "   Use 'hledger balance --forecast' to include in projections"
