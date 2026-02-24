# Listing Copy: Bandwidth Monitor

## Metadata
- **Type:** Skill
- **Name:** bandwidth-monitor
- **Display Name:** Bandwidth Monitor
- **Categories:** [automation, analytics]
- **Price:** $10
- **Icon:** 📡
- **Dependencies:** [vnstat, bash, jq]

## Tagline

Monitor network bandwidth usage — Get alerts before you hit data caps

## Description

Servers with bandwidth limits? Metered connections? Or just curious where all your data goes? Manually checking network usage is tedious, and by the time you notice a spike, the damage is done.

Bandwidth Monitor installs and configures vnstat (lightweight network traffic daemon) to track every byte flowing through your interfaces. See daily, weekly, and monthly usage at a glance. Set threshold alerts via Telegram when you're approaching limits. Generate reports for billing or capacity planning. Find bandwidth-hungry processes with per-process monitoring.

**What it does:**
- 📊 Track daily/weekly/monthly bandwidth per interface
- 🚨 Threshold alerts via Telegram when limits are near
- 📈 Real-time live bandwidth monitoring
- 📋 Generate usage reports (table or JSON export)
- 🔍 Find top bandwidth-consuming processes
- 🔄 Multi-interface comparison (eth0, wlan0, docker0, etc.)
- ⏱️ Cron-ready for automated threshold checks
- 💾 Historical data retention (12+ months)

Perfect for sysadmins, developers running servers, anyone with metered connections, or teams needing bandwidth accountability.

## Core Capabilities

1. Real-time monitoring — Live bandwidth rates per interface
2. Historical tracking — Daily, weekly, monthly usage via vnstat
3. Threshold alerts — Telegram notifications when limits exceeded
4. Usage reports — Table or JSON format for billing/planning
5. Per-process monitoring — Find which process eats bandwidth (via nethogs)
6. Multi-interface — Monitor and compare all network interfaces
7. Auto-detection — Finds primary interface automatically
8. Cron integration — Schedule threshold checks every 15 min
9. Zero overhead — vnstat uses <5MB RAM, ~0.1% CPU
10. One-command install — Dependencies handled automatically

## Dependencies
- `vnstat` (2.6+) — installed by skill
- `nethogs` (optional) — installed by skill
- `bash` (4.0+), `jq`, `curl`

## Installation Time
5 minutes
