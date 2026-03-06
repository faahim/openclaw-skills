# Listing Copy: Folder Watcher

## Metadata
- **Type:** Skill
- **Name:** folder-watcher
- **Display Name:** Folder Watcher
- **Categories:** [automation, productivity]
- **Icon:** 👁️
- **Dependencies:** [inotify-tools, bash]

## Tagline

Monitor directories for file changes — auto-organize, compress, notify, or trigger scripts instantly.

## Description

Tired of manually sorting downloads, watching for file changes, or triggering builds by hand? Folder Watcher uses Linux's inotify (or macOS's fswatch) to monitor directories in real-time and react instantly to file events.

When files are created, modified, deleted, or moved, Folder Watcher triggers your chosen action automatically: organize files by type, compress large uploads, copy to backups, send Telegram notifications, or run any custom script.

**What it does:**
- 👁️ Watch any directory for file system events in real-time
- 📂 Auto-organize files by extension (PDFs → Documents, images → Pictures)
- 🗜️ Auto-compress large files with gzip
- 📋 Copy changed files to backup destinations
- 🔔 Send Telegram/webhook notifications on new files
- ⚡ Run custom scripts on file changes (build triggers, processing pipelines)
- ⏱️ Debounce rapid changes to avoid repeated triggers
- 🔧 Run as systemd service for persistent monitoring

Perfect for developers, sysadmins, and power users who want filesystem automation without heavy tools.

## Quick Start Preview

```bash
# Install inotify-tools
bash scripts/install.sh

# Watch Downloads folder, auto-organize by file type
bash scripts/watch.sh --dir ~/Downloads --events create --action organize

# Watch for code changes, trigger build
bash scripts/watch.sh --dir ./src --events modify --action script --script "make build" --debounce 2
```

## Core Capabilities

1. Real-time directory monitoring — instant detection via inotify/fswatch
2. Auto-organize — sort files by extension into categorized folders
3. Auto-compress — gzip large files automatically
4. Backup sync — copy changed files to backup directories
5. Script triggers — run any command on file events
6. Telegram alerts — instant notifications on file changes
7. Debounce support — batch rapid changes to prevent spam
8. Exclude patterns — skip temp files, .git, node_modules
9. Systemd service — run persistently as a background daemon
10. Cross-platform — Linux (inotify) + macOS (fswatch) support
