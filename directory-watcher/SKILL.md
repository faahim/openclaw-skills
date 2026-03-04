---
name: directory-watcher
description: >-
  Watch directories for file changes and automatically trigger commands, scripts, or notifications.
categories: [automation, dev-tools]
dependencies: [inotify-tools, bash]
---

# Directory Watcher

## What This Does

Monitors directories for file changes (create, modify, delete, move) and automatically runs commands when events occur. Perfect for auto-builds, file sync triggers, backup automation, and deployment pipelines.

**Example:** "Watch `/var/www/html` — when any `.html` file changes, rebuild the search index and send a Telegram notification."

## Quick Start (3 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y inotify-tools

# Alpine
apk add inotify-tools

# RHEL/CentOS/Fedora
sudo dnf install -y inotify-tools

# Mac (uses fswatch instead)
brew install fswatch
```

### 2. Watch a Directory

```bash
# Watch current directory for any changes
bash scripts/watch.sh --dir . --on-change "echo 'File changed: \$FILE'"

# Output:
# [2026-03-04 10:00:01] 👁️ Watching: . (create,modify,delete,move)
# [2026-03-04 10:00:15] 📝 MODIFY: ./README.md
# File changed: ./README.md
```

### 3. Auto-Build on Save

```bash
# Rebuild project when source files change
bash scripts/watch.sh \
  --dir ./src \
  --filter "*.js,*.ts,*.css" \
  --on-change "npm run build" \
  --debounce 2
```

## Core Workflows

### Workflow 1: Auto-Build on File Change

**Use case:** Rebuild project when source code changes

```bash
bash scripts/watch.sh \
  --dir ./src \
  --filter "*.js,*.ts,*.jsx,*.tsx" \
  --on-change "npm run build" \
  --debounce 3 \
  --recursive
```

**Output:**
```
[2026-03-04 10:00:01] 👁️ Watching: ./src (recursive, filter: *.js,*.ts,*.jsx,*.tsx)
[2026-03-04 10:02:33] 📝 MODIFY: ./src/components/App.tsx
[2026-03-04 10:02:36] ⚡ Running: npm run build
[2026-03-04 10:02:38] ✅ Command completed (exit: 0, 2.1s)
```

### Workflow 2: Sync on New Files

**Use case:** Upload new files to S3 when they appear

```bash
bash scripts/watch.sh \
  --dir /data/exports \
  --events create \
  --on-change "aws s3 cp \$FILE s3://my-bucket/exports/" \
  --log /var/log/file-sync.log
```

### Workflow 3: Alert on Config Changes

**Use case:** Get notified when config files are modified (security)

```bash
bash scripts/watch.sh \
  --dir /etc \
  --filter "*.conf,*.cfg,*.ini" \
  --events modify,delete \
  --recursive \
  --on-change "bash scripts/notify.sh 'Config changed: \$FILE \$EVENT'" \
  --log /var/log/config-watch.log
```

### Workflow 4: Auto-Restart Service

**Use case:** Restart a service when its config changes

```bash
bash scripts/watch.sh \
  --dir /etc/nginx/sites-enabled \
  --on-change "nginx -t && systemctl reload nginx" \
  --debounce 5
```

### Workflow 5: Backup Trigger

**Use case:** Run backup when important files change

```bash
bash scripts/watch.sh \
  --dir /home/user/documents \
  --events create,modify \
  --recursive \
  --on-change "rsync -avz /home/user/documents/ /backup/documents/" \
  --debounce 60
```

## Configuration

### Command Line Options

```
--dir DIR          Directory to watch (required)
--events EVENTS    Comma-separated: create,modify,delete,move,attrib (default: create,modify,delete,move)
--filter PATTERN   Comma-separated glob patterns: "*.js,*.ts" (default: all files)
--exclude PATTERN  Comma-separated patterns to exclude: "node_modules,.git"
--on-change CMD    Command to run on event ($FILE, $EVENT, $DIR available)
--on-create CMD    Command to run only on create events
--on-modify CMD    Command to run only on modify events
--on-delete CMD    Command to run only on delete events
--recursive        Watch subdirectories recursively
--debounce SECS    Wait N seconds after last event before running (default: 1)
--log FILE         Log events to file
--daemon           Run as background daemon
--pid FILE         PID file path (for daemon mode)
--max-events N     Stop after N events (0 = unlimited, default: 0)
--quiet            Suppress output (log only)
```

### Config File (YAML)

```yaml
# watch-config.yaml
watchers:
  - name: "source-build"
    dir: ./src
    recursive: true
    filter: ["*.js", "*.ts", "*.css"]
    exclude: ["node_modules", ".git", "dist"]
    events: [create, modify, delete]
    on_change: "npm run build"
    debounce: 3

  - name: "config-alert"
    dir: /etc/nginx
    recursive: true
    filter: ["*.conf"]
    events: [modify]
    on_change: "nginx -t && systemctl reload nginx"
    debounce: 5

  - name: "upload-sync"
    dir: /data/exports
    events: [create]
    on_change: "aws s3 cp $FILE s3://bucket/exports/"
    debounce: 0
```

```bash
# Run with config file
bash scripts/watch.sh --config watch-config.yaml
```

### Environment Variables

```bash
# Override defaults
export WATCHER_DEBOUNCE=2
export WATCHER_LOG=/var/log/watcher.log
export WATCHER_EXCLUDE="node_modules,.git,__pycache__"
```

## Advanced Usage

### Run as Systemd Service

```bash
# Install as service
bash scripts/install-service.sh --config /path/to/watch-config.yaml

# This creates /etc/systemd/system/directory-watcher.service
# and enables it to start on boot
```

### Multiple Watchers

```bash
# Run multiple watchers from config
bash scripts/watch.sh --config watch-config.yaml
# All watchers defined in YAML run simultaneously
```

### Custom Notify Script

The included `scripts/notify.sh` sends alerts via:
- Telegram (if `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` set)
- Email (if `SMTP_HOST` set)
- Webhook (if `WEBHOOK_URL` set)
- stdout (always)

```bash
# Set up Telegram notifications
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

bash scripts/watch.sh \
  --dir /important/files \
  --on-change "bash scripts/notify.sh 'Changed: \$FILE'"
```

### Pipe Events to Script

```bash
# Process events in a custom script
bash scripts/watch.sh --dir ./data --format json | python3 process-events.py
```

### macOS Support

On macOS, the watcher uses `fswatch` instead of `inotifywait`:

```bash
# Automatically detected — same interface
bash scripts/watch.sh --dir ./src --on-change "make build"
```

## Troubleshooting

### Issue: "inotifywait: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install -y inotify-tools

# Verify
which inotifywait
```

### Issue: "Failed to watch: too many open files"

```bash
# Increase inotify watch limit
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Issue: Events firing too rapidly

```bash
# Increase debounce
bash scripts/watch.sh --dir . --on-change "make build" --debounce 5
```

### Issue: Missing events in large directories

```bash
# Increase inotify queue size
echo "fs.inotify.max_queued_events=65536" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Key Principles

1. **Lightweight** — Uses kernel-level inotify (near-zero CPU)
2. **Debounce** — Prevents command spam on rapid changes
3. **Filter** — Only trigger on files you care about
4. **Cross-platform** — inotifywait (Linux) + fswatch (macOS)
5. **Daemon-ready** — Run as systemd service for production

## Dependencies

- `inotify-tools` (Linux) or `fswatch` (macOS)
- `bash` (4.0+)
- Optional: `yq` (for YAML config parsing)
- Optional: `curl` (for webhook/Telegram notifications)
