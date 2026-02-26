# Listing Copy: Time Tracker

## Metadata
- **Type:** Skill
- **Name:** time-tracker
- **Display Name:** Time Tracker
- **Categories:** [productivity, finance]
- **Price:** $10
- **Dependencies:** [bash, sqlite3, bc]

## Tagline

Track project time from the terminal — Generate invoices and reports instantly

## Description

Manually tracking billable hours in spreadsheets is error-prone and tedious. By the time you compile a weekly report or invoice, you've already forgotten half of what you worked on.

Time Tracker lets you start/stop timers from the command line, tag entries by project and client, and generate instant reports and invoices. All data stored locally in SQLite — no cloud services, no subscriptions, no monthly fees.

**What it does:**
- ⏱️ Start/stop timers with one command
- 📁 Organize by project, client, and tags
- 📊 Daily, weekly, monthly reports
- 💰 Invoice generation with hourly rates
- 📤 Export to CSV or JSON for accounting
- 🔒 All data stays on your machine

Perfect for freelancers, contractors, and developers who need simple, reliable time tracking without the overhead of Toggl, Harvest, or Clockify.

## Quick Start Preview

```bash
bash scripts/tt.sh start "Building API" --project backend --client "Acme Corp" --rate 85
# ⏱️  Started: "Building API" — Project: backend — Rate: $85/hr

bash scripts/tt.sh stop
# ✅ Stopped: "Building API" — 2h 15m

bash scripts/tt.sh invoice --client "Acme Corp"
# Generates formatted invoice with hours × rate
```

## Core Capabilities

1. Start/stop timers — One command to begin, one to end
2. Project organization — Group entries by project and client
3. Tag system — Add tags for filtering (feature, review, meeting)
4. Billable rates — Set hourly rates per entry or globally
5. Daily reports — See today's or yesterday's work at a glance
6. Weekly/monthly summaries — Aggregate time by period
7. Invoice generation — Formatted invoices with hours × rate calculations
8. CSV/JSON export — Feed data into accounting tools
9. Manual entries — Add forgotten time after the fact
10. SQLite storage — Fast, reliable, local-only persistence

## Dependencies
- `bash` (4.0+)
- `sqlite3`
- `bc`

## Installation Time
**2 minutes** — Run install script, start tracking
