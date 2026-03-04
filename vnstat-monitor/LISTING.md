# Listing Copy: vnStat Network Monitor

## Metadata
- **Type:** Skill
- **Name:** vnstat-monitor
- **Display Name:** vnStat Network Monitor
- **Categories:** [automation, analytics]
- **Price:** $10
- **Dependencies:** [vnstat, jq, bash, bc]
- **Icon:** 📡

## Tagline
Monitor network bandwidth usage — track daily, weekly, monthly traffic with cap alerts

## Description

Running a VPS with a 1TB transfer limit? Hosting services at home and wondering where your bandwidth goes? Manually checking `ifconfig` doesn't cut it when you need real usage data over time.

vnStat Network Monitor installs and configures vnstat to track bandwidth across all your network interfaces. Get daily, weekly, and monthly reports with RX/TX breakdowns. Set bandwidth caps with warning thresholds and get alerts via Telegram or log files before you hit overage charges.

**What it does:**
- 📡 Auto-detect and monitor all network interfaces
- 📊 Daily, weekly, monthly, and yearly traffic reports
- 🚨 Bandwidth cap alerts with configurable warn/critical thresholds
- 📈 End-of-month usage projection
- 📱 Telegram notifications when approaching limits
- 📋 Export to JSON, CSV, or formatted tables
- 🔄 Live rate monitoring mode
- ⏰ Cron-ready — schedule automatic checks
- 🔧 One-command install — auto-detects OS (Debian/Ubuntu/RHEL/Fedora/Arch/Alpine)

Perfect for VPS operators, home server admins, and anyone who needs to track network usage without a full monitoring stack.

## Quick Start Preview

```bash
# Install vnstat + start monitoring
bash scripts/install.sh

# See this month's bandwidth
bash scripts/report.sh

# Set a 1TB monthly cap with alerts
bash scripts/alert.sh --cap 1000 --unit GiB --check
# ✅ Current usage: 234.5 GiB / 1000 GiB (23.5%)
# 📊 Projected end-of-month: 782 GiB (78.2%)
```

## Core Capabilities

1. Auto-install — Detects OS and installs vnstat + dependencies in one command
2. Multi-interface — Monitor eth0, wlan0, wg0, and any other interface simultaneously
3. Bandwidth reports — Daily, weekly, monthly, yearly with RX/TX breakdown
4. Usage projection — Predicts end-of-month usage based on current trend
5. Cap alerts — Set monthly limits with 80%/95% warning thresholds
6. Telegram alerts — Get notified on your phone when approaching limits
7. JSON/CSV export — Pipe data to dashboards, spreadsheets, or automation
8. Live monitoring — Real-time bandwidth rate display
9. Interface comparison — Side-by-side usage across all interfaces
10. Top days — Find your highest-traffic days at a glance
11. Cron scheduling — Automatic daily/weekly checks
12. Lightweight — Uses ~2MB RAM, zero CPU overhead

## Installation Time
**5 minutes** — Run install script, start generating reports immediately
