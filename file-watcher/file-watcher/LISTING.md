# Listing Copy: File Watcher

## Metadata
- **Type:** Skill
- **Name:** file-watcher
- **Display Name:** File Watcher
- **Categories:** [automation, productivity]
- **Price:** $8
- **Dependencies:** [inotify-tools, bash]

## Tagline

Watch files for changes — auto-trigger scripts, syncs, and alerts instantly

## Description

Manually checking if files changed is a waste of time. Whether it's processing uploads, reloading configs, backing up documents, or alerting on log errors — you need it to happen automatically, the instant a file changes.

File Watcher uses Linux's inotify subsystem to monitor directories in real-time with zero polling and zero CPU waste. When files are created, modified, moved, or deleted, it triggers your custom actions — run scripts, send Telegram alerts, sync folders, or kick off builds.

**What it does:**
- 👁️ Watch any directory for file changes in real-time
- ⚡ Trigger custom scripts/commands on create, modify, delete, or move events
- 🔔 Send Telegram notifications on file changes
- 🔁 Auto-sync directories with rsync on changes
- 📁 Filter by file extension (*.js, *.log, *.pdf)
- 🚫 Exclude patterns (node_modules, .git, .tmp)
- ⏱️ Debounce rapid changes to avoid duplicate triggers
- 🔄 Run as background daemon or systemd service
- 📝 YAML config for managing multiple watchers

Perfect for developers automating build triggers, sysadmins monitoring config changes, and anyone who needs file-based automation without polling.

## Quick Start Preview

```bash
# Watch a folder, run a script when files change
bash scripts/watch.sh --dir /var/uploads --on-change "process.sh" --recursive

# [2026-03-06 12:00:05] ✨ CREATE: /var/uploads/photo.jpg
# → process.sh triggered
```

## Core Capabilities

1. Real-time monitoring — Zero-polling via Linux inotify, instant detection
2. Custom actions — Run any command/script when files change ($WATCH_FILE env var)
3. Telegram alerts — Get notified on your phone when critical files change
4. File filtering — Watch only specific extensions (*.js, *.log, *.pdf)
5. Exclude patterns — Skip node_modules, .git, temp files
6. Recursive watching — Monitor entire directory trees
7. Debounce control — Avoid duplicate triggers on rapid edits
8. Daemon mode — Run in background with PID management
9. systemd integration — Install as a persistent system service
10. YAML config — Define multiple watchers in one config file
11. Event logging — Log all file events to file for audit trails
12. Multi-watcher — Run multiple independent watchers simultaneously

## Dependencies
- `bash` (4.0+)
- `inotify-tools` (auto-installed via install.sh)
- Optional: `curl` (Telegram alerts), `python3` (YAML config)

## Installation Time
**2 minutes** — Run install.sh, start watching

## Pricing Justification
$8 — Simple utility with real automation value. Saves manual polling/checking. Comparable to fswatch setups that take 30+ min to configure properly.
