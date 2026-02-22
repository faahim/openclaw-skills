#!/bin/bash
# Budget Tracker — CLI expense & income tracker
# Usage: bash budget.sh <command> [options]

set -euo pipefail

# Config
DATA_DIR="${BUDGET_TRACKER_DIR:-$HOME/.budget-tracker}"
CURRENCY="${BUDGET_CURRENCY:-\$}"
TX_FILE="$DATA_DIR/transactions.json"
BUDGET_FILE="$DATA_DIR/budgets.json"
CAT_FILE="$DATA_DIR/categories.json"
EXPORT_DIR="$DATA_DIR/exports"

DEFAULT_CATEGORIES='["groceries","food","transport","entertainment","utilities","rent","health","shopping","subscriptions","education","other"]'

# --- Helpers ---

die() { echo "❌ $*" >&2; exit 1; }
info() { echo "✅ $*"; }
warn() { echo "⚠️  $*"; }

ensure_init() {
  [[ -f "$TX_FILE" ]] || die "Not initialized. Run: bash budget.sh init"
}

gen_id() {
  echo "tx_$(date +%s)_$RANDOM"
}

now_date() {
  date -u +%Y-%m-%d
}

now_month() {
  date -u +%Y-%m
}

fmt_money() {
  printf "%s%.2f" "$CURRENCY" "$1"
}

# --- Commands ---

cmd_init() {
  local force=false
  [[ "${1:-}" == "--force" ]] && force=true

  if [[ -f "$TX_FILE" && "$force" == "false" ]]; then
    die "Already initialized at $DATA_DIR. Use --force to reinitialize."
  fi

  mkdir -p "$DATA_DIR" "$EXPORT_DIR"
  echo '[]' > "$TX_FILE"
  echo '{}' > "$BUDGET_FILE"
  echo "$DEFAULT_CATEGORIES" > "$CAT_FILE"

  info "Budget tracker initialized at $DATA_DIR/"
  echo "   Created: transactions.json, budgets.json, categories.json"
}

cmd_add() {
  ensure_init
  local amount="" category="" note="" type="expense" date=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --amount) amount="$2"; shift 2 ;;
      --category) category="$2"; shift 2 ;;
      --note) note="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --date) date="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$amount" ]] && die "Missing --amount"
  [[ -z "$category" ]] && die "Missing --category"
  [[ -z "$date" ]] && date="$(now_date)"

  # Validate category exists (auto-add if not)
  local cats
  cats=$(cat "$CAT_FILE")
  if ! echo "$cats" | jq -e --arg c "$category" 'index($c) != null' >/dev/null 2>&1; then
    echo "$cats" | jq --arg c "$category" '. + [$c]' > "$CAT_FILE"
  fi

  local id sign display_amount
  id=$(gen_id)

  if [[ "$type" == "income" ]]; then
    sign="+"
    display_amount="+$(fmt_money "$amount")"
  else
    sign="-"
    display_amount="-$(fmt_money "$amount")"
  fi

  # Add transaction
  local tx
  tx=$(jq -n \
    --arg id "$id" \
    --arg date "$date" \
    --arg type "$type" \
    --arg category "$category" \
    --argjson amount "$amount" \
    --arg note "$note" \
    '{id: $id, date: $date, type: $type, category: $category, amount: $amount, note: $note}')

  jq --argjson tx "$tx" '. + [$tx]' "$TX_FILE" > "$TX_FILE.tmp" && mv "$TX_FILE.tmp" "$TX_FILE"

  info "Added: $display_amount [$category] \"$note\" ($date)"
}

cmd_budget() {
  ensure_init
  local category="" limit=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --category) category="$2"; shift 2 ;;
      --limit) limit="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$category" ]] && die "Missing --category"
  [[ -z "$limit" ]] && die "Missing --limit"

  jq --arg cat "$category" --argjson limit "$limit" '.[$cat] = $limit' "$BUDGET_FILE" > "$BUDGET_FILE.tmp" && mv "$BUDGET_FILE.tmp" "$BUDGET_FILE"

  info "Budget set: $category = $(fmt_money "$limit")/month"
}

cmd_status() {
  ensure_init
  local month
  month="${1:-$(now_month)}"

  echo "📊 Budget Status — $month"
  echo ""

  local budgets
  budgets=$(cat "$BUDGET_FILE")
  local tx_data
  tx_data=$(cat "$TX_FILE")

  local total_spent=0 total_budget=0

  # Header
  printf "%-16s %10s %10s %10s %6s\n" "Category" "Budget" "Spent" "Left" "%"
  printf "%-16s %10s %10s %10s %6s\n" "────────────" "──────" "──────" "──────" "────"

  echo "$budgets" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read -r cat limit; do
    local spent
    spent=$(echo "$tx_data" | jq --arg m "$month" --arg c "$cat" \
      '[.[] | select(.type == "expense" and .category == $c and (.date | startswith($m))) | .amount] | add // 0')

    local left pct
    left=$(echo "$limit - $spent" | bc)
    if (( $(echo "$limit > 0" | bc -l) )); then
      pct=$(echo "scale=0; $spent * 100 / $limit" | bc)
    else
      pct=0
    fi

    total_spent=$(echo "$total_spent + $spent" | bc)
    total_budget=$(echo "$total_budget + $limit" | bc)

    printf "%-16s %10s %10s %10s %5s%%\n" "$cat" "$(fmt_money "$limit")" "$(fmt_money "$spent")" "$(fmt_money "$left")" "$pct"
  done

  echo ""
  echo "Total spent: $(fmt_money "$total_spent") / $(fmt_money "$total_budget")"
}

cmd_report() {
  ensure_init
  local month
  month="${1:-$(now_month)}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --month) month="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local tx_data
  tx_data=$(cat "$TX_FILE")

  local income expenses
  income=$(echo "$tx_data" | jq --arg m "$month" \
    '[.[] | select(.type == "income" and (.date | startswith($m))) | .amount] | add // 0')
  expenses=$(echo "$tx_data" | jq --arg m "$month" \
    '[.[] | select(.type == "expense" and (.date | startswith($m))) | .amount] | add // 0')

  local net
  net=$(echo "$income - $expenses" | bc)

  echo "📊 Monthly Report — $month"
  echo ""
  echo "INCOME:     $(fmt_money "$income")"
  echo "EXPENSES:   $(fmt_money "$expenses")"

  if (( $(echo "$net >= 0" | bc -l) )); then
    echo "NET:        +$(fmt_money "$net")"
  else
    echo "NET:        -$(fmt_money "${net#-}")"
  fi

  echo ""
  echo "Top Categories:"
  echo "$tx_data" | jq -r --arg m "$month" '
    [.[] | select(.type == "expense" and (.date | startswith($m)))]
    | group_by(.category)
    | map({category: .[0].category, total: (map(.amount) | add)})
    | sort_by(-.total)
    | to_entries[]
    | "  \(.key + 1). \(.value.category)\t$\(.value.total)"
  '

  # Daily average
  local day_of_month
  day_of_month=$(date -u +%-d)
  if (( day_of_month > 0 )); then
    local daily_avg projected
    daily_avg=$(echo "scale=2; $expenses / $day_of_month" | bc)
    projected=$(echo "scale=2; $daily_avg * 30" | bc)
    echo ""
    echo "Daily average: $(fmt_money "$daily_avg")"
    echo "Projected month-end: $(fmt_money "$projected")"
  fi
}

cmd_list() {
  ensure_init
  local search="" category="" from="" to="" last="" show_id=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --search) search="$2"; shift 2 ;;
      --category) category="$2"; shift 2 ;;
      --from) from="$2"; shift 2 ;;
      --to) to="$2"; shift 2 ;;
      --last) last="$2"; shift 2 ;;
      --show-id) show_id=true; shift ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  local filter='.'
  [[ -n "$category" ]] && filter="$filter | select(.category == \"$category\")"
  [[ -n "$from" ]] && filter="$filter | select(.date >= \"$from\")"
  [[ -n "$to" ]] && filter="$filter | select(.date <= \"$to\")"
  [[ -n "$search" ]] && filter="$filter | select(.note | test(\"$search\"; \"i\"))"

  local result
  result=$(jq "[.[] | $filter]" "$TX_FILE")

  [[ -n "$last" ]] && result=$(echo "$result" | jq ".[-$last:]")

  local count
  count=$(echo "$result" | jq 'length')
  echo "📋 Transactions ($count):"
  echo ""

  if [[ "$show_id" == "true" ]]; then
    echo "$result" | jq -r '.[] | "\(.date) \(if .type == "income" then "+" else "-" end)$\(.amount) [\(.category)] \(.note) (ID: \(.id))"'
  else
    echo "$result" | jq -r '.[] | "\(.date) \(if .type == "income" then "+" else "-" end)$\(.amount) [\(.category)] \(.note)"'
  fi
}

cmd_delete() {
  ensure_init
  local id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$id" ]] && die "Missing --id"

  local exists
  exists=$(jq --arg id "$id" '[.[] | select(.id == $id)] | length' "$TX_FILE")
  [[ "$exists" == "0" ]] && die "Transaction $id not found"

  jq --arg id "$id" '[.[] | select(.id != $id)]' "$TX_FILE" > "$TX_FILE.tmp" && mv "$TX_FILE.tmp" "$TX_FILE"

  info "Deleted transaction $id"
}

cmd_edit() {
  ensure_init
  local id="" amount="" category="" note=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      --amount) amount="$2"; shift 2 ;;
      --category) category="$2"; shift 2 ;;
      --note) note="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$id" ]] && die "Missing --id"

  local update='.'
  [[ -n "$amount" ]] && update="$update | if .id == \$id then .amount = ($amount) else . end"
  [[ -n "$category" ]] && update="$update | if .id == \$id then .category = \$cat else . end"
  [[ -n "$note" ]] && update="$update | if .id == \$id then .note = \$note else . end"

  jq --arg id "$id" --arg cat "${category:-}" --arg note "${note:-}" "[.[] | $update]" "$TX_FILE" > "$TX_FILE.tmp" && mv "$TX_FILE.tmp" "$TX_FILE"

  info "Updated transaction $id"
}

cmd_export() {
  ensure_init
  local output="" month=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output) output="$2"; shift 2 ;;
      --month) month="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$output" ]] && output="$EXPORT_DIR/export-$(now_date).csv"

  local filter='.'
  [[ -n "$month" ]] && filter="select(.date | startswith(\"$month\"))"

  echo "date,type,category,amount,note,id" > "$output"
  jq -r "[.[] | $filter] | .[] | \"\(.date),\(.type),\(.category),\(.amount),\\\"\(.note)\\\",\(.id)\"" "$TX_FILE" >> "$output"

  local count
  count=$(tail -n +2 "$output" | wc -l | tr -d ' ')
  info "Exported $count transactions to $output"
}

cmd_summary() {
  ensure_init
  local year=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --year) year="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$year" ]] && year=$(date -u +%Y)

  local tx_data
  tx_data=$(cat "$TX_FILE")

  local income expenses net savings_rate
  income=$(echo "$tx_data" | jq --arg y "$year" \
    '[.[] | select(.type == "income" and (.date | startswith($y))) | .amount] | add // 0')
  expenses=$(echo "$tx_data" | jq --arg y "$year" \
    '[.[] | select(.type == "expense" and (.date | startswith($y))) | .amount] | add // 0')
  net=$(echo "$income - $expenses" | bc)

  if (( $(echo "$income > 0" | bc -l) )); then
    savings_rate=$(echo "scale=1; $net * 100 / $income" | bc)
  else
    savings_rate="0.0"
  fi

  echo "📊 Year-to-Date — $year"
  echo ""
  echo "Total Income:   $(fmt_money "$income")"
  echo "Total Expenses: $(fmt_money "$expenses")"
  echo "Net Savings:    $(fmt_money "$net")"
  echo "Savings Rate:   ${savings_rate}%"
}

cmd_alerts() {
  ensure_init
  local month
  month=$(now_month)

  local budgets tx_data has_alert=false
  budgets=$(cat "$BUDGET_FILE")
  tx_data=$(cat "$TX_FILE")

  echo "$budgets" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read -r cat limit; do
    local spent pct
    spent=$(echo "$tx_data" | jq --arg m "$month" --arg c "$cat" \
      '[.[] | select(.type == "expense" and .category == $c and (.date | startswith($m))) | .amount] | add // 0')

    if (( $(echo "$limit > 0" | bc -l) )); then
      pct=$(echo "scale=0; $spent * 100 / $limit" | bc)
      if (( pct >= 100 )); then
        echo "🔴 $cat: $(fmt_money "$spent")/$(fmt_money "$limit") (${pct}%) — OVER BUDGET!"
        has_alert=true
      elif (( pct >= 80 )); then
        echo "⚠️  $cat: $(fmt_money "$spent")/$(fmt_money "$limit") (${pct}%) — nearly over budget!"
        has_alert=true
      fi
    fi
  done

  [[ "$has_alert" == "false" ]] && echo "✅ All categories within budget"
}

cmd_category() {
  ensure_init

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --add)
        local new_cat="$2"
        jq --arg c "$new_cat" '. + [$c] | unique' "$CAT_FILE" > "$CAT_FILE.tmp" && mv "$CAT_FILE.tmp" "$CAT_FILE"
        info "Added category: $new_cat"
        return
        ;;
      --list)
        echo "📂 Categories:"
        jq -r '.[]' "$CAT_FILE"
        return
        ;;
      *) die "Unknown option: $1" ;;
    esac
  done
}

# --- Main ---

CMD="${1:-help}"
shift || true

case "$CMD" in
  init)     cmd_init "$@" ;;
  add)      cmd_add "$@" ;;
  budget)   cmd_budget "$@" ;;
  status)   cmd_status "$@" ;;
  report)   cmd_report "$@" ;;
  list)     cmd_list "$@" ;;
  delete)   cmd_delete "$@" ;;
  edit)     cmd_edit "$@" ;;
  export)   cmd_export "$@" ;;
  summary)  cmd_summary "$@" ;;
  alerts)   cmd_alerts "$@" ;;
  category) cmd_category "$@" ;;
  help|*)
    echo "Budget Tracker — CLI expense & income tracker"
    echo ""
    echo "Usage: bash budget.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init                          Initialize data directory"
    echo "  add --amount N --category C   Add a transaction"
    echo "  budget --category C --limit N Set monthly budget"
    echo "  status                        Show budget vs spent"
    echo "  report [--month YYYY-MM]      Monthly spending report"
    echo "  list [--last N] [--category C] List transactions"
    echo "  delete --id ID                Delete a transaction"
    echo "  edit --id ID [--amount N]     Edit a transaction"
    echo "  export [--output file.csv]    Export to CSV"
    echo "  summary [--year YYYY]         Year-to-date summary"
    echo "  alerts                        Check budget alerts"
    echo "  category --add C | --list     Manage categories"
    ;;
esac
