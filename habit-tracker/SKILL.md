---
name: habit-tracker
description: >-
  Track daily habits with streaks, heatmaps, and completion reports using SQLite storage.
categories: [productivity, automation]
dependencies: [bash, sqlite3, bc]
---

# Habit Tracker

## What This Does

A persistent habit tracking CLI that stores completions in SQLite, calculates streaks, generates GitHub-style heatmaps, and produces weekly reports. Unlike simple text-based tracking, this maintains proper state across sessions with date-aware streak logic and historical analytics.

**Example:** "Track 5 daily habits, see current streaks, get a weekly completion report with progress bars."

## Quick Start (2 minutes)

### 1. Install

```bash
# Check dependencies (sqlite3 is the only non-standard one)
which sqlite3 bc || sudo apt-get install -y sqlite3 bc

# Install the script
sudo cp scripts/habit.sh /usr/local/bin/habit
sudo chmod +x /usr/local/bin/habit

# Or just use directly
bash scripts/habit.sh help
```

### 2. Add Your First Habits

```bash
habit add exercise "Morning workout" daily
habit add meditation "10 min mindfulness" daily
habit add reading "Read 30 pages" daily
habit add journal "Write daily journal" daily
```

### 3. Log Completions

```bash
# Mark today's habits as done
habit done exercise
habit done meditation
habit done reading "Finished chapter 5"

# Log a past day
habit done exercise 2026-02-25
```

### 4. Check Progress

```bash
# Today's status
habit list

# Output:
# 📋 Habits — 2026-02-28
#
#   HABIT                FREQ       TODAY    STREAK
#   ────────────────────────────────────────────────
#   exercise             daily        ✅    🔥 12
#   journal              daily        ⬜    0
#   meditation           daily        ✅    🔥 5
#   reading              daily        ✅    🔥 8
```

## Core Workflows

### Workflow 1: Daily Check-in

**Use case:** Agent runs this during daily check-in to see what's done

```bash
# Show today's status
habit list

# Mark habits as done
habit done exercise
habit done meditation "Guided session"
habit done reading
```

### Workflow 2: Weekly Report

**Use case:** Generate a progress summary every Sunday

```bash
habit report 7

# Output:
# 📈 Weekly Report (last 7 days)
#
#   Overall completion rate: 78.6% (22/28)
#
#   exercise
#   ████████████████████ 100% (7/7) 🔥12
#
#   meditation
#   ██████████████░░░░░░ 71% (5/7) 🔥5
#
#   reading
#   ████████████████░░░░ 85% (6/7) 🔥8
#
#   journal
#   ██████████░░░░░░░░░░ 57% (4/7) 🔥0
```

### Workflow 3: Streak Analysis

**Use case:** Deep-dive into a specific habit's history

```bash
habit stats exercise 90

# Output:
# 📊 Stats: exercise
#   Created:          2026-01-01 00:00:00
#   Current streak:   🔥 12 days
#   Best streak:      ⭐ 21 days
#   Total completions: 67
#   Last 90d rate:    74.4%
#
#   Last 7 days:
#   █ █ █ █ █ █ █
#   S F T W T M S
```

### Workflow 4: Heatmap View

**Use case:** Visual overview of consistency

```bash
habit heatmap exercise 12

# Output:
# 🗓️  Heatmap: exercise (12 weeks)
#
#   M █ █ ░ █ █ █ █ █ ░ █ █ █
#   T █ ░ █ █ █ █ █ ░ █ █ █ █
#   W █ █ █ █ ░ █ █ █ █ █ █ █
#   T ░ █ █ █ █ █ ░ █ █ █ █ █
#   F █ █ █ ░ █ █ █ █ █ ░ █ █
#   S █ █ ░ █ █ █ █ █ ░ █ █ █
#   S ░ ░ █ █ ░ █ ░ █ █ ░ █ █
```

### Workflow 5: Data Export

**Use case:** Back up or analyze data externally

```bash
# CSV export
habit export csv > habits-backup.csv

# JSON export  
habit export json > habits-backup.json
```

## Configuration

### Storage Location

```bash
# Default: ~/.habit-tracker/habits.db
# Override with environment variable:
export HABIT_TRACKER_DIR="/path/to/custom/dir"
```

### OpenClaw Cron Integration

```bash
# Daily reminder at 9pm to log habits
# In OpenClaw cron, add a systemEvent:
# "Check habit completion for today: run `habit list` and remind about incomplete habits"

# Weekly report every Sunday
# "Generate habit report: run `habit report 7` and share the results"
```

## Command Reference

| Command | Description |
|---------|-------------|
| `habit add <name> [desc] [freq]` | Add a new habit |
| `habit done <name> [date] [note]` | Mark as completed |
| `habit undo <name> [date]` | Remove a completion |
| `habit list` | Show today's status |
| `habit stats [name] [days]` | Show statistics |
| `habit heatmap <name> [weeks]` | GitHub-style heatmap |
| `habit report [days]` | Completion report |
| `habit export [csv\|json]` | Export data |
| `habit remove <name>` | Archive a habit |

## Troubleshooting

### Issue: "sqlite3: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install -y sqlite3

# Mac (usually pre-installed)
brew install sqlite3

# Alpine
apk add sqlite
```

### Issue: "bc: command not found"

```bash
sudo apt-get install -y bc
```

### Issue: Date parsing errors on macOS

The script handles both GNU date (`date -d`) and BSD date (`date -v`). If you see errors, ensure you're using bash 4+:

```bash
bash --version
# If < 4.0, install modern bash:
brew install bash
```

## Key Principles

1. **Persistent** — SQLite storage survives across sessions
2. **Streak-aware** — Proper consecutive-day streak calculation
3. **Visual** — Heatmaps and progress bars for quick assessment
4. **Exportable** — CSV/JSON export for external analysis
5. **Fast** — All queries optimized with indexes
