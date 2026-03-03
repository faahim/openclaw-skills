# Listing Copy: Network Traffic Monitor

## Metadata
- **Type:** Skill
- **Name:** vnstat-traffic
- **Display Name:** Network Traffic Monitor
- **Categories:** [automation, analytics]
- **Price:** $8
- **Dependencies:** [vnstat, jq, bash, bc]

## Tagline

Monitor network bandwidth usage — Track daily & monthly traffic with data cap alerts

## Description

Running a VPS, home server, or any Linux machine with bandwidth limits? Manually checking traffic stats is tedious, and by the time you notice you've blown through your data cap, the overage charges have already hit.

Network Traffic Monitor uses vnstat to give you lightweight, always-on bandwidth accounting with zero performance impact. Track download/upload per interface, get daily and monthly breakdowns, set data cap alerts via Telegram, and export usage data as JSON for automation.

**What it does:**
- 📊 Real-time and historical bandwidth tracking per interface
- ⏱️ Daily, monthly, and all-time usage breakdowns
- 🚨 Data cap alerts at configurable thresholds (80%, 95%)
- 📈 30-day traffic heatmaps and monthly comparisons
- 📤 JSON export for dashboards and automation pipelines
- 🔔 Telegram and webhook notifications
- ⚡ One-command install, 5-minute setup
- 🪶 Near-zero CPU/memory overhead (vnstat kernel accounting)

Perfect for VPS admins, homelabbers, and anyone who needs to track bandwidth without running heavy monitoring stacks.

## Quick Start Preview

```bash
# Install vnstat + initialize interfaces
bash scripts/install.sh

# Check current usage
bash scripts/traffic.sh status

# Output:
# ╔══════════════════════════════════════════════════════════╗
# ║  Network Traffic Monitor — vnstat                       ║
# ║  Interface: eth0                                        ║
# ║  Today:     ↓ 2.45 GiB  ↑ 890 MiB  = 3.32 GiB         ║
# ║  This Month: ↓ 68.2 GiB  ↑ 23.1 GiB = 91.3 GiB        ║
# ╚══════════════════════════════════════════════════════════╝
```

## Core Capabilities

1. Interface status — Current day/month/total bandwidth per interface
2. Daily breakdown — Hourly traffic patterns for today
3. Monthly tracking — Day-by-day usage with end-of-month projection
4. Live monitoring — Real-time bandwidth rates (Mbit/s)
5. Interface ranking — Compare traffic across all interfaces
6. Data cap alerts — Telegram/webhook at 80%/95% thresholds
7. Traffic heatmap — Visual 30-day usage patterns
8. Monthly comparison — Compare current vs previous months
9. JSON export — Pipe data into dashboards or automation
10. Cron integration — Automated hourly cap checks
11. Alert deduplication — No spam on repeated threshold hits

## Dependencies
- `vnstat` (2.6+)
- `bash` (4.0+)
- `jq`, `bc`, `curl`

## Installation Time
**5 minutes** — Run install.sh, start monitoring
