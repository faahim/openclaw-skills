#!/bin/bash
# Quick one-liner transaction entry
# Usage: quick-add.sh "Description" amount [account] [source-account]
set -euo pipefail

JOURNAL="${LEDGER_FILE:-$HOME/finances/main.journal}"

DESC="${1:?Usage: quick-add.sh \"Description\" amount [expense-account] [source-account]}"
AMOUNT="${2:?Amount required}"
ACCT1="${3:-expenses:misc}"
ACCT2="${4:-assets:bank:checking}"
DATE=$(date +%Y-%m-%d)

cat >> "$JOURNAL" << EOF

$DATE $DESC
    $ACCT1$(printf '%*s' $((40 - ${#ACCT1})) '')  \$$AMOUNT
    $ACCT2

EOF

echo "✅ $DATE $DESC — \$$AMOUNT ($ACCT1)"
