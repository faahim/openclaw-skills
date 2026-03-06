---
name: file-watcher
description: >-
  Watch files and directories for changes — trigger scripts, sync, alerts, or backups automatically on create/modify/delete events.
categories: [automation, productivity]
dependencies: [inotify-tools, bash]
---

# File Watcher

## What This Does

Monitor files and directories for real-time changes using Linux's inotify subsystem. When files are created, modified, moved, or deleted, automatically trigger custom actions — run scripts, send notifications, sync files, or start backups. Zero polling, zero CPU waste.

**Example:** "Watch my uploads folder — when a new image lands, auto-compress it and move to processed/"

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Install inotify-tools (provides inotifywait)
bash scripts/install.sh
```

### 2. Watch a Directory

```bash
# Watch current directory for any changes
bash scripts/watch.sh --dir /path/to/watch

# Output:
# [2026-03-06 12:00:00] 👁️ Watching /path/to/watch (create,modify,delete,move)
# [2026-03-06 12:00:05] ✨ CREATE: /path/to/watch/newfile.txt
# [2026-03-06 12:00:10] ✏️ MODIFY: /path/to/watch/newfile.txt
```

### 3. Trigger Actions on Changes

```bash
# Run a script when files change
bash scripts/watch.sh --dir /var/uploads --on-change "bash /opt/process.sh"

# Send Telegram alert on new files
bash scripts/watch.sh --dir /var/uploads --events create --telegram

# Auto-sync to remote on any change
bash scripts/watch.sh --dir ~/documents --on-change "rsync -avz ~/documents/ remote:~/backup/"
```

## Core Workflows

### Workflow 1: Development Hot-Reload Trigger

**Use case:** Trigger rebuild when source files change

```bash
bash scripts/watch.sh \
  --dir ./src \
  --events modify,create,delete \
  --filter '*.js,*.ts,*.css' \
  --on-change "npm run build" \
  --debounce 2
```

### Workflow 2: Upload Processing Pipeline

**Use case:** Auto-process files dropped into a folder

```bash
bash scripts/watch.sh \
  --dir /var/uploads \
  --events create,moved_to \
  --on-change "bash scripts/process-upload.sh" \
  --recursive
```

### Workflow 3: Log File Alert

**Use case:** Alert when log files are modified (new errors)

```bash
bash scripts/watch.sh \
  --dir /var/log/myapp \
  --events modify \
  --filter '*.log' \
  --on-change 'tail -1 "$WATCH_FILE" | grep -i error && curl -s "https://api.telegram.org/bot$BOT_TOKEN/sendMessage?chat_id=$CHAT_ID&text=Error+in+$WATCH_FILE"'
```

### Workflow 4: Backup on Change

**Use case:** Auto-backup config files when edited

```bash
bash scripts/watch.sh \
  --dir /etc/nginx \
  --events modify \
  --on-change 'cp "$WATCH_FILE" /backup/nginx/$(date +%Y%m%d_%H%M%S)_$(basename "$WATCH_FILE")'
```

### Workflow 5: Sync Directories

**Use case:** Keep two directories in sync

```bash
bash scripts/watch.sh \
  --dir ~/project \
  --recursive \
  --on-change "rsync -avz --delete ~/project/ /mnt/backup/project/" \
  --debounce 5
```

## Configuration

### Command-Line Options

```
--dir PATH          Directory to watch (required)
--recursive         Watch subdirectories too
--events EVENTS     Comma-separated: create,modify,delete,move,attrib (default: create,modify,delete,move)
--filter PATTERNS   Comma-separated glob patterns: '*.js,*.ts' (default: all files)
--exclude PATTERNS  Comma-separated patterns to ignore: 'node_modules,.git'
--on-change CMD     Command to run on each event (has $WATCH_FILE, $WATCH_EVENT, $WATCH_DIR env vars)
--telegram          Send Telegram notification on events (needs TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID)
--log FILE          Log events to file
--debounce SECS     Wait N seconds after last event before triggering action (default: 1)
--daemon            Run in background (writes PID to /tmp/file-watcher-<hash>.pid)
--quiet             Suppress console output (still logs if --log set)
```

### Environment Variables

```bash
# For Telegram alerts
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Available inside --on-change commands:
# $WATCH_FILE   — Full path of changed file
# $WATCH_EVENT  — Event type (CREATE, MODIFY, DELETE, MOVED_TO, MOVED_FROM)
# $WATCH_DIR    — Watched directory
```

### Config File (YAML)

```bash
# Use config file instead of CLI args
bash scripts/watch.sh --config config.yaml
```

```yaml
# config.yaml
watchers:
  - name: uploads
    dir: /var/uploads
    recursive: true
    events: [create, moved_to]
    filter: ["*.jpg", "*.png", "*.pdf"]
    exclude: [".tmp", "thumbs"]
    on_change: "bash /opt/process-upload.sh"
    debounce: 2

  - name: configs
    dir: /etc/nginx
    events: [modify]
    on_change: "nginx -t && systemctl reload nginx"
    telegram: true

  - name: logs
    dir: /var/log/app
    events: [modify]
    filter: ["*.log"]
    on_change: 'tail -1 "$WATCH_FILE" | grep -qi "error" && echo "Error detected in $WATCH_FILE"'
```

## Advanced Usage

### Run as systemd Service

```bash
# Install as service
bash scripts/install-service.sh --config /path/to/config.yaml

# Manage
sudo systemctl start file-watcher
sudo systemctl enable file-watcher
sudo systemctl status file-watcher
```

### Multiple Watchers

```bash
# Start multiple watchers in background
bash scripts/watch.sh --dir /var/uploads --on-change "process.sh" --daemon
bash scripts/watch.sh --dir /etc/nginx --on-change "reload.sh" --daemon

# List running watchers
bash scripts/watch.sh --list

# Stop all watchers
bash scripts/watch.sh --stop-all
```

### OpenClaw Cron Integration

```bash
# Use with OpenClaw cron to restart watcher if it dies
# In your cron job:
pgrep -f "file-watcher" || bash /path/to/scripts/watch.sh --config config.yaml --daemon
```

## Troubleshooting

### Issue: "inotifywait: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
sudo apt-get install -y inotify-tools  # Debian/Ubuntu
sudo yum install -y inotify-tools      # RHEL/CentOS
sudo pacman -S inotify-tools           # Arch
```

### Issue: "Failed to watch: No space left on device"

This means the inotify watch limit is reached.

**Fix:**
```bash
# Check current limit
cat /proc/sys/fs/inotify/max_user_watches

# Increase temporarily
sudo sysctl fs.inotify.max_user_watches=524288

# Increase permanently
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Issue: Events firing too fast (duplicate triggers)

**Fix:** Increase debounce:
```bash
bash scripts/watch.sh --dir /path --on-change "cmd" --debounce 5
```

### Issue: Not catching events in subdirectories

**Fix:** Add `--recursive`:
```bash
bash scripts/watch.sh --dir /path --recursive --on-change "cmd"
```

## Dependencies

- `bash` (4.0+)
- `inotify-tools` (provides `inotifywait`) — Linux only
- Optional: `curl` (for Telegram alerts)
- Optional: `rsync` (for sync workflows)
- Optional: `yq` or `python3` (for YAML config parsing)
