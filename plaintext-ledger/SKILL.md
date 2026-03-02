---
name: plaintext-ledger
description: >-
  Plain-text double-entry bookkeeping with hledger — track expenses, generate financial reports, no cloud required.
categories: [finance, productivity]
dependencies: [bash, hledger]
---

# Plain-Text Ledger

## What This Does

Track your finances using plain-text double-entry bookkeeping powered by hledger. Add transactions in a simple text file, generate balance sheets, income statements, expense breakdowns, and cash flow reports. All your data stays in a single `.journal` file you own forever — no SaaS, no lock-in.

**Example:** "Track expenses across 5 accounts, see monthly spending breakdown by category, export reports as CSV."

## Quick Start (5 minutes)

### 1. Install hledger

```bash
bash scripts/install.sh
```

This installs hledger and sets up your journal at `~/finances/main.journal`.

### 2. Add Your First Transaction

```bash
bash scripts/add-transaction.sh
# Interactive prompt:
# Date [2026-03-02]:
# Description: Grocery shopping
# From account [expenses:food]: expenses:groceries
# To account [assets:bank:checking]:
# Amount: 85.50
```

Or edit the journal directly:

```bash
cat >> ~/finances/main.journal << 'EOF'

2026-03-02 Grocery shopping
    expenses:groceries          $85.50
    assets:bank:checking       $-85.50

2026-03-02 Monthly salary
    assets:bank:checking      $4500.00
    income:salary            $-4500.00

2026-03-01 Rent payment
    expenses:housing:rent     $1200.00
    assets:bank:checking     $-1200.00

2026-03-01 Electric bill
    expenses:utilities:electric   $95.00
    assets:bank:checking         $-95.00
EOF
```

### 3. See Your Balance

```bash
hledger -f ~/finances/main.journal balance
#                $3119.50  assets:bank:checking
#               $-4500.00  income:salary
#                  $85.50  expenses:groceries
#                $1200.00  expenses:housing:rent
#                  $95.00  expenses:utilities:electric
# --------------------
#                       0
```

## Core Workflows

### Workflow 1: Monthly Expense Breakdown

```bash
# See expenses grouped by category this month
hledger -f ~/finances/main.journal balance expenses --monthly --tree

# Pie chart of spending categories
bash scripts/expense-report.sh --month 2026-03

# Output:
# 📊 March 2026 Expense Report
# ─────────────────────────────
# Housing          $1,200.00  (86.8%)  ████████████████████
# Utilities           $95.00   (6.9%)  ██
# Groceries           $85.50   (6.2%)  █
# ─────────────────────────────
# Total            $1,380.50
```

### Workflow 2: Income Statement

```bash
# Profit & loss for a period
hledger -f ~/finances/main.journal incomestatement --monthly -b 2026-01 -e 2026-04

# Output:
# Income Statement 2026-01-01..2026-03-31
#
# Revenues:
#   income:salary         $13,500.00
#   income:freelance       $2,000.00
# Total                   $15,500.00
#
# Expenses:
#   expenses:housing       $3,600.00
#   expenses:groceries       $780.00
#   expenses:utilities       $285.00
#   expenses:transport       $150.00
# Total                    $4,815.00
#
# Net:                    $10,685.00
```

### Workflow 3: Track Multiple Accounts

```bash
# Balance sheet — see all assets and liabilities
hledger -f ~/finances/main.journal balancesheet

# Output:
# Balance Sheet 2026-03-02
#
# Assets:
#   assets:bank:checking    $3,119.50
#   assets:bank:savings    $10,000.00
#   assets:cash               $120.00
# Total                    $13,239.50
#
# Liabilities:
#   liabilities:credit-card   $450.00
# Total                       $450.00
#
# Net Worth:               $12,789.50
```

### Workflow 4: Budget Tracking

```bash
# Define monthly budget
cat > ~/finances/budget.journal << 'EOF'
~ monthly
    expenses:groceries       $400
    expenses:housing:rent   $1200
    expenses:utilities       $150
    expenses:transport       $100
    expenses:entertainment   $200
    assets:budget allocation
EOF

# Compare actual vs budget
hledger -f ~/finances/main.journal -f ~/finances/budget.journal balance --budget expenses --monthly
```

### Workflow 5: Quick Transaction Entry

```bash
# One-liner transaction
bash scripts/quick-add.sh "Coffee at Blue Bottle" 5.50 expenses:food:coffee

# Recurring transactions (auto-add monthly)
bash scripts/add-recurring.sh "Netflix" 15.99 expenses:subscriptions monthly

# Import from CSV (bank export)
bash scripts/import-csv.sh ~/Downloads/bank-statement.csv
```

### Workflow 6: Cash Flow Analysis

```bash
hledger -f ~/finances/main.journal cashflow --monthly -b 2026-01

# Output:
# Cashflow Statement 2026-01-01..2026-03-31
#
# Cash flows:
#   assets:bank:checking   +$8,200.00
#   assets:bank:savings    +$2,000.00
#   assets:cash              +$485.50
# Total                   +$10,685.50
```

## Configuration

### Journal File Format

```
; ~/finances/main.journal
; This is a plain text file using hledger journal format

; Account declarations (optional but recommended)
account assets:bank:checking
account assets:bank:savings
account assets:cash
account expenses:groceries
account expenses:housing:rent
account expenses:utilities:electric
account expenses:utilities:water
account expenses:transport
account expenses:food:restaurant
account expenses:food:coffee
account expenses:subscriptions
account income:salary
account income:freelance
account liabilities:credit-card

; Commodity declaration
commodity $1,000.00

; Transactions
2026-01-01 Opening balances
    assets:bank:checking     $5,000.00
    assets:bank:savings     $10,000.00
    equity:opening

2026-01-15 Monthly salary
    assets:bank:checking     $4,500.00
    income:salary

2026-01-15 Rent
    expenses:housing:rent    $1,200.00
    assets:bank:checking
```

### Environment Variables

```bash
# Set default journal file (avoids -f flag every time)
export LEDGER_FILE=~/finances/main.journal

# Now just run:
hledger balance
hledger incomestatement
```

### Multi-Currency Support

```
2026-03-01 Currency exchange
    assets:bank:checking    $-1000.00
    assets:bank:eur          €920.00 @@ $1000.00

2026-03-02 Dinner in Berlin
    expenses:food:restaurant  €45.00
    assets:bank:eur
```

## Advanced Usage

### Tags for Categorization

```
2026-03-02 Business lunch  ; client:acme, project:widget
    expenses:food:restaurant   $65.00
    assets:bank:checking

; Query by tag
; hledger -f main.journal register tag:client=acme
```

### Auto-Import Bank Statements

```bash
# Set up CSV import rules
cat > ~/finances/bank-rules.csv << 'EOF'
# skip 1 header line
skip 1

# column order in your bank CSV
fields date, description, amount

# date format
date-format %m/%d/%Y

# auto-categorize by description
if WALMART|TARGET
    account1 expenses:groceries

if NETFLIX|SPOTIFY|HULU
    account1 expenses:subscriptions

if SHELL|EXXON|BP
    account1 expenses:transport:gas

# default
account1 expenses:unknown
account2 assets:bank:checking
EOF

# Import
hledger import ~/Downloads/statement.csv --rules-file ~/finances/bank-rules.csv
```

### Web UI (Optional)

```bash
# Start local web dashboard
hledger-web -f ~/finances/main.journal --port 5000

# Open http://localhost:5000 for a browsable UI
```

### Forecasting

```bash
# Project expenses forward
hledger -f ~/finances/main.journal -f ~/finances/budget.journal balance --forecast -e 2026-12 expenses
```

## Troubleshooting

### Issue: "hledger: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: sudo apt install hledger
# Mac: brew install hledger
# Any: curl -sO https://hledger.org/install.sh && bash install.sh
```

### Issue: "could not balance this transaction"

**Fix:** Every transaction must balance to zero. Check amounts:
```
2026-03-02 Example
    expenses:food     $50.00
    assets:checking  $-50.00   ; Must equal the negative of above
```
Or let hledger infer the second amount:
```
2026-03-02 Example
    expenses:food     $50.00
    assets:checking              ; hledger calculates: $-50.00
```

### Issue: Wrong date format

**Fix:** Use YYYY-MM-DD format (ISO 8601):
```
2026-03-02  ✅ correct
03/02/2026  ❌ wrong (use date-format in CSV rules)
```

## Dependencies

- `hledger` (plain-text accounting tool)
- `bash` (4.0+)
- `column` (for formatted output, usually pre-installed)
- Optional: `hledger-web` (web UI dashboard)
- Optional: `hledger-ui` (terminal UI)
