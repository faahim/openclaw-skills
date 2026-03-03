---
name: file-watcher
description: >-
  Watch directories for file changes and trigger custom actions automatically using inotifywait.
categories: [automation, dev-tools]
dependencies: [inotify-tools, bash]
---

# File Watcher & Trigger

## What This Does

Monitors directories for file system events (create, modify, delete, move) and triggers custom actions when changes are detected. Uses Linux's inotify subsystem via `inotifywait` for efficient, low-overhead watching — no polling, no CPU waste.

**Example:** "Watch `/var/log/` for new files → compress and archive them. Watch `~/Downloads/` → auto-sort files by extension. Watch a deploy directory → restart services on config changes."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y inotify-tools

# RHEL/CentOS/Fedora
sudo dnf install -y inotify-tools

# Arch
sudo pacman -S inotify-tools

# Verify
which inotifywait && echo "✅ Ready"
```

### 2. Watch a Directory (One-liner)

```bash
# Watch current directory for any changes
bash scripts/watch.sh --dir . --events create,modify --action 'echo "Changed: $WATCH_FILE"'
```

### 3. Watch with Config File

```bash
# Copy and edit config
cp scripts/config-template.yaml config.yaml

# Run with config
bash scripts/watch.sh --config config.yaml
```

## Core Workflows

### Workflow 1: Auto-Sort Downloads

**Use case:** Automatically move downloaded files to folders by type

```bash
bash scripts/watch.sh \
  --dir ~/Downloads \
  --events create,moved_to \
  --action 'bash scripts/actions/sort-by-extension.sh "$WATCH_FILE"'
```

**What happens:**
```
[2026-03-03 09:00:01] 👁️ Watching: /home/user/Downloads (create,moved_to)
[2026-03-03 09:01:15] 📄 report.pdf → Moved to ~/Documents/PDFs/
[2026-03-03 09:02:30] 🖼️ photo.jpg → Moved to ~/Pictures/
[2026-03-03 09:03:45] 📦 archive.zip → Moved to ~/Archives/
```

### Workflow 2: Auto-Restart Service on Config Change

**Use case:** Restart nginx/app when config files change

```bash
bash scripts/watch.sh \
  --dir /etc/nginx/conf.d \
  --events modify,create,delete \
  --action 'echo "Config changed: $WATCH_FILE"; sudo nginx -t && sudo systemctl reload nginx' \
  --debounce 5
```

**Output:**
```
[2026-03-03 09:00:01] 👁️ Watching: /etc/nginx/conf.d (modify,create,delete)
[2026-03-03 09:15:22] ⚡ default.conf modified → nginx -t passed → Reloaded nginx
```

### Workflow 3: Auto-Compress Log Files

**Use case:** Compress log files when they're rotated/created

```bash
bash scripts/watch.sh \
  --dir /var/log/myapp \
  --events create \
  --filter '\.log$' \
  --action 'gzip -9 "$WATCH_FILE" && echo "Compressed: $WATCH_FILE.gz"' \
  --debounce 10
```

### Workflow 4: Sync on Change

**Use case:** Trigger rsync when files change in a directory

```bash
bash scripts/watch.sh \
  --dir /home/user/project \
  --events modify,create,delete \
  --exclude '.git|node_modules|__pycache__' \
  --action 'rsync -avz /home/user/project/ remote:/backup/project/' \
  --debounce 3
```

### Workflow 5: Build on Save (Dev Hot-Reload)

**Use case:** Run build command when source files change

```bash
bash scripts/watch.sh \
  --dir ./src \
  --events modify \
  --filter '\.(js|ts|jsx|tsx)$' \
  --action 'npm run build 2>&1 | tail -5' \
  --debounce 2 \
  --recursive
```

## Configuration

### Config File Format (YAML)

```yaml
# config.yaml
watchers:
  - name: "downloads-sorter"
    dir: ~/Downloads
    events: [create, moved_to]
    recursive: false
    action: 'bash scripts/actions/sort-by-extension.sh "$WATCH_FILE"'

  - name: "config-reloader"
    dir: /etc/nginx/conf.d
    events: [modify, create, delete]
    recursive: true
    filter: '\.conf$'
    exclude: '\.swp$|~$'
    debounce: 5
    action: 'sudo nginx -t && sudo systemctl reload nginx'

  - name: "log-compressor"
    dir: /var/log/myapp
    events: [create]
    filter: '\.log$'
    debounce: 10
    action: 'gzip -9 "$WATCH_FILE"'

# Global settings
settings:
  log_file: /var/log/file-watcher.log
  max_log_size: 10M  # Rotate at 10MB
  notify_on_error: true
  notify_command: 'curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=File Watcher Error: $ERROR_MSG"'
```

### Command-Line Options

```
--dir <path>        Directory to watch (required unless --config)
--events <list>     Comma-separated: create,modify,delete,move,attrib,close_write
--action <cmd>      Shell command to run (receives $WATCH_FILE, $WATCH_EVENT, $WATCH_DIR)
--config <file>     YAML config file for multiple watchers
--recursive         Watch subdirectories too
--filter <regex>    Only trigger on filenames matching regex
--exclude <regex>   Skip filenames matching regex
--debounce <secs>   Wait N seconds after last event before triggering (default: 1)
--daemon            Run in background (writes PID to /tmp/file-watcher.pid)
--log <file>        Log output to file
```

### Environment Variables Available in Actions

```bash
$WATCH_FILE    # Full path of the changed file
$WATCH_EVENT   # Event type (CREATE, MODIFY, DELETE, etc.)
$WATCH_DIR     # Watched directory path
$WATCH_NAME    # Filename only (no path)
$WATCH_EXT     # File extension
```

## Advanced Usage

### Run as Systemd Service

```bash
# Install as service
bash scripts/install-service.sh --config /path/to/config.yaml

# This creates /etc/systemd/system/file-watcher.service
# and enables it to start on boot

# Manage
sudo systemctl start file-watcher
sudo systemctl stop file-watcher
sudo systemctl status file-watcher
journalctl -u file-watcher -f
```

### Multiple Watchers

```bash
# Run from config (starts all watchers in parallel)
bash scripts/watch.sh --config config.yaml

# Or run individually in background
bash scripts/watch.sh --dir ~/Downloads --events create --action '...' --daemon
bash scripts/watch.sh --dir /var/log --events create --action '...' --daemon

# List running watchers
bash scripts/watch.sh --status

# Stop all
bash scripts/watch.sh --stop-all
```

### Chaining Actions

```bash
# Multiple commands on trigger
bash scripts/watch.sh \
  --dir /data/uploads \
  --events close_write \
  --action '
    echo "Processing: $WATCH_FILE"
    # Validate
    file "$WATCH_FILE" | grep -q "image" || exit 0
    # Optimize
    convert "$WATCH_FILE" -resize "1920x1080>" -quality 85 "$WATCH_FILE"
    # Notify
    echo "Optimized: $WATCH_NAME" >> /var/log/image-processing.log
  '
```

## Built-in Actions

Pre-built action scripts in `scripts/actions/`:

### sort-by-extension.sh
Sorts files into directories by extension (PDFs → Documents, images → Pictures, etc.)

```bash
bash scripts/actions/sort-by-extension.sh "/path/to/file.pdf"
# → Moves to ~/Documents/PDFs/file.pdf
```

### notify-telegram.sh
Sends a Telegram notification about the file change.

```bash
export TELEGRAM_BOT_TOKEN="your-token"
export TELEGRAM_CHAT_ID="your-chat-id"
bash scripts/actions/notify-telegram.sh "$WATCH_FILE" "$WATCH_EVENT"
```

### backup-file.sh
Creates a timestamped backup copy.

```bash
bash scripts/actions/backup-file.sh "/path/to/file.conf"
# → Copies to /path/to/file.conf.2026-03-03_090000.bak
```

## Troubleshooting

### Issue: "inotifywait: command not found"

**Fix:**
```bash
sudo apt-get install -y inotify-tools  # Debian/Ubuntu
sudo dnf install -y inotify-tools      # Fedora/RHEL
```

### Issue: "Failed to watch: No space left on device"

**Cause:** Linux has a limit on inotify watches (default ~8192)

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

### Issue: Action fires multiple times for one change

**Fix:** Use `--debounce` to batch rapid events:
```bash
bash scripts/watch.sh --dir . --events modify --debounce 3 --action '...'
```

### Issue: Watching doesn't work on NFS/CIFS mounts

**Cause:** inotify doesn't work on network filesystems.

**Workaround:** Use polling fallback:
```bash
bash scripts/watch.sh --dir /mnt/share --poll 5 --action '...'
```

## Dependencies

- `bash` (4.0+)
- `inotify-tools` (provides `inotifywait`)
- Optional: `yq` (for YAML config parsing, falls back to simple parser)
- Optional: `curl` (for notification actions)

## Key Principles

1. **Event-driven** — No polling, zero CPU when idle (uses kernel inotify)
2. **Debounce** — Batches rapid events to avoid action spam
3. **Composable** — Pipe any shell command as an action
4. **Daemon-ready** — Run as background service with systemd
5. **Logged** — All events and actions logged with timestamps
