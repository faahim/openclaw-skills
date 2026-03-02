# Listing Copy: Latency Monitor

## Metadata
- **Type:** Skill
- **Name:** latency-monitor
- **Display Name:** Latency Monitor
- **Categories:** [automation, analytics]
- **Price:** $10
- **Icon:** 📡
- **Dependencies:** [bash, fping, mtr, bc, curl]

## Tagline

Monitor network latency, jitter, and packet loss — Get alerts when quality degrades

## Description

Your uptime monitor says "200 OK" but your users are complaining about lag. HTTP status codes don't tell the whole story — latency spikes, jitter, and packet loss silently destroy user experience for VoIP, gaming, video calls, and real-time applications.

Latency Monitor continuously pings your hosts, measures round-trip time, jitter (variance), and packet loss, then alerts you via Telegram, webhook, or custom command when thresholds are exceeded. All data logs to CSV for trend analysis and percentile reporting.

**What it does:**
- 📡 Monitor unlimited hosts via ICMP ping or TCP connect
- ⏱️ Track latency (avg/min/max), jitter, and packet loss per check
- 🔔 Instant alerts via Telegram, webhook, or custom command (with dedup)
- 📊 CSV logging with analysis tool (percentiles, multi-host comparison)
- 🏥 One-shot network quality reports via mtr (hop-by-hop analysis)
- 🎮 Network grading system (★ to ★★★★★) for VoIP/gaming readiness
- ⚙️ Install as systemd service for persistent monitoring
- 🛡️ TCP fallback for hosts that block ICMP

Perfect for sysadmins, developers, and anyone who needs to know when their network is degrading — before users start complaining.

## Quick Start Preview

```bash
# Monitor hosts, alert on Telegram
bash scripts/latency-monitor.sh \
  --hosts "1.1.1.1,8.8.8.8,your-server.com" \
  --interval 60 \
  --alert-telegram "$TOKEN:$CHAT_ID"

# Output:
# [2026-03-02 15:00:00] 1.1.1.1 | latency=12.4ms jitter=1.2ms loss=0.0% | ✅ OK
# [2026-03-02 15:00:00] 8.8.8.8 | latency=18.7ms jitter=3.2ms loss=0.0% | ✅ OK
```

## Core Capabilities

1. Multi-host ICMP monitoring — Ping any number of hosts simultaneously
2. TCP connect mode — For hosts that block ICMP (use --tcp --port 443)
3. Configurable thresholds — Separate warn/critical levels for latency, jitter, loss
4. Alert deduplication — Won't spam you on sustained issues; alerts on state changes
5. Recovery notifications — Get notified when issues resolve
6. CSV logging — Full history with timestamps for trend analysis
7. Percentile reporting — P50/P95/P99 latency from log analysis tool
8. Network quality reports — mtr-based hop-by-hop analysis
9. Systemd service installer — Set up persistent monitoring in one command
10. Cron-compatible — Run periodic snapshots via crontab

## Dependencies
- bash (4.0+), fping, mtr, bc, curl

## Installation Time
**5 minutes** — Install fping, run script
