---
name: sysmon
description: >-
  Monitor system resources (CPU, RAM, disk, processes) and get instant alerts when thresholds are exceeded.
categories: [automation, dev-tools]
dependencies: [bash, curl, awk, free, df, top]
---

# System Resource Monitor (sysmon)

## What This Does

Monitors your server's CPU, RAM, disk usage, and top processes in real-time. Sends alerts via Telegram, webhook, or email when configurable thresholds are exceeded. Runs as a lightweight cron job — no heavy monitoring stack required.

**Example:** "Alert me on Telegram if CPU > 80%, RAM > 90%, or disk > 85%. Check every 5 minutes."

## Quick Start (3 minutes)

### 1. Install

```bash
# Clone or copy scripts to your server
SKILL_DIR="$HOME/.openclaw/skills/sysmon"
mkdir -p "$SKILL_DIR"
cp -r scripts/* "$SKILL_DIR/"
chmod +x "$SKILL_DIR"/*.sh
```

### 2. Configure Alerts (Optional)

```bash
# For Telegram alerts
export SYSMON_TELEGRAM_BOT_TOKEN="your-bot-token"
export SYSMON_TELEGRAM_CHAT_ID="your-chat-id"

# Add to ~/.bashrc or ~/.openclaw/.env for persistence
```

### 3. Run First Check

```bash
bash scripts/sysmon.sh

# Output:
# ═══════════════════════════════════════
# 🖥  System Resource Report — 2026-02-22 02:53 UTC
# ═══════════════════════════════════════
# CPU Usage:    23.4%  ✅
# RAM Usage:    67.2%  (2.1G / 3.8G)  ✅
# Swap Usage:   12.0%  (0.5G / 4.0G)  ✅
# Disk / :      54.3%  (27G / 50G)  ✅
# Load Avg:     0.82 / 0.65 / 0.59
# Uptime:       14 days, 7:23
# ═══════════════════════════════════════
# Top 5 Processes by CPU:
#   PID   CPU%  MEM%  COMMAND
#   1234  12.3   4.5  node
#   5678   8.1   2.3  python3
# ═══════════════════════════════════════
```

## Core Workflows

### Workflow 1: One-Shot System Check

```bash
bash scripts/sysmon.sh
```

Returns a formatted report of all system resources. No alerts, just information.

### Workflow 2: Alert on Thresholds

```bash
bash scripts/sysmon.sh \
  --cpu-warn 80 \
  --ram-warn 90 \
  --disk-warn 85 \
  --alert telegram
```

If any threshold is exceeded:
```
🚨 SYSMON ALERT — myserver
CPU Usage: 92.3% ⚠️  (threshold: 80%)
RAM Usage: 67.2% ✅
Disk / :  54.3% ✅
Top CPU consumers:
  PID 1234 (node) — 45.2% CPU
  PID 5678 (python3) — 31.1% CPU
```

### Workflow 3: Run as Cron Job

```bash
# Check every 5 minutes, alert on high usage
bash scripts/install-cron.sh --interval 5 --cpu-warn 80 --ram-warn 90 --disk-warn 85

# Or manually add to crontab:
# */5 * * * * bash /path/to/sysmon.sh --cpu-warn 80 --ram-warn 90 --disk-warn 85 --alert telegram --quiet
```

### Workflow 4: JSON Output (for Pipelines)

```bash
bash scripts/sysmon.sh --json

# Output:
# {"cpu":23.4,"ram":67.2,"ram_used":"2.1G","ram_total":"3.8G","swap":12.0,
#  "disk_percent":54.3,"disk_used":"27G","disk_total":"50G",
#  "load_1":0.82,"load_5":0.65,"load_15":0.59,
#  "uptime":"14 days","top_processes":[...]}
```

### Workflow 5: Monitor Specific Disk Paths

```bash
bash scripts/sysmon.sh --disk / --disk /home --disk /var --disk-warn 85
```

### Workflow 6: Watch Mode (Live Dashboard)

```bash
bash scripts/sysmon.sh --watch --interval 10

# Refreshes every 10 seconds with live stats
```

## Configuration

### Environment Variables

```bash
# Telegram alerts
export SYSMON_TELEGRAM_BOT_TOKEN="<token>"
export SYSMON_TELEGRAM_CHAT_ID="<chat-id>"

# Webhook alerts (Slack, Discord, custom)
export SYSMON_WEBHOOK_URL="https://hooks.slack.com/services/..."

# Email alerts (via system mail or SMTP)
export SYSMON_EMAIL_TO="admin@example.com"

# Default thresholds (override with CLI flags)
export SYSMON_CPU_WARN=80
export SYSMON_RAM_WARN=90
export SYSMON_DISK_WARN=85
export SYSMON_SWAP_WARN=80

# Alert cooldown — don't re-alert for same issue within N minutes
export SYSMON_COOLDOWN=30

# Hostname label for alerts
export SYSMON_HOSTNAME="my-server"
```

### CLI Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--cpu-warn N` | 80 | CPU % threshold |
| `--ram-warn N` | 90 | RAM % threshold |
| `--disk-warn N` | 85 | Disk % threshold |
| `--swap-warn N` | 80 | Swap % threshold |
| `--disk PATH` | `/` | Disk path to monitor (repeatable) |
| `--alert TYPE` | none | Alert method: telegram, webhook, email |
| `--json` | off | Output JSON instead of formatted text |
| `--quiet` | off | Only output on alerts (for cron) |
| `--watch` | off | Continuous monitoring mode |
| `--interval N` | 60 | Seconds between checks (watch mode) |
| `--top N` | 5 | Number of top processes to show |

## Troubleshooting

### "free: command not found"

```bash
# Install procps (contains free, top, ps)
sudo apt-get install -y procps  # Debian/Ubuntu
sudo yum install -y procps-ng   # CentOS/RHEL
```

### Telegram alerts not arriving

1. Verify token: `curl -s "https://api.telegram.org/bot$SYSMON_TELEGRAM_BOT_TOKEN/getMe"`
2. Verify chat ID: `curl -s "https://api.telegram.org/bot$SYSMON_TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$SYSMON_TELEGRAM_CHAT_ID&text=test"`
3. Ensure bot is added to chat/group

### CPU always shows 0% on single check

CPU usage is sampled over 1 second. If running in cron with `--quiet`, this is normal — it captures a snapshot. Use `--watch` for continuous monitoring.

## Dependencies

- `bash` (4.0+)
- `awk` (text processing)
- `free` (RAM/swap stats — part of procps)
- `df` (disk stats)
- `top` / `ps` (process stats)
- `curl` (for Telegram/webhook alerts)
- Optional: `mail` / `sendmail` (for email alerts)

All dependencies are pre-installed on most Linux distributions.
