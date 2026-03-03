---
name: vnstat-traffic
description: >-
  Monitor network bandwidth usage with vnstat — track daily, monthly, and per-interface traffic with alerts and reports.
categories: [automation, analytics]
dependencies: [vnstat, jq, bash]
---

# Network Traffic Monitor (vnstat)

## What This Does

Track network bandwidth usage across all interfaces — daily, weekly, monthly, and real-time. Get alerts when you're approaching data caps, generate usage reports, and identify bandwidth hogs. Uses vnstat for lightweight, always-on traffic accounting with zero performance impact.

**Example:** "Monitor eth0, alert me via Telegram when monthly usage exceeds 500GB, generate a weekly bandwidth report."

## Quick Start (5 minutes)

### 1. Install vnstat

```bash
bash scripts/install.sh
```

This installs vnstat, starts the daemon, and initializes monitoring on all detected interfaces.

### 2. Check Current Usage

```bash
bash scripts/traffic.sh status
```

**Output:**
```
╔══════════════════════════════════════════════════════════╗
║  Network Traffic Monitor — vnstat                       ║
╠══════════════════════════════════════════════════════════╣
║  Interface: eth0                                        ║
║  Today:     ↓ 2.45 GiB  ↑ 890 MiB  = 3.32 GiB         ║
║  This Month: ↓ 68.2 GiB  ↑ 23.1 GiB = 91.3 GiB        ║
║  All Time:  ↓ 1.24 TiB  ↑ 456 GiB  = 1.68 TiB         ║
╚══════════════════════════════════════════════════════════╝
```

### 3. Set Up Alerts

```bash
# Alert when monthly traffic exceeds 500 GiB
bash scripts/traffic.sh alert --interface eth0 --monthly-limit 500 --unit GiB --notify telegram

# Alert when daily traffic exceeds 20 GiB
bash scripts/traffic.sh alert --interface eth0 --daily-limit 20 --unit GiB --notify telegram
```

## Core Workflows

### Workflow 1: Daily Usage Report

**Use case:** Get a summary of today's bandwidth usage.

```bash
bash scripts/traffic.sh daily
```

**Output:**
```
Daily Traffic Report — 2026-03-03
═══════════════════════════════════
Interface: eth0
  00:00-06:00  ↓ 450 MiB  ↑ 120 MiB
  06:00-12:00  ↓ 1.2 GiB  ↑ 340 MiB
  12:00-18:00  ↓ 890 MiB  ↑ 210 MiB
  18:00-now    ↓ 560 MiB  ↑ 180 MiB
  ─────────────────────────────────
  Total:       ↓ 3.08 GiB ↑ 850 MiB = 3.91 GiB
```

### Workflow 2: Monthly Summary

**Use case:** Check monthly bandwidth against your data cap.

```bash
bash scripts/traffic.sh monthly
```

**Output:**
```
Monthly Traffic — March 2026
═══════════════════════════════
Day  1: ↓ 4.2 GiB  ↑ 1.1 GiB = 5.3 GiB
Day  2: ↓ 3.8 GiB  ↑ 980 MiB = 4.7 GiB
Day  3: ↓ 2.1 GiB  ↑ 650 MiB = 2.7 GiB (today, partial)
─────────────────────────────────
Total:  ↓ 10.1 GiB ↑ 2.7 GiB = 12.8 GiB
Projected: ~128 GiB this month
Data cap: 500 GiB (2.6% used)
```

### Workflow 3: Real-Time Monitor

**Use case:** Watch live traffic rates.

```bash
bash scripts/traffic.sh live --interface eth0
```

**Output (updates every 2s):**
```
Live Traffic — eth0 [Ctrl+C to stop]
  ↓ 12.4 Mbit/s  ↑ 3.2 Mbit/s  Total: 15.6 Mbit/s
```

### Workflow 4: Top Talkers by Interface

**Use case:** See which interface uses the most bandwidth.

```bash
bash scripts/traffic.sh top
```

**Output:**
```
Interface Ranking (This Month)
══════════════════════════════
1. eth0     91.3 GiB  (87.2%)
2. docker0  12.4 GiB  (11.9%)
3. wg0       980 MiB   (0.9%)
```

### Workflow 5: JSON Export for Automation

**Use case:** Pipe traffic data into other tools.

```bash
bash scripts/traffic.sh export --format json --period monthly
```

**Output:**
```json
{
  "interface": "eth0",
  "period": "2026-03",
  "rx_bytes": 10845741056,
  "tx_bytes": 2899102720,
  "total_bytes": 13744843776,
  "days": [
    {"date": "2026-03-01", "rx": 4509715456, "tx": 1181116006},
    {"date": "2026-03-02", "rx": 4080218931, "tx": 1027604889}
  ]
}
```

## Configuration

### Data Cap Alerts

```bash
# Edit config
cp scripts/config-template.yaml ~/.config/vnstat-traffic/config.yaml
```

```yaml
# ~/.config/vnstat-traffic/config.yaml
interfaces:
  - name: eth0
    data_cap:
      monthly: 500    # GiB
      daily: 25       # GiB
    alerts:
      - type: telegram
        bot_token: "${TELEGRAM_BOT_TOKEN}"
        chat_id: "${TELEGRAM_CHAT_ID}"
      - type: webhook
        url: "https://hooks.slack.com/..."
    thresholds:
      - percent: 80
        message: "⚠️ 80% of monthly data cap used"
      - percent: 95
        message: "🚨 95% of monthly data cap — throttling imminent!"

  - name: wg0
    data_cap:
      monthly: 100
    alerts:
      - type: telegram
        bot_token: "${TELEGRAM_BOT_TOKEN}"
        chat_id: "${TELEGRAM_CHAT_ID}"

schedule:
  daily_report: "08:00"     # Send daily summary at 8 AM
  monthly_report: "1st"     # Send monthly summary on 1st of month
  check_interval: 3600      # Check caps every hour (seconds)
```

### Environment Variables

```bash
# For Telegram alerts
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"
```

## Advanced Usage

### Run as Cron Job (Hourly Cap Check)

```bash
# Check data caps every hour
bash scripts/traffic.sh setup-cron

# Or manually add to crontab:
# 0 * * * * bash /path/to/scripts/traffic.sh check-caps >> /var/log/vnstat-traffic.log 2>&1
```

### Historical Comparison

```bash
# Compare this month vs last month
bash scripts/traffic.sh compare --months 2

# Output:
# Feb 2026: 245.6 GiB total (↓189.2 ↑56.4)
# Mar 2026: 12.8 GiB so far (projected: 128 GiB) — 47.8% decrease projected
```

### Per-Day Heatmap (Last 30 Days)

```bash
bash scripts/traffic.sh heatmap
```

**Output:**
```
Daily Traffic Heatmap (last 30 days)
Each █ = 5 GiB
Feb 02 ████░░░░░░ 18.2 GiB
Feb 03 ██████░░░░ 28.5 GiB
Feb 04 ███░░░░░░░ 14.1 GiB
...
Mar 03 ██░░░░░░░░  9.8 GiB (today)
```

### Reset Interface Stats

```bash
# Reset a specific interface
bash scripts/traffic.sh reset --interface eth0

# Reset all interfaces
bash scripts/traffic.sh reset --all
```

## Troubleshooting

### Issue: "vnstat: command not found"

**Fix:**
```bash
# Run the installer
bash scripts/install.sh

# Or install manually:
# Ubuntu/Debian
sudo apt-get install -y vnstat

# RHEL/CentOS/Fedora
sudo dnf install -y vnstat

# Arch
sudo pacman -S vnstat
```

### Issue: "Error: no data available yet"

**Fix:** vnstat needs time to collect data. Wait 5 minutes after install, or check daemon status:
```bash
systemctl status vnstatd
# or
vnstatd --nodaemon  # Run in foreground for debugging
```

### Issue: Interface not detected

**Fix:**
```bash
# List all interfaces
ip link show

# Add interface manually
sudo vnstat --add -i <interface-name>
```

### Issue: Telegram alerts not sending

**Check:**
1. Bot token is valid: `echo $TELEGRAM_BOT_TOKEN`
2. Chat ID is correct: Test with `curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Test"`
3. Bot has access to the chat

## Dependencies

- `vnstat` (2.6+) — Network traffic accounting daemon
- `bash` (4.0+)
- `jq` — JSON parsing
- `bc` — Math calculations
- Optional: `cron` for scheduled checks
- Optional: `curl` for Telegram/webhook alerts
