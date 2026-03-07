# Listing Copy: File Watcher & Trigger

## Metadata
- **Type:** Skill
- **Name:** file-watcher
- **Display Name:** File Watcher & Trigger
- **Categories:** [automation, dev-tools]
- **Icon:** 👁️
- **Dependencies:** [inotify-tools, bash]

## Tagline
Watch files for changes — auto-trigger commands on create, modify, or delete

## Description

Checking for file changes manually or writing custom polling scripts wastes time and CPU. You need instant, reliable file monitoring that triggers actions the moment something changes.

**File Watcher & Trigger** uses Linux kernel-level inotify to monitor files and directories with zero CPU overhead. When a file is created, modified, or deleted, your command runs instantly. No polling, no delays, no wasted resources.

**What it does:**
- 👁️ Real-time monitoring of files and directories using inotify (Linux) or fswatch (macOS)
- ⚡ Instant command execution on file events (create, modify, delete, move)
- 🎯 Regex filtering — only trigger for specific file patterns (.jpg, .py, .conf, etc.)
- ⏱️ Smart debouncing — coalesce rapid changes (editors save multiple times)
- 🔄 Recursive directory watching with configurable depth
- 🛡️ Daemon mode with PID tracking and systemd service generation
- 📋 YAML config for managing multiple watchers
- 📝 Event logging with timestamps

**Perfect for:** developers who want auto-build on save, sysadmins who need config-reload automation, anyone processing uploaded files, or monitoring logs for error alerts.

## Quick Start Preview

```bash
# Auto-reload nginx when config changes
bash scripts/watch.sh --path /etc/nginx/ --recursive --events modify --run 'nginx -t && systemctl reload nginx'

# Process new uploads
bash scripts/watch.sh --path /uploads/ --events create --filter '\.jpg$' --run 'compress.sh "$WATCH_FILE"'
```

## Core Capabilities

1. Kernel-level file monitoring — uses inotify, zero CPU when idle
2. Event-driven commands — run any shell command on file changes
3. Smart debouncing — coalesce rapid-fire events from editors
4. Regex file filtering — trigger only for matching filenames
5. Recursive watching — monitor entire directory trees
6. Environment variables — $WATCH_FILE, $WATCH_EVENT, $WATCH_NAME in commands
7. Daemon mode — background execution with PID management
8. Systemd integration — auto-generate service files for persistent watchers
9. YAML config — manage multiple watchers in one file
10. Cross-platform — inotifywait (Linux) + fswatch (macOS) fallback
11. Event logging — timestamped log file output
12. Max-runs limit — auto-stop after N triggers
