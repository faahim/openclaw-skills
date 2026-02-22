---
name: budget-tracker
description: >-
  Track expenses and income from the command line. Categorize transactions, set budgets, generate monthly reports, and export to CSV.
categories: [finance, productivity]
dependencies: [bash, jq, bc]
---

# Budget Tracker

## What This Does

Track personal or business expenses and income entirely from the command line. Add transactions with categories, set monthly budgets per category, get spending reports with breakdowns, and export everything to CSV. All data stored locally in JSON — no cloud, no subscriptions.

**Example:** "Add $45 grocery expense, check if I'm over budget this month, generate a spending report."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# These are usually pre-installed on Linux/Mac
which jq bc || sudo apt-get install -y jq bc  # Debian/Ubuntu
# or: brew install jq  # macOS
```

### 2. Initialize

```bash
# Create data directory
bash scripts/budget.sh init

# Output:
# ✅ Budget tracker initialized at ~/.budget-tracker/
# Created: transactions.json, budgets.json, categories.json
```

### 3. Add Your First Transaction

```bash
# Add an expense
bash scripts/budget.sh add --amount 45.50 --category groceries --note "Weekly shopping"

# Output:
# ✅ Added: -$45.50 [groceries] "Weekly shopping" (2026-02-22)
```

## Core Workflows

### Workflow 1: Track Daily Expenses

```bash
# Add expenses
bash scripts/budget.sh add --amount 45.50 --category groceries --note "Weekly shopping"
bash scripts/budget.sh add --amount 12.00 --category transport --note "Uber to office"
bash scripts/budget.sh add --amount 8.50 --category food --note "Lunch"

# Add income
bash scripts/budget.sh add --amount 3500 --category salary --type income --note "February salary"
```

### Workflow 2: Set Monthly Budgets

```bash
# Set budget limits per category
bash scripts/budget.sh budget --category groceries --limit 400
bash scripts/budget.sh budget --category food --limit 200
bash scripts/budget.sh budget --category transport --limit 150
bash scripts/budget.sh budget --category entertainment --limit 100

# Check budget status
bash scripts/budget.sh status

# Output:
# 📊 Budget Status — February 2026
# ┌──────────────┬────────┬────────┬────────┬───────┐
# │ Category     │ Budget │ Spent  │ Left   │ %     │
# ├──────────────┼────────┼────────┼────────┼───────┤
# │ groceries    │ $400   │ $45.50 │ $354.50│ 11%   │
# │ food         │ $200   │ $8.50  │ $191.50│ 4%    │
# │ transport    │ $150   │ $12.00 │ $138.00│ 8%    │
# │ entertainment│ $100   │ $0.00  │ $100.00│ 0%    │
# └──────────────┴────────┴────────┴────────┴───────┘
# Total spent: $66.00 / $850.00 (8%)
```

### Workflow 3: Monthly Report

```bash
# Current month report
bash scripts/budget.sh report

# Specific month
bash scripts/budget.sh report --month 2026-01

# Output:
# 📊 Monthly Report — February 2026
#
# INCOME:     $3,500.00
# EXPENSES:   $66.00
# NET:        +$3,434.00
#
# Top Categories:
#   1. groceries    $45.50  (68.9%)
#   2. transport    $12.00  (18.2%)
#   3. food         $8.50   (12.9%)
#
# Daily average: $3.00
# Projected month-end: $84.00
```

### Workflow 4: Export to CSV

```bash
# Export all transactions
bash scripts/budget.sh export --output expenses.csv

# Export specific month
bash scripts/budget.sh export --month 2026-02 --output feb-expenses.csv

# Output:
# ✅ Exported 15 transactions to feb-expenses.csv
```

### Workflow 5: Search & Filter

```bash
# Search by note
bash scripts/budget.sh list --search "uber"

# Filter by category
bash scripts/budget.sh list --category groceries

# Filter by date range
bash scripts/budget.sh list --from 2026-02-01 --to 2026-02-15

# Last N transactions
bash scripts/budget.sh list --last 10
```

### Workflow 6: Delete / Edit

```bash
# List recent with IDs
bash scripts/budget.sh list --last 5 --show-id

# Delete by ID
bash scripts/budget.sh delete --id tx_abc123

# Edit amount
bash scripts/budget.sh edit --id tx_abc123 --amount 50.00
```

## Configuration

### Data Location

All data stored at `~/.budget-tracker/`:

```
~/.budget-tracker/
├── transactions.json    # All transactions
├── budgets.json         # Monthly budget limits
├── categories.json      # Category list
└── exports/             # CSV exports
```

### Custom Categories

```bash
# Add custom category
bash scripts/budget.sh category --add "subscriptions"
bash scripts/budget.sh category --add "health"

# List all categories
bash scripts/budget.sh category --list

# Default categories: groceries, food, transport, entertainment,
# utilities, rent, health, shopping, subscriptions, education, other
```

### Environment Variables

```bash
# Custom data directory (default: ~/.budget-tracker)
export BUDGET_TRACKER_DIR="$HOME/.budget-tracker"

# Currency symbol (default: $)
export BUDGET_CURRENCY="$"
```

## Advanced Usage

### Recurring Transactions

```bash
# Add a recurring expense (use with cron)
# Add to crontab:
# 1 0 1 * * bash /path/to/budget.sh add --amount 1200 --category rent --note "Monthly rent"
# 1 0 1 * * bash /path/to/budget.sh add --amount 15 --category subscriptions --note "Netflix"
```

### Year-to-Date Summary

```bash
bash scripts/budget.sh summary --year 2026

# Output:
# 📊 Year-to-Date — 2026
# Total Income:   $7,000.00
# Total Expenses: $2,340.00
# Net Savings:    $4,660.00
# Savings Rate:   66.6%
```

### Budget Alerts

```bash
# Check if any category is over 80% spent
bash scripts/budget.sh alerts

# Output:
# ⚠️ entertainment: $92/$100 (92%) — nearly over budget!
# ✅ All other categories within budget
```

## Troubleshooting

### Issue: "command not found: jq"

```bash
sudo apt-get install jq    # Debian/Ubuntu
brew install jq             # macOS
```

### Issue: "command not found: bc"

```bash
sudo apt-get install bc     # Debian/Ubuntu
brew install bc             # macOS
```

### Issue: Data file corrupted

```bash
# Validate JSON
jq . ~/.budget-tracker/transactions.json

# Backup and reinit if needed
cp ~/.budget-tracker/transactions.json ~/.budget-tracker/transactions.json.bak
bash scripts/budget.sh init --force
```

## Key Principles

1. **Local-first** — All data in `~/.budget-tracker/`, no cloud dependency
2. **Fast** — Add a transaction in one command
3. **Portable** — JSON storage, CSV export, works anywhere bash runs
4. **Privacy** — Your financial data never leaves your machine
