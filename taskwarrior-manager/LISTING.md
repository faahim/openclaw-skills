# Listing Copy: Taskwarrior Manager

## Metadata
- **Type:** Skill
- **Name:** taskwarrior-manager
- **Display Name:** Taskwarrior Manager
- **Categories:** [productivity, automation]
- **Price:** $10
- **Dependencies:** [bash, taskwarrior, jq]
- **Icon:** ✅

## Tagline

Powerful CLI task management — projects, priorities, reports, and cross-device sync

## Description

Tired of switching between bloated task apps that break your flow? Taskwarrior is the gold standard of CLI task management — used by developers and power users who live in the terminal. But setting it up right takes time.

**Taskwarrior Manager** gets you productive in 5 minutes. Auto-installs on any Linux or macOS, configures sensible defaults, and wraps Taskwarrior's 50+ commands into simple workflows: daily reviews, burndown charts, bulk task import, project summaries, and cross-device sync.

**What you get:**
- ✅ One-command install on Ubuntu, Fedora, Arch, macOS, Alpine
- 📋 Daily review command (overdue + today + high priority at a glance)
- 📊 Burndown charts and productivity reports
- 📁 Project & tag management with bulk operations
- 🔄 Cross-device sync via Taskserver (self-hosted)
- ⏰ Cron integration for automated reviews and overdue alerts
- 📥 Import from CSV/JSON, export anytime
- 🪝 Git-style hooks for automation (log completions, validate tasks)

Perfect for developers, sysadmins, and anyone who prefers the terminal over clicking through GUIs.

## Core Capabilities

1. Auto-install — Detects OS, installs Taskwarrior + dependencies
2. Daily review — One command shows overdue, due today, and high priority
3. Project management — Bulk-add tasks, track progress per project
4. Priority system — H/M/L with smart urgency scoring
5. Burndown charts — Daily/weekly/monthly progress visualization
6. Recurring tasks — Standup notes, reviews, recurring chores
7. CSV/JSON import — Migrate from any tool
8. Cross-device sync — Self-hosted Taskserver with cert-based auth
9. Cron scheduling — Automated daily reviews and overdue alerts
10. Git-style hooks — Trigger actions on add/complete/modify

## Dependencies
- `bash` (4.0+)
- `taskwarrior` (installed by skill)
- `jq` (installed by skill)
- Optional: `openssl` (for sync certs)

## Installation Time
**5 minutes** — Run install script, start adding tasks
