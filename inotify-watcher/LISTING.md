# Listing Copy: Inotify Watcher

## Metadata
- **Type:** Skill
- **Name:** inotify-watcher
- **Display Name:** Inotify Watcher
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [inotify-tools, bash]
- **Icon:** 👁️

## Tagline

Watch directories for changes — trigger scripts, alerts, and syncs in real-time

## Description

Manually checking for file changes is tedious and error-prone. Whether it's uploads that need processing, config files that shouldn't be touched, or source code that needs rebuilding — you need automated filesystem monitoring.

Inotify Watcher uses Linux's native inotify API to monitor directories in real-time with near-zero CPU overhead. When files are created, modified, deleted, or moved, it triggers your custom actions instantly — run scripts, send Telegram alerts, sync files, or kick off builds.

**What it does:**
- 👁️ Monitor directories for create, modify, delete, move events
- 🎯 Filter by filename patterns (regex)
- ⚡ Trigger any shell command with file/event variables
- 🔔 Built-in Telegram and email alerting
- ⏱️ Debounce rapid events to avoid duplicate triggers
- 📋 Multi-directory config via YAML
- 🔧 Install as systemd service for always-on monitoring
- 📝 Event logging with timestamps

## Core Capabilities

1. Real-time monitoring — Events fire within milliseconds via kernel inotify
2. Custom actions — Run any shell command with $FILE, $EVENT, $TIMESTAMP variables
3. Pattern filtering — Regex-based include/exclude for targeted watching
4. Event debouncing — Coalesce rapid changes (editor save cycles) into single triggers
5. Multi-directory — Watch multiple directories with different actions from one YAML config
6. Telegram alerts — Built-in alert script for instant notifications
7. Systemd service — Install as persistent background service
8. Daemon mode — Run in background with PID management
9. Recursive watching — Monitor entire directory trees
10. Zero dependencies — Just inotify-tools and bash (both standard on Linux)

## Installation Time
**2 minutes** — Install inotify-tools, run the script
