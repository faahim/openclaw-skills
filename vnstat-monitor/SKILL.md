---
name: vnstat-monitor
description: >-
  Monitor network bandwidth usage with vnstat — track daily, weekly, and monthly traffic per interface with alerts and reports.
categories: [automation, analytics]
dependencies: [vnstat, jq, bash]
---

# vnStat Network Monitor

## What This Does

Installs and configures vnstat to monitor network bandwidth usage across all interfaces. Tracks daily, weekly, and monthly traffic, generates formatted reports, and alerts when bandwidth exceeds configurable thresholds. Perfect for VPS users watching transfer limits, home servers, or anyone who needs to know where their bandwidth goes.

**Example:** "Show me this month's bandwidth usage" → instant report with RX/TX breakdown per interface.

## Quick Start (5 minutes)

### 1. Install vnstat

```bash
bash scripts/install.sh
```

This detects your OS (Debian/Ubuntu/RHEL/Fedora/Arch/Alpine) and installs vnstat, starts the daemon, and initializes monitoring on all detected interfaces.

### 2. Check Current Usage

```bash
bash scripts/report.sh
```

Sample output:
```
╔══════════════════════════════════════════════════════╗
║              Network Bandwidth Report               ║
╠══════════════════════════════════════════════════════╣
║ Interface: eth0                                      ║
║ Period: March 2026                                   ║
╠──────────────┬──────────┬──────────┬────────────────╣
║ Day          │ RX       │ TX       │ Total          ║
╠──────────────┼──────────┼──────────┼────────────────╣
║ 2026-03-01   │ 1.24 GiB │ 0.85 GiB │ 2.09 GiB      ║
║ 2026-03-02   │ 0.98 GiB │ 0.62 GiB │ 1.60 GiB      ║
║ 2026-03-03   │ 2.31 GiB │ 1.14 GiB │ 3.45 GiB      ║
║ 2026-03-04   │ 0.45 GiB │ 0.22 GiB │ 0.67 GiB      ║
╠──────────────┼──────────┼──────────┼────────────────╣
║ Month Total  │ 4.98 GiB │ 2.83 GiB │ 7.81 GiB      ║
║ Projected    │ 50.2 GiB │ 28.5 GiB │ 78.7 GiB      ║
╚══════════════╧══════════╧══════════╧════════════════╝
```

### 3. Set Up Bandwidth Alerts

```bash
# Alert if monthly usage exceeds 500 GiB
bash scripts/alert.sh --cap 500 --unit GiB --period monthly

# Alert at 80% and 95% thresholds
bash scripts/alert.sh --cap 1000 --unit GiB --warn-at 80 --crit-at 95
```

## Core Workflows

### Workflow 1: Daily Usage Summary

```bash
bash scripts/report.sh --period daily --interface eth0
```

Shows today's bandwidth with hourly breakdown.

### Workflow 2: Monthly Report (All Interfaces)

```bash
bash scripts/report.sh --period monthly --all
```

Shows monthly totals across all monitored interfaces.

### Workflow 3: Top Traffic Days

```bash
bash scripts/report.sh --top 10
```

Shows the 10 highest-traffic days in the database.

### Workflow 4: Bandwidth Cap Monitoring

```bash
# Check if approaching monthly cap
bash scripts/alert.sh --cap 1000 --unit GiB --check

# Output:
# ✅ Current usage: 234.5 GiB / 1000 GiB (23.5%)
# 📊 Projected end-of-month: 782 GiB (78.2%) — Within limits
```

### Workflow 5: JSON Export (for dashboards/automation)

```bash
bash scripts/report.sh --period monthly --format json
```

```json
{
  "interface": "eth0",
  "period": "2026-03",
  "rx_bytes": 5345678901,
  "tx_bytes": 3039012345,
  "total_bytes": 8384691246,
  "days": [
    {"date": "2026-03-01", "rx": 1331692032, "tx": 912261120, "total": 2243953152},
    ...
  ]
}
```

### Workflow 6: Compare Interfaces

```bash
bash scripts/report.sh --compare --period monthly
```

```
Interface Comparison — March 2026
──────────────────────────────────
eth0:   ████████████████████ 78.7 GiB (87%)
wlan0:  ███                  12.1 GiB (13%)
──────────────────────────────────
Total:                       90.8 GiB
```

### Workflow 7: Set Up Cron Alerting

```bash
# Install daily bandwidth check (runs at 8am)
bash scripts/alert.sh --install-cron --cap 1000 --unit GiB --time "0 8 * * *"
```

This creates a cron job that checks current usage against your cap and writes alerts to a log file.

## Configuration

### Environment Variables

```bash
# Default interface (auto-detected if not set)
export VNSTAT_INTERFACE="eth0"

# Alert log location
export VNSTAT_ALERT_LOG="$HOME/.vnstat-monitor/alerts.log"

# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<your-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"
```

### Config File

```bash
# ~/.vnstat-monitor/config.yaml
interfaces:
  - name: eth0
    cap: 1000       # GiB per month
    warn_pct: 80
    crit_pct: 95
  - name: wlan0
    cap: 0          # 0 = no cap (monitor only)

alerts:
  telegram: true
  log: true
  log_path: ~/.vnstat-monitor/alerts.log

report:
  default_period: monthly
  default_format: table    # table | json | csv
```

## Advanced Usage

### Export to CSV

```bash
bash scripts/report.sh --period monthly --format csv > bandwidth-march-2026.csv
```

### Historical Trends

```bash
# Last 12 months summary
bash scripts/report.sh --period yearly
```

### Rate Monitoring (Live)

```bash
# Show current transfer rate (updates every 2 seconds)
bash scripts/report.sh --live
```

Uses `vnstat -l` for live monitoring with formatted output.

### Database Management

```bash
# Show database info
bash scripts/report.sh --dbinfo

# Reset statistics for an interface
bash scripts/install.sh --reset eth0

# Add a new interface to monitor
bash scripts/install.sh --add wg0
```

## Troubleshooting

### Issue: "vnstat: command not found"

**Fix:** Run `bash scripts/install.sh` — it auto-detects your OS and installs vnstat.

### Issue: "No data available yet"

vnstat needs ~5 minutes of data collection after first install. Wait and try again.

```bash
# Check daemon status
systemctl status vnstatd 2>/dev/null || service vnstat status
```

### Issue: Interface not monitored

```bash
# List monitored interfaces
vnstat --iflist

# Add missing interface
bash scripts/install.sh --add <interface-name>
```

### Issue: Permission denied

vnstat daemon runs as root. For user access:
```bash
sudo usermod -aG vnstat $USER
```

## Dependencies

- `vnstat` (2.6+) — installed by `scripts/install.sh`
- `bash` (4.0+)
- `jq` — for JSON output
- `bc` — for calculations (usually pre-installed)
- Optional: `yq` for YAML config parsing (falls back to grep)
