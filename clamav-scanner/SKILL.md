---
name: clamav-scanner
description: >-
  Install and manage ClamAV antivirus — scan files, schedule scans, auto-update virus definitions, quarantine threats.
categories: [security, automation]
dependencies: [clamav, clamav-daemon, clamav-freshclam]
---

# ClamAV Antivirus Scanner

## What This Does

Install, configure, and manage ClamAV antivirus on your server. Run on-demand scans, schedule recurring scans, auto-update virus definitions, quarantine infected files, and get alerts when threats are found. Essential for any server handling uploads, emails, or shared files.

**Example:** "Scan /var/www uploads directory every 6 hours, quarantine infected files, alert me on Telegram."

## Quick Start (5 minutes)

### 1. Install ClamAV

```bash
bash scripts/install.sh
```

This installs ClamAV, starts the freshclam daemon (auto-updates virus definitions), and verifies everything works.

### 2. Run Your First Scan

```bash
bash scripts/scan.sh --path /home
```

Output:
```
[2026-02-26 12:00:00] 🔍 Scanning /home ...
[2026-02-26 12:00:15] ✅ Scan complete — 1,247 files scanned, 0 threats found
```

### 3. Enable Scheduled Scans

```bash
bash scripts/schedule.sh --path /var/www --interval 6h --alert telegram
```

## Core Workflows

### Workflow 1: Scan a Directory

```bash
bash scripts/scan.sh --path /var/www/uploads
```

Output:
```
[2026-02-26 12:00:00] 🔍 Scanning /var/www/uploads ...
[2026-02-26 12:00:08] ⚠️  THREAT: /var/www/uploads/invoice.pdf.exe — Win.Trojan.Agent-123456
[2026-02-26 12:00:08] 📦 Quarantined → /var/clamav/quarantine/invoice.pdf.exe
[2026-02-26 12:00:10] ✅ Scan complete — 342 files scanned, 1 threat found
```

### Workflow 2: Scan with Quarantine

```bash
bash scripts/scan.sh --path /tmp --quarantine
```

Infected files are moved to `/var/clamav/quarantine/` with original path preserved in metadata.

### Workflow 3: Scan and Alert via Telegram

```bash
export TELEGRAM_BOT_TOKEN="your-token"
export TELEGRAM_CHAT_ID="your-chat-id"

bash scripts/scan.sh --path /var/www --alert telegram
```

On threat detection:
```
🚨 ClamAV Alert
Host: myserver
Threat: Win.Trojan.Agent-123456
File: /var/www/uploads/invoice.pdf.exe
Action: Quarantined
```

### Workflow 4: Update Virus Definitions Manually

```bash
bash scripts/update-defs.sh
```

Output:
```
[2026-02-26 12:00:00] 📥 Updating virus definitions...
[2026-02-26 12:00:12] ✅ Updated — main.cvd: 2026-02-26, daily.cld: 2026-02-26
[2026-02-26 12:00:12] 📊 Total signatures: 8,721,456
```

### Workflow 5: Scheduled Recurring Scans

```bash
# Scan uploads every 6 hours
bash scripts/schedule.sh --path /var/www/uploads --interval 6h --quarantine --alert telegram

# Scan entire system daily at 3am
bash scripts/schedule.sh --path / --time "3:00" --exclude "/proc,/sys,/dev" --quarantine
```

### Workflow 6: Check Scan History

```bash
bash scripts/history.sh
```

Output:
```
Date                 Path              Files   Threats  Duration
2026-02-26 12:00    /var/www/uploads   342     1        8s
2026-02-26 06:00    /var/www/uploads   340     0        7s
2026-02-25 18:00    /home              1,247   0        15s
```

### Workflow 7: Manage Quarantine

```bash
# List quarantined files
bash scripts/quarantine.sh --list

# Restore a false positive
bash scripts/quarantine.sh --restore /var/clamav/quarantine/safe-file.txt

# Purge quarantine older than 30 days
bash scripts/quarantine.sh --purge 30
```

## Configuration

### Environment Variables

```bash
# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Custom quarantine directory (default: /var/clamav/quarantine)
export CLAMAV_QUARANTINE_DIR="/var/clamav/quarantine"

# Scan log location (default: /var/log/clamav/scan.log)
export CLAMAV_SCAN_LOG="/var/log/clamav/scan.log"
```

### Exclude Patterns

```bash
# Exclude directories from scan
bash scripts/scan.sh --path / --exclude "/proc,/sys,/dev,/run,/snap"

# Exclude file types
bash scripts/scan.sh --path /var/www --exclude-ext "jpg,png,gif,mp4"
```

## Advanced Usage

### Scan Uploaded Files in Real-Time

```bash
# Watch a directory for new files and scan them
bash scripts/watch.sh --path /var/www/uploads --quarantine --alert telegram
```

Uses `inotifywait` to monitor file creation events and scan immediately.

### Multi-Directory Config

Create `config.yaml`:
```yaml
scans:
  - path: /var/www/uploads
    interval: 6h
    quarantine: true
    alert: telegram
    exclude_ext: [jpg, png, gif]

  - path: /home
    interval: 24h
    quarantine: true
    exclude: [/home/user/.cache]

  - path: /tmp
    interval: 12h
    quarantine: true
```

Run: `bash scripts/scan.sh --config config.yaml`

### Integration with OpenClaw Cron

```bash
# Add to OpenClaw cron for agent-managed scanning
# The agent can then process results and take action
*/360 * * * * bash /path/to/scripts/scan.sh --path /var/www --quarantine --json >> /var/log/clamav/results.json
```

## Troubleshooting

### Issue: "freshclam: Can't connect to database server"

**Fix:**
```bash
sudo systemctl restart clamav-freshclam
# Wait 2-3 minutes for initial download
sudo freshclam
```

### Issue: Scan is very slow

**Fix:** Use `--exclude` to skip large/unnecessary directories:
```bash
bash scripts/scan.sh --path / --exclude "/proc,/sys,/dev,/run,/snap,/var/lib/docker"
```

### Issue: "LibClamAV Error: cli_loaddb(): No supported database files found"

**Fix:** Definitions haven't downloaded yet:
```bash
sudo freshclam
# Wait for download to complete (first run takes 2-5 minutes)
```

### Issue: High memory usage

ClamAV loads virus definitions into RAM (~1GB). For low-memory systems:
```bash
# Use clamscan instead of clamdscan (slower but less RAM)
bash scripts/scan.sh --path /var/www --no-daemon
```

## Dependencies

- `clamav` (antivirus engine)
- `clamav-daemon` (background scanning service)
- `clamav-freshclam` (auto-update definitions)
- `inotify-tools` (optional, for real-time file watching)
- `curl` (for Telegram alerts)
- `jq` (for JSON output)
