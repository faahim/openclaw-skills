---
name: expense-splitter
description: >-
  Split shared expenses between friends, roommates, or travel groups. Track who paid what, calculate optimal settlements, export to CSV. Like Splitwise but local and free.
categories: [finance, productivity]
dependencies: [sqlite3, python3, bc]
---

# Expense Splitter

## What This Does

Split shared expenses between groups of people — roommates, road trips, dinner groups, travel buddies. Tracks who paid what, calculates who owes whom, and finds the optimal number of payments to settle all debts. All data stored locally in SQLite — no cloud, no accounts, no subscriptions.

**Example:** 3 friends on a road trip. Alice pays $90 for gas, Bob pays $60 for food, Charlie pays nothing. The splitter calculates: Charlie owes Alice $20 and Bob $10. One command.

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Check required tools (usually pre-installed on Linux/Mac)
which sqlite3 python3 bc || echo "Install: sudo apt install sqlite3 python3 bc"

# Make the script executable
chmod +x scripts/expense-splitter.sh

# Optional: add to PATH
sudo ln -sf "$(pwd)/scripts/expense-splitter.sh" /usr/local/bin/expense-splitter
```

### 2. Create a Group

```bash
bash scripts/expense-splitter.sh create-group roadtrip Alice Bob Charlie
# ✅ Group 'roadtrip' created with members: Alice Bob Charlie
```

### 3. Add Expenses

```bash
# Alice paid $90 for gas (split equally)
bash scripts/expense-splitter.sh add roadtrip Alice 90 "Gas"

# Bob paid $60 for food (split equally)
bash scripts/expense-splitter.sh add roadtrip Bob 60 "Food"

# Alice paid $45 for hotel (split equally)
bash scripts/expense-splitter.sh add roadtrip Alice 45 "Hotel"
```

### 4. Check Balances

```bash
bash scripts/expense-splitter.sh balances roadtrip
# Shows each person's net balance (positive = owed money, negative = owes money)
```

### 5. Calculate Settlements

```bash
bash scripts/expense-splitter.sh settle roadtrip
# 🔄 Optimal settlements:
#   💸 Charlie → Alice: $45.00
#   💸 Charlie → Bob: $20.00
#   💸 Bob → Alice: $15.00
```

## Core Workflows

### Workflow 1: Equal Split (Default)

Most common — everyone pays the same share.

```bash
bash scripts/expense-splitter.sh add roommates Alex 120 "Electricity bill"
# $120 / 3 roommates = $40 each
```

### Workflow 2: Exact Split

When shares aren't equal (e.g., one person ate more).

```bash
bash scripts/expense-splitter.sh add dinner Sam 85 "Sushi dinner" exact Sam:35 Kim:25 Pat:25
```

### Workflow 3: Percentage Split

Split by percentage (e.g., income-based rent).

```bash
bash scripts/expense-splitter.sh add apartment Dana 2400 "March rent" percentage Dana:50 Alex:30 Sam:20
# Dana: $1200, Alex: $720, Sam: $480
```

### Workflow 4: Record a Settlement

When someone pays their debt:

```bash
bash scripts/expense-splitter.sh record-settle roadtrip Charlie Alice 45
# ✅ Recorded: Charlie paid $45 to Alice

# Recalculate to see remaining debts
bash scripts/expense-splitter.sh settle roadtrip
```

### Workflow 5: Export for Records

```bash
bash scripts/expense-splitter.sh export roadtrip trip-expenses.csv
# ✅ Exported to trip-expenses.csv
```

### Workflow 6: Group Summary

```bash
bash scripts/expense-splitter.sh summary roadtrip
# 📊 Summary for 'roadtrip':
#   Total expenses: $195
#   Number of expenses: 3
#   Members: Alice, Bob, Charlie
#   Top Spender: Alice ($135)
```

## Configuration

### Custom Database Location

```bash
export EXPENSE_SPLITTER_DIR="$HOME/Documents/expenses"
bash scripts/expense-splitter.sh init
```

### Multiple Groups

Run as many groups as needed — roommates, trips, dinners, projects:

```bash
bash scripts/expense-splitter.sh create-group roommates Alex Dana Sam
bash scripts/expense-splitter.sh create-group eurotrip Alex Kim Pat Lee
bash scripts/expense-splitter.sh create-group poker-night Sam Kim Alex Dana
bash scripts/expense-splitter.sh list-groups
```

## Advanced Usage

### View Expense History

```bash
bash scripts/expense-splitter.sh history roommates
# Shows last 50 expenses with dates, amounts, and who paid
```

### Delete a Wrong Entry

```bash
bash scripts/expense-splitter.sh history roommates  # Find the ID
bash scripts/expense-splitter.sh delete 7            # Delete expense #7
```

### Automate with OpenClaw Cron

Set up monthly rent splitting:

```bash
# Add to OpenClaw cron: first of every month
bash scripts/expense-splitter.sh add apartment Dana 2400 "$(date +%B) rent"
bash scripts/expense-splitter.sh settle apartment
```

## Troubleshooting

### Issue: "sqlite3: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install sqlite3

# Mac
brew install sqlite3

# Alpine
apk add sqlite
```

### Issue: "python3: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install python3

# Mac (usually pre-installed)
brew install python3
```

### Issue: Rounding errors in splits

The tool rounds to 2 decimal places. For large groups, there may be ±$0.01 differences. This is normal and handled in settlement calculation.

### Issue: Wrong expense added

Use `history` to find the ID, then `delete` to remove it:

```bash
bash scripts/expense-splitter.sh history mygroup
bash scripts/expense-splitter.sh delete <id>
```

## How Settlement Optimization Works

The tool uses a greedy algorithm to minimize the number of payments:

1. Calculate each person's net balance (paid - owed)
2. Sort debtors (negative balance) and creditors (positive balance)
3. Match largest debtor to largest creditor
4. Repeat until all debts are settled

For N people, this produces at most N-1 payments (optimal for most cases).

## Dependencies

- `sqlite3` (3.x+) — persistent storage
- `python3` (3.6+) — settlement optimization algorithm
- `bc` — precise decimal arithmetic
- `bash` (4.0+) — script runtime

## Key Principles

1. **Local first** — All data in SQLite, no cloud sync
2. **Simple CLI** — One command per action
3. **Accurate math** — Proper decimal handling, no floating-point surprises
4. **Minimal deps** — sqlite3 + python3 + bc (usually pre-installed)
5. **Multiple groups** — Track roommates, trips, and dinners separately
