#!/bin/bash
# Invoice Ledger — Track invoice status
set -euo pipefail

LEDGER_FILE="${LEDGER_FILE:-$HOME/invoices/ledger.json}"

if [[ ! -f "$LEDGER_FILE" ]]; then
  echo "No invoices yet. Generate one first."
  exit 0
fi

ACTION=""
INV_NUMBER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --list) ACTION="list"; shift ;;
    --overdue) ACTION="overdue"; shift ;;
    --paid) ACTION="paid"; INV_NUMBER="$2"; shift 2 ;;
    --status) ACTION="status"; INV_NUMBER="$2"; shift 2 ;;
    --summary) ACTION="summary"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -z "$ACTION" ]] && ACTION="list"

case "$ACTION" in
  list)
    echo "# Invoice Ledger"
    echo ""
    printf "%-16s %-12s %-20s %12s  %s\n" "NUMBER" "DATE" "CLIENT" "TOTAL" "STATUS"
    printf "%-16s %-12s %-20s %12s  %s\n" "------" "----" "------" "-----" "------"
    jq -r '.invoices[] | [.number, .date, .client[:20], .total, .status] | @tsv' "$LEDGER_FILE" | \
      while IFS=$'\t' read -r num date client total status; do
        STATUS_ICON="⏳"
        [[ "$status" == "paid" ]] && STATUS_ICON="✅"
        TODAY=$(date +%Y-%m-%d)
        if [[ "$status" == "pending" ]]; then
          DUE=$(jq -r --arg n "$num" '.invoices[] | select(.number==$n) | .due_date' "$LEDGER_FILE")
          [[ "$TODAY" > "$DUE" ]] && STATUS_ICON="🔴" && status="OVERDUE"
        fi
        printf "%-16s %-12s %-20s %12s  %s %s\n" "$num" "$date" "$client" "$total" "$STATUS_ICON" "$status"
      done
    ;;
    
  overdue)
    TODAY=$(date +%Y-%m-%d)
    echo "# Overdue Invoices (as of $TODAY)"
    echo ""
    jq -r --arg today "$TODAY" '.invoices[] | select(.status=="pending" and .due_date < $today) | [.number, .due_date, .client, .total] | @tsv' "$LEDGER_FILE" | \
      while IFS=$'\t' read -r num due client total; do
        echo "🔴 $num — $client — $total (due: $due)"
      done
    ;;
    
  paid)
    jq --arg num "$INV_NUMBER" '(.invoices[] | select(.number==$num)).status = "paid"' "$LEDGER_FILE" > "${LEDGER_FILE}.tmp" \
      && mv "${LEDGER_FILE}.tmp" "$LEDGER_FILE"
    echo "✅ Marked $INV_NUMBER as paid"
    ;;
    
  summary)
    echo "# Invoice Summary"
    TOTAL_COUNT=$(jq '.invoices | length' "$LEDGER_FILE")
    PAID_COUNT=$(jq '[.invoices[] | select(.status=="paid")] | length' "$LEDGER_FILE")
    PENDING_COUNT=$(jq '[.invoices[] | select(.status=="pending")] | length' "$LEDGER_FILE")
    echo "Total invoices: $TOTAL_COUNT"
    echo "Paid: $PAID_COUNT"
    echo "Pending: $PENDING_COUNT"
    ;;
    
  status)
    jq -r --arg num "$INV_NUMBER" '.invoices[] | select(.number==$num) | "Invoice: \(.number)\nDate: \(.date)\nDue: \(.due_date)\nClient: \(.client)\nTotal: \(.total)\nStatus: \(.status)"' "$LEDGER_FILE"
    ;;
esac
