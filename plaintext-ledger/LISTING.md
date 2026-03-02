# Listing Copy: Plain-Text Ledger

## Metadata
- **Type:** Skill
- **Name:** plaintext-ledger
- **Display Name:** Plain-Text Ledger
- **Categories:** [finance, productivity]
- **Price:** $10
- **Icon:** 📒
- **Dependencies:** [bash, hledger]

## Tagline

Double-entry bookkeeping in plain text — track expenses, generate financial reports, own your data forever

## Description

Spreadsheets get messy. Banking apps don't give you control. SaaS tools lock your data behind subscriptions. You need something better.

Plain-Text Ledger sets up hledger — the gold standard in plain-text accounting. Your entire financial life lives in a single text file you can version with git, edit with any text editor, and keep forever. Double-entry bookkeeping means every dollar is accounted for, every report balances perfectly.

**What it does:**
- 📝 Add transactions via interactive prompt or one-liners
- 📊 Generate balance sheets, income statements, cash flow reports
- 🏷️ Auto-categorize bank imports with CSV rules
- 💰 Budget tracking — compare actual vs planned spending
- 📈 Monthly expense breakdowns with visual charts
- 🔄 Recurring transactions for subscriptions and bills
- 💱 Multi-currency support with exchange rates
- 🔍 Tag-based filtering (by client, project, category)
- 📥 Import bank CSV statements automatically
- 🌐 Optional web UI for browsing

Perfect for developers, freelancers, and anyone who wants full control of their finances without SaaS lock-in.

## Quick Start Preview

```bash
# Install hledger + set up journal
bash scripts/install.sh

# Add a transaction
bash scripts/quick-add.sh "Grocery shopping" 85.50 expenses:groceries

# See your balances
hledger balance
```

## Core Capabilities

1. Double-entry bookkeeping — Every transaction balances, audit-grade accuracy
2. Plain-text storage — Single .journal file, git-friendly, no vendor lock-in
3. Interactive entry — Guided prompts or quick one-liners for adding transactions
4. Financial reports — Balance sheet, income statement, cash flow, register
5. Expense breakdown — Visual category reports with percentage bars
6. CSV import — Auto-categorize bank statements with customizable rules
7. Budget tracking — Define monthly budgets, compare actual vs planned
8. Multi-currency — Track multiple currencies with exchange rates
9. Recurring entries — Subscriptions and bills auto-projected in forecasts
10. Web dashboard — Optional browser UI for visual exploration
11. Tag system — Filter by client, project, or custom metadata

## Installation Time
**5 minutes** — Run install script, start adding transactions
