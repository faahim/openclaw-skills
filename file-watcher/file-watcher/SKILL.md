---
name: file-watcher
description: >-
  Watch files and directories for changes — trigger custom actions automatically on create, modify, delete, or move events.
categories: [automation, dev-tools]
dependencies: [inotify-tools, bash]
---

# File Watcher

## What This Does

Monitors files and directories for real-time changes using Linux's inotify kernel subsystem. When a file is created, modified, deleted, or moved, it triggers your custom action — rebuild a project, sync files, send a notification, restart a service, anything.

**Example:** "Watch `./src/` — on any `.ts` file change, run `npm run build` automatically."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. Watch a Directory

```bash
# Watch current directory, print events
bash scripts/watch.sh --path ./src --events modify,create,delete

# Output:
# [2026-03-06 21:00:00] MODIFY ./src/index.ts
# [2026-03-06 21:00:05] CREATE ./src/utils.ts
```

### 3. Trigger Actions on Changes

```bash
# Rebuild on file changes
bash scripts/watch.sh --path ./src --events modify,create --run "npm run build"

# Restart service on config change
bash scripts/watch.sh --path /etc/myapp/config.yaml --events modify --run "systemctl restart myapp"

# Sync on new files
bash scripts/watch.sh --path ./uploads --events create --run "rsync -av ./uploads/ remote:/backups/"
```

## Core Workflows

### Workflow 1: Auto-Build on Code Changes

**Use case:** Rebuild project when source files change

```bash
bash scripts/watch.sh \
  --path ./src \
  --filter '\.tsx?$|\.css$' \
  --events modify,create,delete \
  --run "npm run build" \
  --debounce 2
```

The `--debounce 2` waits 2 seconds after last change before running, preventing rapid re-triggers during batch saves.

### Workflow 2: Auto-Deploy on Build Output

**Use case:** Deploy when build artifacts change

```bash
bash scripts/watch.sh \
  --path ./dist \
  --events modify,create \
  --run "rsync -avz ./dist/ user@server:/var/www/html/" \
  --debounce 5
```

### Workflow 3: Log File Monitor with Alerts

**Use case:** Alert when error patterns appear in logs

```bash
bash scripts/watch.sh \
  --path /var/log/myapp.log \
  --events modify \
  --run 'tail -1 /var/log/myapp.log | grep -q "ERROR" && curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Error+detected+in+myapp"'
```

### Workflow 4: Auto-Backup on Config Changes

**Use case:** Backup config files whenever they're modified

```bash
bash scripts/watch.sh \
  --path /etc/nginx \
  --recursive \
  --events modify \
  --run 'STAMP=$(date +%Y%m%d_%H%M%S); tar czf /backups/nginx_$STAMP.tar.gz /etc/nginx/'
```

### Workflow 5: Watch Multiple Paths with Config

**Use case:** Complex multi-path watching

```bash
bash scripts/watch.sh --config config.yaml
```

## Configuration

### Config File Format (YAML)

```yaml
# config.yaml
watchers:
  - name: "source-rebuild"
    path: ./src
    recursive: true
    events: [modify, create, delete]
    filter: '\.(ts|tsx|js|jsx|css)$'
    exclude: 'node_modules|\.git|dist'
    debounce: 2
    run: "npm run build"

  - name: "config-restart"
    path: /etc/myapp
    recursive: false
    events: [modify]
    filter: '\.yaml$|\.json$'
    debounce: 1
    run: "systemctl restart myapp"

  - name: "upload-sync"
    path: ./uploads
    recursive: true
    events: [create, moved_to]
    run: "rsync -av ./uploads/ backup:/data/uploads/"
    debounce: 5

  - name: "log-alert"
    path: /var/log/app.log
    events: [modify]
    run: 'tail -1 "$WATCH_FILE" | grep -qE "(ERROR|FATAL)" && echo "Alert: error in $WATCH_FILE" | mail -s "App Error" admin@example.com'
```

### Environment Variables Available in Actions

When your `--run` command executes, these environment variables are set:

```bash
$WATCH_FILE    # Full path of the changed file
$WATCH_EVENT   # Event type (MODIFY, CREATE, DELETE, MOVED_TO, etc.)
$WATCH_DIR     # Directory being watched
$WATCH_NAME    # Filename only (no path)
```

### Command-Line Options

```
--path PATH        Directory or file to watch (required unless --config)
--config FILE      YAML config file for multi-watcher setup
--events EVENTS    Comma-separated: modify,create,delete,move,access,attrib
--filter REGEX     Only trigger on filenames matching regex
--exclude REGEX    Ignore filenames matching regex
--recursive        Watch subdirectories too
--run COMMAND      Command to execute on event
--debounce SECS    Wait N seconds after last event before triggering (default: 0)
--log FILE         Log events to file
--daemon           Run in background (creates PID file)
--quiet            Suppress event output (still runs actions)
```

## Advanced Usage

### Run as Systemd Service

```bash
# Generate systemd unit file
bash scripts/watch.sh --config /etc/file-watcher/config.yaml --generate-service > /etc/systemd/system/file-watcher.service

# Enable and start
sudo systemctl enable --now file-watcher
```

### Run as Background Daemon

```bash
bash scripts/watch.sh --path ./src --run "make build" --daemon

# Check status
cat /tmp/file-watcher-*.pid

# Stop
bash scripts/watch.sh --stop
```

### Chaining Multiple Actions

```bash
bash scripts/watch.sh \
  --path ./src \
  --events modify \
  --run 'npm run build && npm run test && echo "All good" || echo "Build failed"'
```

### Using with OpenClaw Cron

```bash
# Start watcher on boot via cron
@reboot /path/to/scripts/watch.sh --config /path/to/config.yaml --daemon --log /var/log/file-watcher.log
```

## Troubleshooting

### Issue: "inotifywait: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: sudo apt-get install -y inotify-tools
# RHEL/CentOS: sudo yum install -y inotify-tools
# Arch: sudo pacman -S inotify-tools
# Alpine: sudo apk add inotify-tools
```

### Issue: "Failed to watch; upper limit on inotify watches reached"

**Fix:** Increase inotify watch limit
```bash
echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Issue: Events fire too rapidly / action runs multiple times

**Fix:** Use `--debounce` to batch rapid events
```bash
bash scripts/watch.sh --path ./src --run "make" --debounce 3
```

### Issue: Watching doesn't work on NFS/CIFS mounts

**Explanation:** inotify only works on local filesystems. For network mounts, use polling mode:
```bash
bash scripts/watch.sh --path /mnt/nfs/share --poll 5  # Check every 5 seconds
```

## Dependencies

- `bash` (4.0+)
- `inotify-tools` (inotifywait)
- Optional: `yq` (for YAML config parsing — falls back to grep-based parser)
