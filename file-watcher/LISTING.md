# Listing Copy: File Watcher & Trigger

## Metadata
- **Type:** Skill
- **Name:** file-watcher
- **Display Name:** File Watcher & Trigger
- **Categories:** [automation, dev-tools]
- **Price:** $10
- **Icon:** 👁️
- **Dependencies:** [inotify-tools, bash]

## Tagline

Watch directories for changes — trigger any action automatically

## Description

Tired of manually running scripts after files change? Whether it's restarting a service when config changes, sorting downloads by type, or compressing new log files — File Watcher handles it automatically.

File Watcher & Trigger monitors directories using Linux's native inotify subsystem — zero CPU usage when idle, instant detection when files are created, modified, deleted, or moved. Hook up any shell command as a trigger action.

**What it does:**
- 👁️ Watch any directory for file system events (create, modify, delete, move)
- ⚡ Trigger custom shell commands instantly on changes
- 🔄 Built-in debounce to prevent action spam on rapid changes
- 📁 Pre-built actions: auto-sort downloads, Telegram alerts, backup files
- 🔧 Run as background daemon or systemd service
- 📋 YAML config for managing multiple watchers
- 🔌 Polling fallback for NFS/CIFS network mounts
- 📊 Full event logging with timestamps

**Perfect for:** developers automating build-on-save, sysadmins reloading services on config changes, anyone who wants their filesystem to react to changes automatically.

## Quick Start Preview

```bash
# Install
sudo apt-get install -y inotify-tools

# Watch a directory
bash scripts/watch.sh --dir ~/Downloads --events create --action 'echo "New file: $WATCH_FILE"'
```

## Core Capabilities

1. Directory monitoring — Watch any local directory using kernel inotify
2. Custom triggers — Run any shell command when files change
3. Event filtering — Match specific file patterns with regex filters
4. Smart debounce — Batch rapid events, trigger once
5. Daemon mode — Run in background with PID management
6. Systemd integration — Install as auto-starting service
7. Multi-watcher config — YAML config for multiple directories
8. Built-in actions — Sort files, send Telegram alerts, create backups
9. Polling fallback — Works on NFS/CIFS with poll mode
10. Environment variables — Actions receive file path, event type, extension

## Dependencies
- `bash` (4.0+)
- `inotify-tools` (apt/dnf/pacman)

## Installation Time
**2 minutes** — Install inotify-tools, run script
