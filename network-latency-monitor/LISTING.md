# Listing Copy: Network Latency Monitor

## Metadata
- **Type:** Skill
- **Name:** network-latency-monitor
- **Display Name:** Network Latency Monitor
- **Categories:** [automation, analytics]
- **Price:** $10
- **Dependencies:** [bash, ping, awk, bc]
- **Icon:** 📡

## Tagline
Monitor network latency to multiple hosts — Track trends, detect degradation, get instant alerts

## Description

**The Problem:** Network issues creep in silently. By the time you notice lag or packet loss, your users are already affected. Manually pinging servers tells you nothing about trends or patterns.

**The Solution:** Network Latency Monitor continuously pings your hosts, tracks latency and packet loss over time, and alerts you the moment things degrade. All data stored locally as CSV — no external monitoring service needed, no monthly fees.

**What it does:**
- 📡 Monitor unlimited hosts via ICMP ping
- ⏱️ Configurable intervals (every 10s to 24h)
- 🚨 Instant alerts via Telegram, Slack webhook, or custom command
- 📊 Detailed reports with avg/min/max/P95 latency and packet loss
- 📈 Trend detection — spot gradual degradation before it becomes critical
- 🗂️ CSV data format — easy to analyze, import, or graph
- 🔄 Cron-ready — run as one-shot checks or continuous daemon
- 🧹 Auto-cleanup — configurable data retention

**Who it's for:** Developers, sysadmins, and homelab enthusiasts who need lightweight, self-hosted network monitoring without the complexity of Nagios or the cost of Datadog.

## Quick Start Preview

```bash
# Monitor your servers
bash scripts/monitor.sh --host 8.8.8.8 --host your-server.com --interval 60 --threshold 100

# Output:
# [2026-03-03 14:00:00] 8.8.8.8 | avg=12.3ms | min=10.1ms | max=15.8ms | loss=0% | ✅
# [2026-03-03 14:00:00] your-server.com | avg=45.1ms | min=32.0ms | max=89.3ms | loss=0% | ✅
```

## Dependencies
- `bash` (4.0+)
- `ping` (iputils-ping)
- `awk`, `bc`, `date`
- Optional: `curl` (for webhook alerts)

## Installation Time
**3 minutes** — No compilation, no dependencies to install on most systems
