---
name: bandwidth-monitor
description: >-
  Monitor network bandwidth usage, track data consumption over time, and alert when thresholds are exceeded.
categories: [automation, analytics]
dependencies: [vnstat, bash, awk]
---

# Bandwidth Monitor

## What This Does

Track network bandwidth usage in real-time and historically. Monitor daily/weekly/monthly data consumption, set alerts when you're approaching limits, and generate usage reports. Essential for servers with bandwidth caps, metered connections, or just keeping tabs on network activity.

**Example:** "Alert me when daily bandwidth exceeds 50GB, show monthly usage trends per interface."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

This installs `vnstat` (lightweight network traffic monitor) and starts the daemon. vnstat runs in the background using minimal resources (~0.1% CPU, <5MB RAM).

### 2. Check Current Bandwidth

```bash
bash scripts/run.sh --status
```

**Output:**
```
═══════════════════════════════════════════
  Bandwidth Monitor — Interface: eth0
═══════════════════════════════════════════
  Today:     ↓ 2.45 GiB  ↑ 890 MiB  (3.32 GiB total)
  This Week: ↓ 18.7 GiB  ↑ 5.21 GiB (23.9 GiB total)
  This Month:↓ 67.3 GiB  ↑ 22.1 GiB (89.4 GiB total)
  Right Now:  ↓ 12.4 Mbit/s  ↑ 3.2 Mbit/s
═══════════════════════════════════════════
```

### 3. Set Up Threshold Alerts

```bash
# Alert when daily usage exceeds 50GB
bash scripts/run.sh --alert-daily 50G

# Alert when monthly usage exceeds 1TB
bash scripts/run.sh --alert-monthly 1T
```

## Core Workflows

### Workflow 1: Real-Time Bandwidth Check

**Use case:** See what's happening on the network right now.

```bash
bash scripts/run.sh --live
```

**Output:**
```
[2026-02-24 15:30:00] eth0 — ↓ 45.2 Mbit/s  ↑ 8.7 Mbit/s
[2026-02-24 15:30:05] eth0 — ↓ 38.1 Mbit/s  ↑ 9.2 Mbit/s
[2026-02-24 15:30:10] eth0 — ↓ 52.8 Mbit/s  ↑ 7.4 Mbit/s
```

### Workflow 2: Daily/Monthly Reports

**Use case:** Generate a usage report for billing or capacity planning.

```bash
# Daily breakdown for current month
bash scripts/run.sh --report daily

# Monthly summary for the year
bash scripts/run.sh --report monthly

# Export to JSON
bash scripts/run.sh --report monthly --json > bandwidth-report.json
```

**Output (daily):**
```
Date          ↓ Received    ↑ Sent       Total
─────────────────────────────────────────────────
2026-02-01    4.21 GiB     1.32 GiB     5.53 GiB
2026-02-02    3.87 GiB     1.18 GiB     5.05 GiB
2026-02-03    6.42 GiB     2.01 GiB     8.43 GiB
...
─────────────────────────────────────────────────
Total:        67.3 GiB     22.1 GiB     89.4 GiB
Daily Avg:    2.92 GiB     0.96 GiB     3.88 GiB
```

### Workflow 3: Threshold Alerts via Telegram

**Use case:** Get notified when bandwidth usage is high.

```bash
# Configure Telegram alerts
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

# Check and alert (run via cron)
bash scripts/run.sh --check-thresholds
```

**Alert message:**
```
🚨 Bandwidth Alert — eth0
Daily usage: 52.3 GiB (threshold: 50 GiB)
Monthly so far: 412 GiB / 1 TiB (41.2%)
```

### Workflow 4: Top Bandwidth Consumers (per-process)

**Use case:** Find which process is using the most bandwidth.

```bash
bash scripts/run.sh --top-processes
```

**Output:**
```
PID     Process         ↓ Rate      ↑ Rate      Total
────────────────────────────────────────────────────
4521    docker-proxy    28.3 Mb/s   4.1 Mb/s    32.4 Mb/s
1823    nginx           12.1 Mb/s   18.7 Mb/s   30.8 Mb/s
9012    sshd            0.2 Mb/s    0.1 Mb/s    0.3 Mb/s
```

*Note: Requires `nethogs` (installed by install.sh).*

### Workflow 5: Multi-Interface Monitoring

**Use case:** Monitor multiple network interfaces (eth0, wlan0, docker0, etc.)

```bash
# List all interfaces with traffic
bash scripts/run.sh --interfaces

# Monitor specific interface
bash scripts/run.sh --status --iface wlan0

# Compare all interfaces
bash scripts/run.sh --compare
```

## Configuration

### Config File

```bash
# Create config
cp scripts/config-template.yaml ~/.config/bandwidth-monitor/config.yaml
```

```yaml
# ~/.config/bandwidth-monitor/config.yaml
interface: eth0          # Primary interface (auto-detect if empty)
poll_interval: 5         # Seconds between live samples

thresholds:
  daily: 50G             # Alert if daily exceeds 50 GiB
  weekly: 300G           # Alert if weekly exceeds 300 GiB
  monthly: 1T            # Alert if monthly exceeds 1 TiB
  rate: 100M             # Alert if sustained rate exceeds 100 Mbit/s

alerts:
  telegram:
    enabled: true
    bot_token: "${TELEGRAM_BOT_TOKEN}"
    chat_id: "${TELEGRAM_CHAT_ID}"
  webhook:
    enabled: false
    url: "https://hooks.slack.com/..."

report:
  format: table          # table or json
  retention_months: 12   # Keep data for 12 months
```

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Override interface
export BW_INTERFACE="eth0"

# Override config path
export BW_CONFIG="$HOME/.config/bandwidth-monitor/config.yaml"
```

## Cron Setup

```bash
# Check thresholds every 15 minutes
*/15 * * * * bash /path/to/scripts/run.sh --check-thresholds >> /var/log/bandwidth-monitor.log 2>&1

# Daily report at midnight
0 0 * * * bash /path/to/scripts/run.sh --report daily --json >> /var/log/bandwidth-daily.json

# Monthly report on 1st of month
0 0 1 * * bash /path/to/scripts/run.sh --report monthly --json >> /var/log/bandwidth-monthly.json
```

## Troubleshooting

### Issue: "vnstat: command not found"

```bash
bash scripts/install.sh
# Or manually: sudo apt install vnstat && sudo systemctl enable --now vnstat
```

### Issue: No data yet

vnstat needs time to collect data. On first install, wait 5+ minutes for initial stats.

```bash
vnstat --oneline  # Check if data collection started
```

### Issue: Wrong interface detected

```bash
# List interfaces
ip link show | grep "^[0-9]" | awk -F: '{print $2}'

# Set correct interface
bash scripts/run.sh --status --iface ens5
```

### Issue: Permission denied for per-process monitoring

```bash
# nethogs needs root for packet capture
sudo bash scripts/run.sh --top-processes
```

## Dependencies

- `vnstat` (2.6+) — network traffic monitor daemon (installed by install.sh)
- `nethogs` (optional) — per-process bandwidth (installed by install.sh)
- `bash` (4.0+)
- `awk`, `curl`, `jq` — standard utilities
- `cron` (optional) — for scheduled threshold checks
