# Listing Copy: Budget Tracker

## Metadata
- **Type:** Skill
- **Name:** budget-tracker
- **Display Name:** Budget Tracker
- **Categories:** [finance, productivity]
- **Price:** $10
- **Dependencies:** [bash, jq, bc]

## Tagline
Track expenses and income from the CLI — budgets, reports, and CSV export

## Description

Manually tracking expenses in spreadsheets is tedious and easy to forget. You need something fast — one command to log a purchase, one command to see where your money goes.

Budget Tracker lets your OpenClaw agent manage your finances from the command line. Add transactions with categories, set monthly budget limits, get spending reports with category breakdowns, and export everything to CSV. All data stored locally in JSON — no cloud services, no monthly fees, complete privacy.

**What it does:**
- 💰 Add expenses and income with categories and notes
- 📊 Set monthly budgets per category with overspend alerts
- 📋 Generate monthly reports with top categories and daily averages
- 📁 Export transactions to CSV for spreadsheets
- 🔍 Search and filter by category, date range, or keyword
- 📈 Year-to-date summaries with savings rate

Perfect for developers, freelancers, and anyone who wants fast expense tracking without opening an app.

## Quick Start Preview

```bash
bash scripts/budget.sh init
bash scripts/budget.sh add --amount 45.50 --category groceries --note "Weekly shopping"
bash scripts/budget.sh report
```

## Core Capabilities

1. Transaction logging — Add expenses/income with one command
2. Category management — Custom categories, auto-detection
3. Monthly budgets — Set limits per category, get alerts at 80%+
4. Spending reports — Category breakdowns, daily averages, projections
5. CSV export — Full or filtered export for spreadsheets
6. Search & filter — By category, date range, keyword, or last N
7. Year-to-date summary — Total income/expenses/savings rate
8. Budget alerts — Warns when approaching or exceeding limits
9. Local storage — JSON files, no cloud dependency
10. Cron-ready — Add recurring transactions via crontab
