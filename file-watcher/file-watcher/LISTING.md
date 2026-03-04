# Listing Copy: File Watcher

## Metadata
- **Type:** Skill
- **Name:** file-watcher
- **Display Name:** File Watcher
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [inotify-tools, bash]

## Tagline

Watch files for changes — auto-trigger builds, syncs, alerts, or any command

## Description

Tired of manually rebuilding projects after every save? Forgetting to sync files to your server? Missing when config files change?

File Watcher monitors directories in real-time using Linux's native inotify subsystem. When files are created, modified, moved, or deleted, it instantly triggers whatever command you want — rebuild your project, sync to a server, compress images, restart services, or send alerts.

**What it does:**
- 👁️ Real-time file monitoring with zero polling overhead
- 🔧 Auto-trigger any command on file changes ($FILE and $EVENT variables)
- 🎯 Filter by file extension (.js, .py, .css, etc.)
- ⏱️ Smart debouncing — prevents rapid-fire on batch saves
- 🔄 Run as systemd service for always-on watching
- 📋 Multi-rule YAML config for complex setups
- 🐛 Daemon mode with PID management (start/stop/status)
- 📊 Optional logging to file

**Who it's for:** Developers, sysadmins, and anyone who wants to automate reactions to file changes without setting up complex CI/CD.

## Quick Start Preview

```bash
# Auto-run tests on code changes
bash scripts/watch.sh --dir ./src --ext ".py" --on-change "pytest" --debounce 3

# Auto-compress uploaded images
bash scripts/watch.sh --dir ./uploads --events create --ext ".jpg,.png" --on-change 'mogrify -resize "1920x>" "$FILE"'
```

## Core Capabilities

1. Real-time monitoring — Uses inotify (kernel-level, zero CPU polling)
2. Extension filtering — Watch only .ts, .py, .css, or any combination
3. Debounce control — Prevent rapid-fire triggers on batch saves
4. Exclusion patterns — Skip node_modules, .git, __pycache__ automatically
5. Multi-rule configs — YAML config file for complex watch setups
6. Systemd integration — Install as always-on service with auto-restart
7. Daemon mode — Background with PID management (start/stop/status)
8. Variable injection — $FILE and $EVENT available in your commands
9. Recursive watching — Monitors subdirectories by default
10. Logging — Optional file logging for audit trails
