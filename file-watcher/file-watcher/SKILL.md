---
name: file-watcher
description: >-
  Watch files and directories for changes — auto-trigger commands on create, modify, or delete events.
categories: [automation, dev-tools]
dependencies: [inotify-tools, bash]
---

# File Watcher

## What This Does

Monitors files and directories for changes in real-time using Linux's inotify subsystem. When a file is created, modified, moved, or deleted, it automatically triggers custom commands — rebuild projects, sync files, send notifications, run tests, or anything else.

**Example:** "Watch `./src/` for changes, auto-run `npm test` on every save. Watch `./uploads/` for new files, auto-compress images."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y inotify-tools

# Fedora/RHEL
sudo dnf install -y inotify-tools

# Alpine
sudo apk add inotify-tools

# Arch
sudo pacman -S inotify-tools
```

### 2. Watch a Directory

```bash
# Watch current directory for any changes
bash scripts/watch.sh --dir . --on-change "echo 'File changed: \$FILE'"

# Output:
# [2026-03-04 03:00:01] 👁️ Watching: . (events: modify,create,delete,move)
# [2026-03-04 03:00:15] 📝 MODIFY: ./README.md
# File changed: ./README.md
```

### 3. Auto-Rebuild on Save

```bash
bash scripts/watch.sh \
  --dir ./src \
  --events modify \
  --ext ".ts,.js,.tsx" \
  --on-change "npm run build" \
  --debounce 2
```

## Core Workflows

### Workflow 1: Auto-Run Tests on File Change

```bash
bash scripts/watch.sh \
  --dir ./src \
  --events modify \
  --ext ".py" \
  --on-change "python -m pytest tests/ -q" \
  --debounce 3
```

### Workflow 2: Auto-Compress New Images

```bash
bash scripts/watch.sh \
  --dir ./uploads \
  --events create \
  --ext ".jpg,.png,.webp" \
  --on-change 'mogrify -resize "1920x1080>" -quality 85 "$FILE"' \
  --log ./logs/compress.log
```

### Workflow 3: Sync Files to Remote Server

```bash
bash scripts/watch.sh \
  --dir ./deploy \
  --events modify,create,delete \
  --on-change 'rsync -avz ./deploy/ user@server:/var/www/html/' \
  --debounce 5
```

### Workflow 4: Auto-Restart Service on Config Change

```bash
bash scripts/watch.sh \
  --dir /etc/nginx/sites-enabled \
  --events modify,create,delete \
  --on-change "sudo nginx -t && sudo systemctl reload nginx" \
  --debounce 2
```

### Workflow 5: Watch for New Log Entries and Alert

```bash
bash scripts/watch.sh \
  --dir /var/log \
  --events modify \
  --ext ".log" \
  --on-change 'tail -1 "$FILE" | grep -qi "error" && curl -s "https://api.telegram.org/bot$BOT_TOKEN/sendMessage?chat_id=$CHAT_ID&text=Error in $FILE"'
```

### Workflow 6: Development Live Reload

```bash
bash scripts/watch.sh \
  --dir ./public \
  --events modify,create \
  --ext ".html,.css,.js" \
  --on-change 'curl -s http://localhost:35729/changed?files="$FILE"' \
  --debounce 1
```

## Configuration

### Command-Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `--dir` | `.` | Directory to watch (recursive by default) |
| `--events` | `modify,create,delete,move` | Comma-separated inotify events |
| `--ext` | (all files) | Filter by extensions: `.js,.ts,.py` |
| `--exclude` | (none) | Regex pattern to exclude: `node_modules\|\.git` |
| `--on-change` | (required) | Command to run. `$FILE` = changed file, `$EVENT` = event type |
| `--debounce` | `1` | Seconds to wait before running (prevents rapid-fire) |
| `--log` | (none) | Log file path |
| `--no-recursive` | (off) | Don't watch subdirectories |
| `--daemon` | (off) | Run in background, write PID to `--pidfile` |
| `--pidfile` | `/tmp/file-watcher.pid` | PID file for daemon mode |

### Environment Variables

```bash
# Override defaults via environment
export WATCH_DIR="./src"
export WATCH_EVENTS="modify,create"
export WATCH_DEBOUNCE=2
export WATCH_EXCLUDE="node_modules|\.git|__pycache__"
```

### Available Events

| Event | Fires When |
|-------|-----------|
| `modify` | File content changes |
| `create` | New file/dir created |
| `delete` | File/dir deleted |
| `move` | File/dir renamed or moved |
| `attrib` | Permissions/ownership changes |
| `close_write` | File closed after writing |
| `open` | File opened |

## Advanced Usage

### Run as Systemd Service

```bash
bash scripts/install-service.sh \
  --name "project-watcher" \
  --dir /home/user/project/src \
  --events modify,create \
  --on-change "/home/user/project/scripts/rebuild.sh" \
  --debounce 3
```

This creates `/etc/systemd/system/file-watcher-project-watcher.service` that:
- Starts on boot
- Restarts on failure
- Logs to journalctl

### Multiple Watch Rules (Config File)

```yaml
# watch-config.yaml
rules:
  - name: rebuild-frontend
    dir: ./frontend/src
    events: [modify, create, delete]
    ext: [.tsx, .ts, .css]
    on_change: "cd frontend && npm run build"
    debounce: 3

  - name: compress-uploads
    dir: ./uploads
    events: [create]
    ext: [.jpg, .png]
    on_change: 'mogrify -resize "1920x>" -quality 85 "$FILE"'
    debounce: 1

  - name: sync-docs
    dir: ./docs
    events: [modify, create, delete]
    on_change: "rsync -avz ./docs/ server:/var/www/docs/"
    debounce: 5
```

```bash
bash scripts/watch.sh --config watch-config.yaml
```

### Daemon Mode

```bash
# Start in background
bash scripts/watch.sh --dir ./src --on-change "make build" --daemon --pidfile /tmp/my-watcher.pid

# Check status
bash scripts/watch.sh --status --pidfile /tmp/my-watcher.pid

# Stop
bash scripts/watch.sh --stop --pidfile /tmp/my-watcher.pid
```

## Troubleshooting

### Issue: "No space left on device" (inotify limit)

**Fix:** Increase inotify watch limit:
```bash
# Temporary
sudo sysctl fs.inotify.max_user_watches=524288

# Permanent
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.d/99-inotify.conf
sudo sysctl -p /etc/sysctl.d/99-inotify.conf
```

### Issue: Command fires too many times

**Fix:** Increase debounce:
```bash
bash scripts/watch.sh --dir ./src --on-change "make" --debounce 5
```

### Issue: Not detecting changes in subdirectories

**Fix:** Ensure recursive mode (default). Check inotify limit if deep trees.

### Issue: "inotifywait: command not found"

**Fix:** Install inotify-tools (see Quick Start step 1).

## Dependencies

- `bash` (4.0+)
- `inotify-tools` (provides `inotifywait`)
- Optional: `yq` (for YAML config files)
