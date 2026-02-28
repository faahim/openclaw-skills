# Listing Copy: Habit Tracker

## Metadata
- **Type:** Skill
- **Name:** habit-tracker
- **Display Name:** Habit Tracker
- **Categories:** [productivity, automation]
- **Price:** $8
- **Dependencies:** [bash, sqlite3, bc]

## Tagline

Track daily habits with streaks, heatmaps, and completion reports

## Description

Sticking to habits is hard enough without losing track of your progress. Spreadsheets get messy, apps require accounts, and plain text files don't calculate streaks.

Habit Tracker is a lightweight CLI that stores completions in SQLite, calculates consecutive-day streaks with proper date math, and generates GitHub-style heatmaps and weekly reports — all from your terminal. No accounts, no cloud, no subscriptions.

**What it does:**
- ✅ Add unlimited habits with daily/weekly frequency
- 🔥 Automatic streak calculation (current + best ever)
- 🗓️ GitHub-style heatmap visualization
- 📈 Weekly completion reports with progress bars
- 📊 Per-habit statistics with completion rates
- 📤 Export to CSV or JSON for external analysis
- 🗄️ SQLite storage — persistent, fast, queryable
- ⏱️ 2-minute setup — single bash script, no build step

Perfect for developers and power users who want habit tracking without leaving the terminal.

## Quick Start Preview

```bash
habit add exercise "Morning workout" daily
habit done exercise
habit list
# 📋 Habits — 2026-02-28
#   exercise    daily    ✅    🔥 12
#   meditation  daily    ⬜    0

habit report 7
# 📈 Overall completion rate: 78.6% (22/28)
```

## Core Capabilities

1. Habit management — Add, archive, and list habits with descriptions
2. Daily logging — Mark completions with optional notes and dates
3. Streak tracking — Consecutive-day streaks with proper calendar math
4. Best streak — All-time longest streak per habit
5. Heatmap — 12-week GitHub-style visual consistency map
6. Weekly reports — Progress bars and completion percentages
7. Statistics — Per-habit and overview stats for any time range
8. Data export — CSV and JSON export for backups or analysis
9. Cron-ready — Integrates with OpenClaw cron for reminders
10. Zero config — Works out of the box with sensible defaults

## Dependencies
- `bash` (4.0+)
- `sqlite3`
- `bc`

## Installation Time
**2 minutes** — Copy script, install sqlite3 if missing
