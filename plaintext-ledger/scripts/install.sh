#!/bin/bash
# Install hledger and set up plain-text ledger
set -euo pipefail

FINANCE_DIR="${LEDGER_DIR:-$HOME/finances}"

echo "📦 Installing Plain-Text Ledger..."

# Install hledger
if command -v hledger &>/dev/null; then
    echo "  ✅ hledger already installed ($(hledger --version | head -1))"
else
    echo "  📥 Installing hledger..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq hledger 2>/dev/null || {
            echo "  📥 apt install failed, trying binary install..."
            curl -sO https://hledger.org/install.sh && bash install.sh
        }
    elif command -v brew &>/dev/null; then
        brew install hledger
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm hledger
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y hledger
    else
        echo "  📥 Using hledger's official installer..."
        curl -sO https://hledger.org/install.sh && bash install.sh
    fi

    if command -v hledger &>/dev/null; then
        echo "  ✅ hledger installed ($(hledger --version | head -1))"
    else
        echo "  ❌ Failed to install hledger. Visit https://hledger.org/install.html" >&2
        exit 1
    fi
fi

# Create finance directory
mkdir -p "$FINANCE_DIR"

# Create starter journal if it doesn't exist
if [[ ! -f "$FINANCE_DIR/main.journal" ]]; then
    cat > "$FINANCE_DIR/main.journal" << 'EOF'
; Plain-Text Ledger — Main Journal
; Edit this file to add transactions
; Format: https://hledger.org/1.32/hledger.html#journal-format

; === Account Declarations ===
account assets:bank:checking     ; Main bank account
account assets:bank:savings      ; Savings account
account assets:cash              ; Cash on hand
account expenses:groceries       ; Food & groceries
account expenses:housing:rent    ; Rent/mortgage
account expenses:utilities       ; Electric, water, internet
account expenses:transport       ; Gas, public transit, rideshare
account expenses:food:restaurant ; Eating out
account expenses:food:coffee     ; Coffee shops
account expenses:subscriptions   ; Netflix, Spotify, etc.
account expenses:entertainment   ; Fun stuff
account expenses:health          ; Medical, pharmacy, gym
account expenses:clothing        ; Clothes & accessories
account expenses:education       ; Books, courses, learning
account expenses:personal        ; Other personal expenses
account income:salary            ; Primary income
account income:freelance         ; Side income
account liabilities:credit-card  ; Credit card balance
account equity:opening           ; Opening balances

; === Commodity ===
commodity $1,000.00

; === Opening Balances ===
; Uncomment and edit with your actual starting balances:
; 2026-01-01 Opening balances
;     assets:bank:checking     $0.00
;     assets:bank:savings      $0.00
;     equity:opening

; === Transactions ===
; Add your transactions below. Format:
;
; YYYY-MM-DD Description
;     account:name     $amount
;     account:name     $-amount  (or leave blank to auto-balance)
;
; Example:
; 2026-03-02 Weekly groceries
;     expenses:groceries     $85.50
;     assets:bank:checking

EOF
    echo "  ✅ Created $FINANCE_DIR/main.journal"
else
    echo "  ℹ️  Journal already exists at $FINANCE_DIR/main.journal"
fi

# Create CSV import rules template
if [[ ! -f "$FINANCE_DIR/import-rules.csv" ]]; then
    cat > "$FINANCE_DIR/import-rules.csv" << 'EOF'
# CSV Import Rules for bank statements
# Customize the fields and categorization rules for your bank

# Skip header row
skip 1

# Column mapping (adjust to match your bank's CSV format)
# Common formats:
#   Chase: fields date, description, amount
#   BofA:  fields date, _, description, amount
#   Wells:  fields date, amount, _, _, description
fields date, description, amount

# Date format in your bank CSV
date-format %m/%d/%Y

# === Auto-categorization Rules ===
# Groceries
if WALMART|TARGET|COSTCO|KROGER|SAFEWAY|TRADER JOE|WHOLE FOODS|ALDI
    account1 expenses:groceries

# Restaurants
if DOORDASH|UBER EATS|GRUBHUB|MCDONALD|STARBUCKS|CHIPOTLE
    account1 expenses:food:restaurant

# Subscriptions
if NETFLIX|SPOTIFY|HULU|DISNEY|AMAZON PRIME|APPLE.COM
    account1 expenses:subscriptions

# Transport
if SHELL|EXXON|BP|UBER|LYFT|TRANSIT
    account1 expenses:transport

# Utilities
if ELECTRIC|WATER|INTERNET|COMCAST|VERIZON|T-MOBILE
    account1 expenses:utilities

# Housing
if RENT|MORTGAGE|HOA
    account1 expenses:housing:rent

# Income
if PAYROLL|DIRECT DEPOSIT|SALARY
    account1 income:salary

# Default (uncategorized)
account1 expenses:unknown
account2 assets:bank:checking
EOF
    echo "  ✅ Created $FINANCE_DIR/import-rules.csv"
fi

# Set environment variable hint
echo ""
echo "🎉 Plain-Text Ledger installed!"
echo ""
echo "Add to your shell profile for convenience:"
echo "  echo 'export LEDGER_FILE=$FINANCE_DIR/main.journal' >> ~/.bashrc"
echo ""
echo "Quick commands:"
echo "  hledger -f $FINANCE_DIR/main.journal balance           # Account balances"
echo "  hledger -f $FINANCE_DIR/main.journal incomestatement   # Profit & loss"
echo "  hledger -f $FINANCE_DIR/main.journal balancesheet      # Assets & liabilities"
echo "  hledger -f $FINANCE_DIR/main.journal register          # Transaction log"
echo ""
echo "Edit your journal:  nano $FINANCE_DIR/main.journal"
echo ""
