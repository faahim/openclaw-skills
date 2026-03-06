# Listing Copy: Expense Splitter

## Metadata
- **Type:** Skill
- **Name:** expense-splitter
- **Display Name:** Expense Splitter
- **Categories:** [finance, productivity]
- **Icon:** 💸
- **Dependencies:** [sqlite3, python3, bc]

## Tagline

Split shared expenses and calculate who owes whom — like Splitwise but local

## Description

Splitting bills with friends shouldn't require a cloud account and a monthly subscription. Whether it's rent with roommates, a road trip with friends, or dinner with colleagues, Expense Splitter tracks who paid what, calculates fair shares, and tells you exactly who owes whom with the minimum number of payments.

Expense Splitter stores everything locally in SQLite — no cloud sync, no accounts, no data leaving your machine. Your OpenClaw agent manages groups, adds expenses, and calculates optimal settlements with a single command.

**What it does:**
- 👥 Create unlimited groups (roommates, trips, dinners, projects)
- 💰 Track expenses with equal, exact, or percentage splits
- 🔄 Calculate optimal settlements (minimum payments to clear all debts)
- ✅ Record payments and track remaining balances
- 📊 View summaries, history, and export to CSV
- 🗄️ All data stored locally in SQLite — private and portable

Perfect for anyone who splits bills regularly and wants a simple, private, no-nonsense solution that lives right in their terminal.

## Quick Start Preview

```bash
# Create a group
expense-splitter create-group roadtrip Alice Bob Charlie

# Add expenses
expense-splitter add roadtrip Alice 90 "Gas"
expense-splitter add roadtrip Bob 60 "Food"

# See who owes whom
expense-splitter settle roadtrip
# 💸 Charlie → Alice: $30.00
# 💸 Bob → Alice: $15.00
```

## Core Capabilities

1. Group management — Create and manage multiple expense groups
2. Equal splits — Divide costs evenly among all members
3. Custom splits — Split by exact amounts or percentages
4. Balance tracking — See net balances for each member
5. Optimal settlements — Minimize the number of payments needed
6. Settlement recording — Track who has paid their share
7. Expense history — View chronological expense log
8. CSV export — Export data for spreadsheets or records
9. Group summaries — See total spend, top spenders, stats
10. Local storage — SQLite database, no cloud dependency
