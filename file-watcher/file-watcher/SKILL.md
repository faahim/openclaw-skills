---
name: file-watcher
description: >-
  Watch files and directories for changes — auto-trigger commands on create, modify, or delete events.
categories: [automation, dev-tools]
dependencies: [inotify-tools, bash]
---

# File Watcher & Trigger

## What This Does

Monitor files and directories for real-time changes (create, modify, delete, move) and automatically run commands when events happen. Uses Linux `inotifywait` for kernel-level file system monitoring — no polling, zero CPU overhead.

**Example:** "Watch `/uploads/` — when a new image appears, auto-compress it. Watch `nginx.conf` — on change, reload nginx. Watch logs — on new error lines, send Telegram alert."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y inotify-tools

# Alpine
sudo apk add inotify-tools

# RHEL/CentOS/Fedora
sudo dnf install -y inotify-tools

# macOS (uses fswatch as fallback)
brew install fswatch

# Verify
which inotifywait && echo "✅ Ready" || echo "❌ Install inotify-tools"
```

### 2. Watch a Directory

```bash
# Watch current directory for any changes
bash scripts/watch.sh --path . --events create,modify --run 'echo "Changed: $WATCH_FILE"'
```

### 3. Watch Config File → Reload Service

```bash
bash scripts/watch.sh \
  --path /etc/nginx/nginx.conf \
  --events modify \
  --run 'nginx -t && systemctl reload nginx && echo "✅ Nginx reloaded"'
```

## Core Workflows

### Workflow 1: Auto-Process Uploads

**Use case:** Compress images when they appear in a directory

```bash
bash scripts/watch.sh \
  --path /var/uploads/ \
  --events create \
  --filter '\.jpg$|\.png$' \
  --run 'scripts/compress-image.sh "$WATCH_FILE"'
```

**Output:**
```
[2026-03-07 19:00:01] 👁️ Watching /var/uploads/ for CREATE events
[2026-03-07 19:00:15] 📁 CREATE: photo.jpg → Running compress-image.sh
[2026-03-07 19:00:16] ✅ Compressed photo.jpg (2.4MB → 890KB)
```

### Workflow 2: Config Change → Service Reload

**Use case:** Auto-reload services when config files change

```bash
bash scripts/watch.sh \
  --path /etc/myapp/config.yaml \
  --events modify,close_write \
  --run 'systemctl restart myapp'
```

### Workflow 3: Log File → Alert on Errors

**Use case:** Watch log file, alert when errors appear

```bash
bash scripts/watch.sh \
  --path /var/log/app.log \
  --events modify \
  --run 'tail -1 "$WATCH_FILE" | grep -qi "error" && curl -s "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage?chat_id=$TG_CHAT_ID&text=Error+in+app.log"'
```

### Workflow 4: Sync on Change

**Use case:** Auto-rsync when files change in a directory

```bash
bash scripts/watch.sh \
  --path /home/user/project/ \
  --events create,modify,delete \
  --recursive \
  --debounce 5 \
  --run 'rsync -avz /home/user/project/ remote:/backup/project/'
```

### Workflow 5: Development Auto-Build

**Use case:** Rebuild project when source files change

```bash
bash scripts/watch.sh \
  --path ./src/ \
  --recursive \
  --filter '\.ts$|\.tsx$' \
  --events modify,create \
  --debounce 2 \
  --run 'npm run build'
```

## Configuration

### Command-Line Options

```
--path <path>         File or directory to watch (required)
--events <events>     Comma-separated: create,modify,delete,move,close_write,attrib
--run <command>       Command to execute on event (required)
--recursive           Watch subdirectories too
--filter <regex>      Only trigger for filenames matching regex
--exclude <regex>     Ignore filenames matching regex
--debounce <seconds>  Wait N seconds after event before running (coalesce rapid changes)
--max-runs <N>        Stop after N triggers (0 = unlimited)
--log <file>          Log events to file
--daemon              Run in background (writes PID to /tmp/file-watcher-<hash>.pid)
--quiet               Suppress event output, only show command output
```

### Environment Variables (available in --run commands)

```bash
$WATCH_FILE     # Full path of the changed file
$WATCH_EVENT    # Event type (CREATE, MODIFY, DELETE, etc.)
$WATCH_DIR      # Directory being watched
$WATCH_NAME     # Filename only (no path)
$WATCH_TIME     # ISO timestamp of event
```

### Config File Format (YAML)

```yaml
# watch-config.yaml
watchers:
  - name: "Upload Processor"
    path: /var/uploads/
    events: [create]
    filter: '\.(jpg|png|gif)$'
    recursive: true
    debounce: 2
    run: 'scripts/process-upload.sh "$WATCH_FILE"'

  - name: "Nginx Config Reload"
    path: /etc/nginx/
    events: [modify, close_write]
    filter: '\.conf$'
    recursive: true
    run: 'nginx -t && systemctl reload nginx'

  - name: "Log Error Alert"
    path: /var/log/app/error.log
    events: [modify]
    run: 'tail -1 "$WATCH_FILE" | grep -q "CRITICAL" && notify.sh "$WATCH_FILE"'
```

Run with config:
```bash
bash scripts/watch.sh --config watch-config.yaml
```

## Advanced Usage

### Run as Systemd Service

```bash
# Generate systemd unit file
bash scripts/install-service.sh \
  --name "upload-watcher" \
  --path /var/uploads/ \
  --events create \
  --run '/usr/local/bin/process-upload.sh "$WATCH_FILE"'

# This creates /etc/systemd/system/file-watcher-upload-watcher.service
# Then:
sudo systemctl enable --now file-watcher-upload-watcher
```

### Manage Running Watchers

```bash
# List active watchers
bash scripts/watch.sh --list

# Stop a background watcher
bash scripts/watch.sh --stop <name-or-pid>

# Stop all watchers
bash scripts/watch.sh --stop-all
```

### Increase Watch Limits (for large directories)

```bash
# Check current limit
cat /proc/sys/fs/inotify/max_user_watches

# Increase (default 8192, set to 524288)
echo 524288 | sudo tee /proc/sys/fs/inotify/max_user_watches
echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Troubleshooting

### Issue: "No space left on device" (inotify limit)

**Fix:** Increase watch limits (see Advanced Usage above)

### Issue: Events firing multiple times

**Fix:** Use `--debounce 2` to coalesce rapid-fire events. Editors like vim create temp files that trigger extra events.

### Issue: Not detecting changes in subdirectories

**Fix:** Add `--recursive` flag

### Issue: macOS — inotifywait not available

**Fix:** The script auto-detects macOS and falls back to `fswatch`:
```bash
brew install fswatch
```

## Key Principles

1. **Kernel-level** — Uses inotify (not polling), zero CPU when idle
2. **Debounce** — Coalesce rapid changes to avoid command spam
3. **Environment vars** — Changed file info passed to your command
4. **Daemonize** — Run in background with PID tracking
5. **Filter** — Regex-based include/exclude for precision
6. **Cross-platform** — inotifywait (Linux) + fswatch (macOS) fallback

## Dependencies

- `inotify-tools` (Linux) or `fswatch` (macOS)
- `bash` (4.0+)
- Optional: `yq` (for YAML config parsing)
