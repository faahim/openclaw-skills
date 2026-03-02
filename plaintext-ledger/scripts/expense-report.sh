#!/bin/bash
# Generate expense report with visual breakdown
# Usage: expense-report.sh [--month YYYY-MM] [--year YYYY]
set -euo pipefail

JOURNAL="${LEDGER_FILE:-$HOME/finances/main.journal}"
PERIOD=""
PERIOD_LABEL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --month)
            MONTH="$2"
            # Calculate period boundaries
            PERIOD="-b ${MONTH}-01 -e $(date -d "${MONTH}-01 + 1 month" +%Y-%m-%d 2>/dev/null || date -v1d -v+1m -j -f "%Y-%m-%d" "${MONTH}-01" +%Y-%m-%d 2>/dev/null)"
            PERIOD_LABEL="$MONTH"
            shift 2
            ;;
        --year)
            YEAR="$2"
            PERIOD="-b ${YEAR}-01-01 -e $((YEAR + 1))-01-01"
            PERIOD_LABEL="$YEAR"
            shift 2
            ;;
        *) echo "Usage: expense-report.sh [--month YYYY-MM] [--year YYYY]"; exit 1 ;;
    esac
done

if [[ -z "$PERIOD_LABEL" ]]; then
    PERIOD_LABEL="All Time"
fi

echo ""
echo "📊 Expense Report — $PERIOD_LABEL"
echo "─────────────────────────────────"
echo ""

# Get expense data as CSV
EXPENSE_DATA=$(hledger -f "$JOURNAL" balance expenses $PERIOD --depth 2 --format '%(account)  %(total)\n' --no-total 2>/dev/null || echo "")

if [[ -z "$EXPENSE_DATA" ]]; then
    echo "No expenses found for this period."
    exit 0
fi

# Calculate total
TOTAL=$(hledger -f "$JOURNAL" balance expenses $PERIOD --depth 1 --format '%(total)\n' --no-total 2>/dev/null | tr -d '$,' | xargs)

# Display each category with bar
echo "$EXPENSE_DATA" | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    ACCT=$(echo "$line" | sed 's/  .*//' | xargs)
    AMT=$(echo "$line" | grep -oP '\$[\d,]+\.?\d*' | tr -d '$,' || echo "0")

    if [[ -n "$AMT" ]] && [[ "$TOTAL" != "0" ]]; then
        PCT=$(echo "scale=1; $AMT / ${TOTAL:-1} * 100" | bc 2>/dev/null || echo "0")
        BAR_LEN=$(echo "scale=0; $AMT / ${TOTAL:-1} * 30" | bc 2>/dev/null || echo "1")
        BAR=$(printf '█%.0s' $(seq 1 ${BAR_LEN:-1}) 2>/dev/null || echo "█")
        printf "  %-25s %10s  (%5s%%)  %s\n" "$ACCT" "\$$AMT" "$PCT" "$BAR"
    fi
done

echo "─────────────────────────────────"
printf "  %-25s %10s\n" "Total" "\$${TOTAL}"
echo ""

# Show top 5 transactions
echo "Top 5 Transactions:"
hledger -f "$JOURNAL" register expenses $PERIOD --format '  %(date)  %-30.30description  %(amount)\n' 2>/dev/null | sort -t'$' -k2 -rn | head -5
echo ""
