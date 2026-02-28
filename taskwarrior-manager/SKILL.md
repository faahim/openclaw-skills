---
name: taskwarrior-manager
description: >-
  Install and manage Taskwarrior for powerful CLI task management — create tasks, manage projects, set priorities, generate reports, and sync across devices.
categories: [productivity, automation]
dependencies: [bash, curl, taskwarrior]
---

# Taskwarrior Manager

## What This Does

Installs and manages [Taskwarrior](https://taskwarrior.org/) — the most powerful CLI task manager. Create tasks with priorities, due dates, tags, and projects. Generate productivity reports. Sync across devices with Taskserver.

**Example:** "Add 15 tasks across 3 projects, see what's overdue, get a weekly burndown, sync to your laptop."

## Quick Start (5 minutes)

### 1. Install Taskwarrior

```bash
bash scripts/install.sh
```

This detects your OS and installs Taskwarrior + dependencies.

### 2. Add Your First Task

```bash
bash scripts/run.sh add "Review pull request" project:work priority:H due:tomorrow
```

### 3. See Your Tasks

```bash
bash scripts/run.sh list
```

## Core Workflows

### Workflow 1: Add Tasks

```bash
# Simple task
bash scripts/run.sh add "Buy groceries"

# Task with metadata
bash scripts/run.sh add "Deploy v2.0" project:webapp priority:H due:2026-03-01 +deploy +critical

# Recurring task
bash scripts/run.sh add "Weekly standup notes" project:work due:monday recur:weekly
```

### Workflow 2: Manage Tasks

```bash
# List all pending tasks
bash scripts/run.sh list

# Filter by project
bash scripts/run.sh list project:work

# Filter by tag
bash scripts/run.sh list +critical

# Filter by due date
bash scripts/run.sh list due.before:tomorrow

# Complete a task
bash scripts/run.sh done <task-id>

# Modify a task
bash scripts/run.sh modify <task-id> priority:M due:friday

# Delete a task
bash scripts/run.sh delete <task-id>
```

### Workflow 3: Projects & Tags

```bash
# List all projects
bash scripts/run.sh projects

# List all tags
bash scripts/run.sh tags

# See project summary
bash scripts/run.sh project-summary

# Bulk-add tasks to a project
bash scripts/run.sh bulk-add work "Design mockups" "Write API docs" "Setup CI/CD" "Code review"
```

### Workflow 4: Reports & Analytics

```bash
# Burndown chart (daily)
bash scripts/run.sh burndown

# Weekly burndown
bash scripts/run.sh burndown weekly

# Productivity summary
bash scripts/run.sh summary

# Overdue tasks
bash scripts/run.sh overdue

# Completed today
bash scripts/run.sh completed-today

# Export as JSON
bash scripts/run.sh export-json
```

### Workflow 5: Priorities & Urgency

```bash
# List by urgency (Taskwarrior's smart sorting)
bash scripts/run.sh next

# High priority only
bash scripts/run.sh list priority:H

# Set urgency coefficients
bash scripts/run.sh config urgency.priority.coefficient 6.0
```

### Workflow 6: Sync Across Devices

```bash
# Setup Taskserver (self-hosted sync)
bash scripts/setup-sync.sh --server your-server.com --port 53589

# Manual sync
bash scripts/run.sh sync

# Check sync status
bash scripts/run.sh sync-status
```

### Workflow 7: Daily Review

```bash
# Morning review: what's due today + overdue + high priority
bash scripts/run.sh daily-review

# Output:
# 📋 Daily Review — 2026-02-28
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🔴 OVERDUE (2):
#   1. Deploy hotfix [webapp] H — due 2026-02-27
#   2. Reply to client email [work] M — due 2026-02-26
#
# 📅 DUE TODAY (3):
#   3. Code review PR #42 [webapp] H
#   4. Team standup notes [work] M
#   5. Order supplies [home] L
#
# ⚡ HIGH PRIORITY (1):
#   6. Finalize Q1 roadmap [work] H — due 2026-03-01
#
# 📊 Stats: 23 pending | 5 due this week | 142 completed total
```

## Configuration

### Taskwarrior Config (~/.taskrc)

The install script sets up sensible defaults. Customize:

```bash
# Change default priority
bash scripts/run.sh config default.priority M

# Set date format
bash scripts/run.sh config dateformat Y-M-D

# Color theme
bash scripts/run.sh config color.overdue red
bash scripts/run.sh config color.due.today yellow

# Urgency tuning
bash scripts/run.sh config urgency.due.coefficient 12.0
bash scripts/run.sh config urgency.blocking.coefficient 8.0
```

### Environment Variables

```bash
# Custom data location (default: ~/.task)
export TASKDATA="$HOME/.task"

# Custom config location (default: ~/.taskrc)
export TASKRC="$HOME/.taskrc"
```

## Advanced Usage

### Custom Reports

```bash
# Create a "standup" report
bash scripts/run.sh config report.standup.description "Tasks for standup"
bash scripts/run.sh config report.standup.columns "id,project,description,status"
bash scripts/run.sh config report.standup.filter "status:pending modified.after:yesterday"

# Run it
task standup
```

### Hooks (Automation)

```bash
# Install the on-complete hook (logs completions)
bash scripts/install-hooks.sh

# Hooks fire on: add, modify, complete, delete
# Custom hooks go in: ~/.task/hooks/
```

### Bulk Import from CSV/JSON

```bash
# Import tasks from JSON
bash scripts/run.sh import tasks.json

# Import from CSV
bash scripts/run.sh import-csv tasks.csv --project myproject
```

### Cron Integration

```bash
# Daily review at 9am
bash scripts/run.sh setup-cron --daily-review 9

# Overdue alerts every 4 hours
bash scripts/run.sh setup-cron --overdue-alert 4
```

## Troubleshooting

### Issue: "command not found: task"

**Fix:**
```bash
# Re-run install
bash scripts/install.sh

# Or install manually:
# Ubuntu/Debian
sudo apt-get install taskwarrior

# Mac
brew install task

# Arch
sudo pacman -S task
```

### Issue: Sync fails with certificate error

**Fix:**
```bash
# Regenerate certificates
bash scripts/setup-sync.sh --regenerate-certs

# Check server connectivity
bash scripts/run.sh sync-status
```

### Issue: Recurring tasks duplicating

**Fix:**
```bash
# Check recurrence config
task config recurrence.limit 1

# Purge duplicate recurrences
task rc.recurrence.limit=0 recurring
```

## Dependencies

- `bash` (4.0+)
- `taskwarrior` (2.6+ / 3.0+) — installed by `scripts/install.sh`
- `jq` (for JSON export/import)
- Optional: `taskserver` (for multi-device sync)
- Optional: `python3` (for advanced reporting)
