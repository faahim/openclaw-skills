---
name: inotify-watcher
description: >-
  Monitor directories for file changes and trigger automated actions — run scripts, send notifications, sync files, or process uploads in real-time.
categories: [automation, dev-tools]
dependencies: [inotify-tools, bash]
---

# Inotify Watcher

## What This Does

Watches directories for file system events (create, modify, delete, move) and triggers automated actions in real-time. Use it to auto-process uploads, sync changes, trigger builds, send alerts on config modifications, or guard sensitive files.

**Example:** "Watch `/var/log/` for new files, parse them instantly. Watch `~/uploads/` and auto-compress images. Watch `/etc/` for unauthorized config changes and alert via Telegram."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y inotify-tools

# RHEL/CentOS/Fedora
sudo dnf install -y inotify-tools

# Alpine
apk add inotify-tools

# Verify
which inotifywait && echo "✅ Ready" || echo "❌ Install inotify-tools first"
```

### 2. Watch a Directory

```bash
# Watch current directory for any changes
bash scripts/watch.sh --dir . --events create,modify,delete --action echo

# Output:
# [2026-03-06 19:55:00] CREATE ./new-file.txt
# [2026-03-06 19:55:05] MODIFY ./new-file.txt
# [2026-03-06 19:55:10] DELETE ./new-file.txt
```

### 3. Run Custom Actions on Events

```bash
# Auto-compress images when added to uploads/
bash scripts/watch.sh \
  --dir ~/uploads \
  --events create \
  --filter '\.jpg$|\.png$' \
  --action 'scripts/compress-image.sh "$FILE"'

# Guard config files — alert on any change
bash scripts/watch.sh \
  --dir /etc/nginx \
  --events modify,delete \
  --action 'scripts/alert.sh "Config changed: $FILE ($EVENT)"'
```

## Core Workflows

### Workflow 1: Auto-Process Uploads

**Use case:** Compress/convert files as they arrive

```bash
bash scripts/watch.sh \
  --dir /srv/uploads \
  --events create,moved_to \
  --filter '\.(jpg|png|gif|webp)$' \
  --action 'mogrify -resize "1920x1920>" -quality 85 "$FILE" && echo "Compressed: $FILE"'
```

### Workflow 2: Config File Guardian

**Use case:** Alert when system configs are modified

```bash
bash scripts/watch.sh \
  --dir /etc \
  --recursive \
  --events modify,delete,create \
  --filter '\.(conf|cfg|ini|yaml|yml|json)$' \
  --action 'scripts/alert.sh "⚠️ Config changed: $EVENT $FILE at $(date)"'
```

### Workflow 3: Auto-Sync on Change

**Use case:** rsync files to remote when local changes

```bash
bash scripts/watch.sh \
  --dir ~/project/dist \
  --recursive \
  --events create,modify,delete \
  --debounce 5 \
  --action 'rsync -avz ~/project/dist/ user@server:/var/www/html/'
```

### Workflow 4: Build Trigger

**Use case:** Run build command when source files change

```bash
bash scripts/watch.sh \
  --dir ~/project/src \
  --recursive \
  --events modify,create \
  --filter '\.(ts|tsx|js|jsx)$' \
  --debounce 2 \
  --action 'cd ~/project && npm run build'
```

### Workflow 5: Log Watcher

**Use case:** Parse new log entries and alert on errors

```bash
bash scripts/watch.sh \
  --dir /var/log \
  --events modify \
  --filter '\.log$' \
  --action 'tail -1 "$FILE" | grep -i "error" && scripts/alert.sh "Error in $FILE"'
```

## Configuration

### Command-Line Options

```
--dir <path>        Directory to watch (required)
--recursive         Watch subdirectories too
--events <list>     Comma-separated: create,modify,delete,moved_to,moved_from,attrib
--filter <regex>    Only trigger on filenames matching regex
--exclude <regex>   Skip filenames matching regex
--action <cmd>      Command to run. Variables: $FILE (path), $EVENT (event type), $DIR (watched dir)
--debounce <secs>   Wait N seconds after last event before running action (coalesce rapid changes)
--log <file>        Log events to file
--daemon            Run in background (writes PID to --pidfile)
--pidfile <file>    PID file path (default: /tmp/inotify-watcher.pid)
--max-events <n>    Stop after N events (0 = unlimited, default)
```

### Environment Variables

```bash
# Telegram alerts (used by scripts/alert.sh)
export TELEGRAM_BOT_TOKEN="<your-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Email alerts
export SMTP_TO="admin@example.com"

# Increase watch limit if monitoring many files
echo 524288 | sudo tee /proc/sys/fs/inotify/max_user_watches
```

### Config File (YAML)

```yaml
# watcher.yaml — for multi-directory watching
watchers:
  - name: uploads
    dir: /srv/uploads
    recursive: true
    events: [create, moved_to]
    filter: '\.(jpg|png|gif)$'
    action: 'mogrify -resize "1920x1920>" "$FILE"'

  - name: configs
    dir: /etc
    recursive: true
    events: [modify, delete]
    filter: '\.(conf|yaml|json)$'
    action: 'scripts/alert.sh "Config: $EVENT $FILE"'

  - name: builds
    dir: ~/project/src
    recursive: true
    events: [modify, create]
    filter: '\.(ts|js)$'
    debounce: 3
    action: 'cd ~/project && npm run build'
```

```bash
# Run multi-watcher from config
bash scripts/multi-watch.sh --config watcher.yaml
```

## Advanced Usage

### Run as Systemd Service

```bash
# Install as service
bash scripts/install-service.sh --config /etc/inotify-watcher/watcher.yaml

# This creates /etc/systemd/system/inotify-watcher.service
sudo systemctl enable --now inotify-watcher
sudo systemctl status inotify-watcher
```

### Daemon Mode

```bash
# Start in background
bash scripts/watch.sh \
  --dir /srv/uploads \
  --events create \
  --action 'process-upload.sh "$FILE"' \
  --daemon \
  --pidfile /tmp/upload-watcher.pid \
  --log /var/log/upload-watcher.log

# Stop
kill $(cat /tmp/upload-watcher.pid)
```

### Increase Watch Limits

```bash
# Check current limit
cat /proc/sys/fs/inotify/max_user_watches

# Increase temporarily
echo 524288 | sudo tee /proc/sys/fs/inotify/max_user_watches

# Persist across reboots
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.d/40-inotify.conf
sudo sysctl -p /etc/sysctl.d/40-inotify.conf
```

## Troubleshooting

### Issue: "No space left on device" (but disk has space)

**Cause:** inotify watch limit reached

**Fix:**
```bash
echo 524288 | sudo tee /proc/sys/fs/inotify/max_user_watches
```

### Issue: Events firing multiple times

**Cause:** Editors save files in multiple steps (write temp → rename)

**Fix:** Use `--debounce 2` to coalesce rapid events

### Issue: Not watching subdirectories

**Fix:** Add `--recursive` flag

### Issue: inotifywait not found

**Fix:**
```bash
sudo apt-get install -y inotify-tools  # Debian/Ubuntu
sudo dnf install -y inotify-tools      # RHEL/Fedora
```

## Key Principles

1. **Real-time** — Events fire within milliseconds of filesystem changes
2. **Lightweight** — Uses kernel inotify API, near-zero CPU overhead
3. **Debounce** — Coalesce rapid events to avoid duplicate triggers
4. **Daemon-ready** — Run as background service with PID management
5. **Composable** — Chain with any shell command or script
