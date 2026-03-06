---
name: folder-watcher
description: >-
  Monitor directories for file changes and trigger automated actions — move, copy, compress, notify, or run custom scripts.
categories: [automation, productivity]
dependencies: [inotify-tools, bash]
---

# Folder Watcher

## What This Does

Watches directories for file system events (create, modify, delete, move) and triggers automated actions instantly. Perfect for automating file workflows: auto-organize downloads, trigger builds on code changes, compress uploads, send notifications on new files, or run any custom script.

**Example:** "Watch ~/Downloads — when a new PDF arrives, move it to ~/Documents/PDFs and send a Telegram notification."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install inotify-tools
bash scripts/install.sh
```

### 2. Watch a Directory

```bash
# Watch ~/Downloads for new files, log events
bash scripts/watch.sh --dir ~/Downloads --events create --action log

# Output:
# [2026-03-06 12:00:01] CREATE ~/Downloads/report.pdf
# [2026-03-06 12:00:15] CREATE ~/Downloads/photo.jpg
```

### 3. Auto-Organize Files

```bash
# Move PDFs to Documents, images to Pictures
bash scripts/watch.sh --dir ~/Downloads --events create \
  --action organize --config config.yaml
```

## Core Workflows

### Workflow 1: Log File Changes

**Use case:** Audit what's happening in a directory

```bash
bash scripts/watch.sh \
  --dir /var/log \
  --events modify,create,delete \
  --action log \
  --logfile /tmp/file-changes.log
```

**Output:**
```
[2026-03-06 12:00:01] MODIFY /var/log/syslog
[2026-03-06 12:00:05] CREATE /var/log/app.log.1
[2026-03-06 12:00:10] DELETE /var/log/old.log
```

### Workflow 2: Auto-Organize Downloads

**Use case:** Sort files by extension as they arrive

```bash
bash scripts/watch.sh \
  --dir ~/Downloads \
  --events create,moved_to \
  --action organize \
  --config config.yaml
```

With config:
```yaml
organize:
  rules:
    - match: "*.pdf"
      dest: ~/Documents/PDFs
    - match: "*.{jpg,png,gif,webp}"
      dest: ~/Pictures/Downloads
    - match: "*.{mp4,mkv,avi}"
      dest: ~/Videos
    - match: "*.{zip,tar.gz,7z}"
      dest: ~/Archives
```

### Workflow 3: Trigger Script on Changes

**Use case:** Rebuild project when source files change

```bash
bash scripts/watch.sh \
  --dir ./src \
  --events modify,create,delete \
  --action script \
  --script "make build" \
  --debounce 2
```

### Workflow 4: Compress New Files

**Use case:** Auto-gzip large files in an upload directory

```bash
bash scripts/watch.sh \
  --dir /uploads \
  --events create \
  --action compress \
  --min-size 10M
```

### Workflow 5: Send Notifications

**Use case:** Alert when files are added to a watched folder

```bash
# Telegram notification
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

bash scripts/watch.sh \
  --dir /important/reports \
  --events create \
  --action notify \
  --notify telegram
```

### Workflow 6: Sync to Backup

**Use case:** Copy changed files to a backup directory

```bash
bash scripts/watch.sh \
  --dir ~/projects \
  --events modify,create \
  --action copy \
  --dest /backup/projects \
  --recursive
```

## Configuration

### Config File Format (YAML)

```yaml
# config.yaml
watchers:
  - name: "downloads-organizer"
    dir: ~/Downloads
    recursive: false
    events: [create, moved_to]
    exclude: ["*.part", "*.tmp", "*.crdownload"]
    action: organize
    organize:
      rules:
        - match: "*.pdf"
          dest: ~/Documents/PDFs
        - match: "*.{jpg,png,gif}"
          dest: ~/Pictures

  - name: "project-builder"
    dir: ~/myproject/src
    recursive: true
    events: [modify, create, delete]
    exclude: ["node_modules", ".git", "*.swp"]
    action: script
    script: "cd ~/myproject && npm run build"
    debounce: 3

  - name: "upload-compressor"
    dir: /uploads
    recursive: false
    events: [create]
    action: compress
    min_size: "5M"
    notify: telegram
```

### Run with Config

```bash
bash scripts/watch.sh --config config.yaml
```

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Email alerts (optional)
export SMTP_HOST="smtp.gmail.com"
export SMTP_USER="<email>"
export SMTP_PASS="<password>"
export NOTIFY_EMAIL="<recipient>"
```

## Advanced Usage

### Run as systemd Service

```bash
# Install as service
bash scripts/install-service.sh --config /path/to/config.yaml

# Manage
sudo systemctl start folder-watcher
sudo systemctl enable folder-watcher
sudo systemctl status folder-watcher
```

### Exclude Patterns

```bash
bash scripts/watch.sh \
  --dir ~/projects \
  --events modify \
  --exclude "node_modules|.git|__pycache__|*.pyc" \
  --action log
```

### Debounce Rapid Changes

```bash
# Wait 2 seconds after last event before triggering action
bash scripts/watch.sh \
  --dir ./src \
  --events modify \
  --action script \
  --script "make build" \
  --debounce 2
```

### Run as Cron-Managed Daemon

```bash
# Add to crontab — restart watcher if it dies
*/5 * * * * pgrep -f "watch.sh.*config.yaml" || bash /path/to/scripts/watch.sh --config /path/to/config.yaml &
```

## Troubleshooting

### Issue: "inotifywait: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
sudo apt-get install -y inotify-tools   # Debian/Ubuntu
sudo yum install -y inotify-tools       # RHEL/CentOS
brew install fswatch                     # macOS (uses fswatch instead)
```

### Issue: "max user watches" limit reached

**Fix:**
```bash
# Check current limit
cat /proc/sys/fs/inotify/max_user_watches

# Increase it
echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Issue: Events firing too rapidly

**Fix:** Use `--debounce` flag to batch rapid changes:
```bash
bash scripts/watch.sh --dir ./src --debounce 3 --action script --script "make build"
```

### Issue: Permission denied on watched directory

**Fix:** Ensure read permission on the directory:
```bash
chmod +r /path/to/dir
# Or run with sudo for system directories
```

## Dependencies

- `bash` (4.0+)
- `inotify-tools` (Linux) or `fswatch` (macOS)
- `gzip` (for compress action)
- Optional: `curl` (for Telegram/webhook notifications)
