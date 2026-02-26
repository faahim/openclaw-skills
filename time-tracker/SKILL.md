---
name: time-tracker
description: >-
  Track time spent on projects and tasks from the terminal. Start/stop timers, tag entries, generate reports and invoices.
categories: [productivity, finance]
dependencies: [bash, sqlite3, bc]
---

# Time Tracker

## What This Does

Track billable and personal time from the command line. Start/stop timers, tag entries by project/client, and generate daily/weekly/monthly reports with invoice-ready output. All data stored locally in SQLite — no cloud, no subscriptions.

**Example:** "Track 3 projects across 2 clients, generate a weekly invoice showing 42.5 hours billed at $85/hr = $3,612.50"

## Quick Start (2 minutes)

### 1. Install

```bash
# Run the install script (creates DB + adds alias)
bash scripts/install.sh
```

### 2. Start Tracking

```bash
# Start a timer
bash scripts/tt.sh start "Building auth flow" --project myapp --client "Acme Corp" --rate 85

# Check what's running
bash scripts/tt.sh status

# Stop the timer
bash scripts/tt.sh stop

# Output:
# ✅ Stopped: "Building auth flow" — 1h 23m (Acme Corp / myapp)
```

### 3. View Reports

```bash
# Today's summary
bash scripts/tt.sh report today

# This week
bash scripts/tt.sh report week

# Generate invoice
bash scripts/tt.sh invoice --client "Acme Corp" --from 2026-02-01 --to 2026-02-28
```

## Core Workflows

### Workflow 1: Simple Time Tracking

```bash
# Start
bash scripts/tt.sh start "Writing docs"

# Stop (logs duration automatically)
bash scripts/tt.sh stop

# Add a completed entry manually (e.g. forgot to track)
bash scripts/tt.sh add "Team meeting" --duration 45m --project standup
```

### Workflow 2: Multi-Project Tracking

```bash
# Track different projects
bash scripts/tt.sh start "API development" --project backend --tag feature
bash scripts/tt.sh stop

bash scripts/tt.sh start "Code review" --project backend --tag review
bash scripts/tt.sh stop

bash scripts/tt.sh start "Landing page" --project frontend --tag design
bash scripts/tt.sh stop

# Report by project
bash scripts/tt.sh report week --project backend
# Output:
# 📊 Week of Feb 24, 2026 — Project: backend
# ─────────────────────────────────────────
# Mon  API development      2h 15m  [feature]
# Mon  Code review           0h 45m  [review]
# Tue  API development      3h 30m  [feature]
# ─────────────────────────────────────────
# Total: 6h 30m
```

### Workflow 3: Billable Time & Invoicing

```bash
# Track with hourly rate
bash scripts/tt.sh start "Database migration" --client "Acme Corp" --rate 100

# Generate invoice
bash scripts/tt.sh invoice --client "Acme Corp" --from 2026-02-01 --to 2026-02-28

# Output:
# ┌─────────────────────────────────────────────────┐
# │  INVOICE — Acme Corp                            │
# │  Period: Feb 1 – Feb 28, 2026                   │
# ├─────────────────────────────────────────────────┤
# │  Database migration          12h 30m   $1,250.00│
# │  API development              8h 15m     $825.00│
# │  Code review                  3h 00m     $300.00│
# ├─────────────────────────────────────────────────┤
# │  TOTAL                       23h 45m   $2,375.00│
# └─────────────────────────────────────────────────┘
```

### Workflow 4: Daily Stand-Up Report

```bash
# What did I do yesterday?
bash scripts/tt.sh report yesterday

# Output:
# 📊 Yesterday — Feb 25, 2026
# ─────────────────────────────────
# API development      3h 30m  backend   [feature]
# Code review          1h 15m  backend   [review]
# Landing page         2h 00m  frontend  [design]
# Team meeting         0h 30m  standup
# ─────────────────────────────────
# Total: 7h 15m
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `tt.sh start "desc"` | Start a timer |
| `tt.sh stop` | Stop the running timer |
| `tt.sh status` | Show current running timer |
| `tt.sh add "desc" --duration 1h30m` | Add a completed entry |
| `tt.sh report today/yesterday/week/month` | Time reports |
| `tt.sh report --from DATE --to DATE` | Custom date range |
| `tt.sh invoice --client NAME` | Generate invoice |
| `tt.sh list` | List recent entries |
| `tt.sh delete ID` | Delete an entry |
| `tt.sh projects` | List all projects |
| `tt.sh clients` | List all clients |
| `tt.sh export csv` | Export to CSV |

### Options

| Option | Description |
|--------|-------------|
| `--project NAME` | Assign to project |
| `--client NAME` | Assign to client |
| `--tag TAG` | Add tag (repeatable) |
| `--rate N` | Hourly rate (for invoicing) |
| `--duration Xh Ym` | Duration (for `add`) |
| `--from DATE` | Start date (YYYY-MM-DD) |
| `--to DATE` | End date (YYYY-MM-DD) |

## Configuration

### Environment Variables

```bash
# Default hourly rate
export TT_DEFAULT_RATE=85

# Database location (default: ~/.timetracker/tt.db)
export TT_DB="$HOME/.timetracker/tt.db"

# Default currency symbol
export TT_CURRENCY="$"
```

## Advanced Usage

### Export for Accounting

```bash
# CSV export
bash scripts/tt.sh export csv --from 2026-02-01 --to 2026-02-28 > feb-hours.csv

# JSON export
bash scripts/tt.sh export json --client "Acme Corp" > acme-feb.json
```

### Run as OpenClaw Cron

```bash
# Weekly report every Friday at 5pm
# In your OpenClaw cron: run `bash scripts/tt.sh report week`
```

## Troubleshooting

### "sqlite3: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install sqlite3

# Mac
brew install sqlite3

# Alpine
apk add sqlite
```

### "No active timer"

You don't have a running timer. Start one with `tt.sh start "description"`.

### Timer running but forgot what it was

```bash
bash scripts/tt.sh status
# Shows: ⏱️ Running: "Building auth flow" — 2h 15m (started 10:30 AM)
```

## Dependencies

- `bash` (4.0+)
- `sqlite3` (database)
- `bc` (calculations)
- `date` (GNU coreutils)
