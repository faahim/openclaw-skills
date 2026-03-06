#!/bin/bash
# Expense Splitter — Local bill splitting with SQLite persistence
# Like Splitwise but self-hosted, no accounts, no cloud
set -euo pipefail

DB_DIR="${EXPENSE_SPLITTER_DIR:-$HOME/.expense-splitter}"
DB_FILE="$DB_DIR/expenses.db"

init_db() {
  mkdir -p "$DB_DIR"
  sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE IF NOT EXISTS groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  UNIQUE(group_id, name),
  FOREIGN KEY(group_id) REFERENCES groups(id)
);
CREATE TABLE IF NOT EXISTS expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL,
  description TEXT NOT NULL,
  amount REAL NOT NULL,
  paid_by INTEGER NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(group_id) REFERENCES groups(id),
  FOREIGN KEY(paid_by) REFERENCES members(id)
);
CREATE TABLE IF NOT EXISTS expense_splits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  expense_id INTEGER NOT NULL,
  member_id INTEGER NOT NULL,
  share REAL NOT NULL,
  FOREIGN KEY(expense_id) REFERENCES expenses(id),
  FOREIGN KEY(member_id) REFERENCES members(id)
);
CREATE TABLE IF NOT EXISTS settlements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL,
  from_member INTEGER NOT NULL,
  to_member INTEGER NOT NULL,
  amount REAL NOT NULL,
  settled_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(group_id) REFERENCES groups(id),
  FOREIGN KEY(from_member) REFERENCES members(id),
  FOREIGN KEY(to_member) REFERENCES members(id)
);
SQL
  echo "✅ Database initialized at $DB_FILE"
}

create_group() {
  local name="$1"
  shift
  local members=("$@")
  
  if [ ${#members[@]} -lt 2 ]; then
    echo "❌ Need at least 2 members. Usage: expense-splitter create-group <name> <member1> <member2> [...]"
    exit 1
  fi
  
  init_db 2>/dev/null
  
  sqlite3 "$DB_FILE" "INSERT INTO groups (name) VALUES ('$name');"
  local gid=$(sqlite3 "$DB_FILE" "SELECT id FROM groups WHERE name='$name';")
  
  for member in "${members[@]}"; do
    sqlite3 "$DB_FILE" "INSERT INTO members (group_id, name) VALUES ($gid, '$member');"
  done
  
  echo "✅ Group '$name' created with members: ${members[*]}"
}

list_groups() {
  init_db 2>/dev/null
  echo "📋 Groups:"
  echo "---"
  sqlite3 -header -column "$DB_FILE" \
    "SELECT g.id, g.name, COUNT(m.id) as members, g.created_at 
     FROM groups g LEFT JOIN members m ON g.id = m.group_id 
     GROUP BY g.id;"
}

add_expense() {
  local group="$1"
  local paid_by="$2"
  local amount="$3"
  local description="$4"
  local split_type="${5:-equal}"  # equal, exact, percentage
  shift 5 2>/dev/null || true
  local split_args=("$@")
  
  local gid=$(sqlite3 "$DB_FILE" "SELECT id FROM groups WHERE name='$group';")
  if [ -z "$gid" ]; then
    echo "❌ Group '$group' not found"
    exit 1
  fi
  
  local payer_id=$(sqlite3 "$DB_FILE" "SELECT id FROM members WHERE group_id=$gid AND name='$paid_by';")
  if [ -z "$payer_id" ]; then
    echo "❌ Member '$paid_by' not found in group '$group'"
    exit 1
  fi
  
  local eid=$(sqlite3 "$DB_FILE" "INSERT INTO expenses (group_id, description, amount, paid_by) VALUES ($gid, '$description', $amount, $payer_id); SELECT last_insert_rowid();")
  
  if [ "$split_type" = "equal" ]; then
    local member_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM members WHERE group_id=$gid;")
    local share=$(echo "scale=2; $amount / $member_count" | bc)
    sqlite3 "$DB_FILE" \
      "INSERT INTO expense_splits (expense_id, member_id, share)
       SELECT $eid, id, $share FROM members WHERE group_id=$gid;"
  elif [ "$split_type" = "exact" ]; then
    # split_args: member1:amount member2:amount ...
    for arg in "${split_args[@]}"; do
      local member="${arg%%:*}"
      local share="${arg##*:}"
      local mid=$(sqlite3 "$DB_FILE" "SELECT id FROM members WHERE group_id=$gid AND name='$member';")
      sqlite3 "$DB_FILE" "INSERT INTO expense_splits (expense_id, member_id, share) VALUES ($eid, $mid, $share);"
    done
  elif [ "$split_type" = "percentage" ]; then
    for arg in "${split_args[@]}"; do
      local member="${arg%%:*}"
      local pct="${arg##*:}"
      local share=$(echo "scale=2; $amount * $pct / 100" | bc)
      local mid=$(sqlite3 "$DB_FILE" "SELECT id FROM members WHERE group_id=$gid AND name='$member';")
      sqlite3 "$DB_FILE" "INSERT INTO expense_splits (expense_id, member_id, share) VALUES ($eid, $mid, $share);"
    done
  fi
  
  echo "✅ Added: $paid_by paid \$$amount for '$description' (split: $split_type)"
}

show_balances() {
  local group="$1"
  local gid=$(sqlite3 "$DB_FILE" "SELECT id FROM groups WHERE name='$group';")
  if [ -z "$gid" ]; then
    echo "❌ Group '$group' not found"
    exit 1
  fi
  
  echo "💰 Balances for '$group':"
  echo "---"
  
  # For each member: (total paid) - (total owed) = net balance
  sqlite3 "$DB_FILE" <<SQL
.mode column
.headers on
SELECT 
  m.name,
  COALESCE(paid.total_paid, 0) as total_paid,
  COALESCE(owed.total_owed, 0) as total_owed,
  COALESCE(settled_out.total_out, 0) as settled_paid,
  COALESCE(settled_in.total_in, 0) as settled_received,
  ROUND(COALESCE(paid.total_paid, 0) - COALESCE(owed.total_owed, 0) - COALESCE(settled_in.total_in, 0) + COALESCE(settled_out.total_out, 0), 2) as net_balance
FROM members m
LEFT JOIN (
  SELECT paid_by, SUM(amount) as total_paid 
  FROM expenses WHERE group_id=$gid GROUP BY paid_by
) paid ON m.id = paid.paid_by
LEFT JOIN (
  SELECT es.member_id, SUM(es.share) as total_owed 
  FROM expense_splits es 
  JOIN expenses e ON es.expense_id = e.id 
  WHERE e.group_id=$gid GROUP BY es.member_id
) owed ON m.id = owed.member_id
LEFT JOIN (
  SELECT from_member, SUM(amount) as total_out
  FROM settlements WHERE group_id=$gid GROUP BY from_member
) settled_out ON m.id = settled_out.from_member
LEFT JOIN (
  SELECT to_member, SUM(amount) as total_in
  FROM settlements WHERE group_id=$gid GROUP BY to_member
) settled_in ON m.id = settled_in.to_member
WHERE m.group_id=$gid;
SQL
}

calculate_settlements() {
  local group="$1"
  local gid=$(sqlite3 "$DB_FILE" "SELECT id FROM groups WHERE name='$group';")
  if [ -z "$gid" ]; then
    echo "❌ Group '$group' not found"
    exit 1
  fi
  
  echo "🔄 Optimal settlements for '$group':"
  echo "---"
  
  # Get net balances into temp file
  local tmpfile=$(mktemp)
  sqlite3 "$DB_FILE" <<SQL > "$tmpfile"
SELECT 
  m.name,
  ROUND(COALESCE(paid.total_paid, 0) - COALESCE(owed.total_owed, 0) - COALESCE(settled_in.total_in, 0) + COALESCE(settled_out.total_out, 0), 2)
FROM members m
LEFT JOIN (
  SELECT paid_by, SUM(amount) as total_paid 
  FROM expenses WHERE group_id=$gid GROUP BY paid_by
) paid ON m.id = paid.paid_by
LEFT JOIN (
  SELECT es.member_id, SUM(es.share) as total_owed 
  FROM expense_splits es 
  JOIN expenses e ON es.expense_id = e.id 
  WHERE e.group_id=$gid GROUP BY es.member_id
) owed ON m.id = owed.member_id
LEFT JOIN (
  SELECT from_member, SUM(amount) as total_out
  FROM settlements WHERE group_id=$gid GROUP BY from_member
) settled_out ON m.id = settled_out.from_member
LEFT JOIN (
  SELECT to_member, SUM(amount) as total_in
  FROM settlements WHERE group_id=$gid GROUP BY to_member
) settled_in ON m.id = settled_in.to_member
WHERE m.group_id=$gid;
SQL

  # Use Python for optimal settlement calculation (greedy algorithm)
  python3 -c "
import sys

balances = {}
for line in open('$tmpfile'):
    parts = line.strip().split('|')
    if len(parts) == 2:
        name, bal = parts[0].strip(), float(parts[1].strip())
        if abs(bal) > 0.01:
            balances[name] = bal

debtors = sorted([(n, -b) for n, b in balances.items() if b < -0.01], key=lambda x: -x[1])
creditors = sorted([(n, b) for n, b in balances.items() if b > 0.01], key=lambda x: -x[1])

if not debtors:
    print('✅ All settled up! No payments needed.')
    sys.exit(0)

settlements = []
di, ci = 0, 0
while di < len(debtors) and ci < len(creditors):
    debtor, debt = debtors[di]
    creditor, credit = creditors[ci]
    amount = min(debt, credit)
    settlements.append((debtor, creditor, amount))
    debtors[di] = (debtor, debt - amount)
    creditors[ci] = (creditor, credit - amount)
    if debtors[di][1] < 0.01:
        di += 1
    if creditors[ci][1] < 0.01:
        ci += 1

for debtor, creditor, amount in settlements:
    print(f'  💸 {debtor} → {creditor}: \${amount:.2f}')
print(f'\n📊 {len(settlements)} payment(s) to settle all debts')
"
  rm -f "$tmpfile"
}

record_settlement() {
  local group="$1"
  local from="$2"
  local to="$3"
  local amount="$4"
  
  local gid=$(sqlite3 "$DB_FILE" "SELECT id FROM groups WHERE name='$group';")
  local from_id=$(sqlite3 "$DB_FILE" "SELECT id FROM members WHERE group_id=$gid AND name='$from';")
  local to_id=$(sqlite3 "$DB_FILE" "SELECT id FROM members WHERE group_id=$gid AND name='$to';")
  
  sqlite3 "$DB_FILE" \
    "INSERT INTO settlements (group_id, from_member, to_member, amount) VALUES ($gid, $from_id, $to_id, $amount);"
  
  echo "✅ Recorded: $from paid \$$amount to $to"
}

show_history() {
  local group="$1"
  local gid=$(sqlite3 "$DB_FILE" "SELECT id FROM groups WHERE name='$group';")
  
  echo "📜 Expense history for '$group':"
  echo "---"
  sqlite3 -header -column "$DB_FILE" \
    "SELECT e.id, e.description, e.amount, m.name as paid_by, e.created_at
     FROM expenses e JOIN members m ON e.paid_by = m.id
     WHERE e.group_id=$gid ORDER BY e.created_at DESC LIMIT 50;"
}

export_csv() {
  local group="$1"
  local output="${2:-expenses-export.csv}"
  local gid=$(sqlite3 "$DB_FILE" "SELECT id FROM groups WHERE name='$group';")
  
  sqlite3 -header -csv "$DB_FILE" \
    "SELECT e.description, e.amount, m.name as paid_by, e.created_at
     FROM expenses e JOIN members m ON e.paid_by = m.id
     WHERE e.group_id=$gid ORDER BY e.created_at;" > "$output"
  
  echo "✅ Exported to $output"
}

delete_expense() {
  local expense_id="$1"
  sqlite3 "$DB_FILE" "DELETE FROM expense_splits WHERE expense_id=$expense_id;"
  sqlite3 "$DB_FILE" "DELETE FROM expenses WHERE id=$expense_id;"
  echo "✅ Expense #$expense_id deleted"
}

show_summary() {
  local group="$1"
  local gid=$(sqlite3 "$DB_FILE" "SELECT id FROM groups WHERE name='$group';")
  
  echo "📊 Summary for '$group':"
  echo "---"
  sqlite3 "$DB_FILE" <<SQL
SELECT '  Total expenses: $' || COALESCE(SUM(amount), 0) FROM expenses WHERE group_id=$gid;
SELECT '  Number of expenses: ' || COUNT(*) FROM expenses WHERE group_id=$gid;
SELECT '  Members: ' || GROUP_CONCAT(name, ', ') FROM members WHERE group_id=$gid;
SQL
  echo ""
  sqlite3 "$DB_FILE" <<SQL
.mode column
.headers on
SELECT m.name as "Top Spender", SUM(e.amount) as total_paid
FROM expenses e JOIN members m ON e.paid_by = m.id
WHERE e.group_id=$gid
GROUP BY m.name
ORDER BY total_paid DESC;
SQL
}

usage() {
  cat <<'HELP'
Expense Splitter — Local bill splitting with SQLite

USAGE:
  expense-splitter <command> [args...]

COMMANDS:
  init                                     Initialize database
  create-group <name> <m1> <m2> [...]     Create a group with members
  list-groups                              List all groups
  add <group> <payer> <amount> <desc>     Add expense (equal split)
  add <group> <payer> <amount> <desc> exact <m1:amt> <m2:amt>
                                           Add with exact split
  add <group> <payer> <amount> <desc> percentage <m1:pct> <m2:pct>
                                           Add with percentage split
  balances <group>                         Show member balances
  settle <group>                           Calculate optimal settlements
  record-settle <group> <from> <to> <amt> Record a settlement payment
  history <group>                          Show expense history
  summary <group>                          Show group summary stats
  export <group> [file.csv]               Export expenses to CSV
  delete <expense_id>                      Delete an expense

EXAMPLES:
  expense-splitter create-group roadtrip Alice Bob Charlie
  expense-splitter add roadtrip Alice 90 "Gas"
  expense-splitter add roadtrip Bob 60 "Food"
  expense-splitter add roadtrip Alice 45 "Tolls" exact Alice:15 Bob:15 Charlie:15
  expense-splitter balances roadtrip
  expense-splitter settle roadtrip
  expense-splitter record-settle roadtrip Charlie Alice 25
  expense-splitter export roadtrip trip-expenses.csv
HELP
}

# Main command dispatch
case "${1:-help}" in
  init) init_db ;;
  create-group) shift; create_group "$@" ;;
  list-groups|list) list_groups ;;
  add) shift; add_expense "$@" ;;
  balances|bal) shift; show_balances "$@" ;;
  settle|settlements) shift; calculate_settlements "$@" ;;
  record-settle) shift; record_settlement "$@" ;;
  history) shift; show_history "$@" ;;
  summary) shift; show_summary "$@" ;;
  export) shift; export_csv "$@" ;;
  delete) shift; delete_expense "$@" ;;
  help|--help|-h) usage ;;
  *) echo "❌ Unknown command: $1"; usage; exit 1 ;;
esac
