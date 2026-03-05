# Listing Copy: Scrutiny Disk Monitor

## Metadata
- **Type:** Skill
- **Name:** scrutiny-disk-monitor
- **Display Name:** Scrutiny Disk Monitor
- **Categories:** [automation, security]
- **Price:** $12
- **Dependencies:** [docker, smartmontools]
- **Icon:** 💽

## Tagline

Monitor hard drive health with S.M.A.R.T tracking — Get alerts before drives fail

## Description

Hard drives fail. SSDs wear out. By the time you notice, your data might already be gone. You need proactive monitoring that catches problems before they become disasters.

Scrutiny Disk Monitor deploys a self-hosted S.M.A.R.T monitoring dashboard that scans your drives on a schedule, tracks health trends over time, and alerts you via Telegram, email, or webhook when a drive shows pre-failure signs. No cloud services, no subscriptions — it runs entirely on your server.

**What it does:**
- 💽 Monitor all drives (HDD, SSD, NVMe) with S.M.A.R.T data
- 📊 Web dashboard with historical health trends and graphs
- 🔔 Instant alerts via Telegram, email, or Slack webhook
- 🌡️ Temperature monitoring with high-temp warnings
- 🔒 SSL certificate and wear-level tracking for SSDs
- ⏱️ Configurable scan intervals (1 hour to 24 hours)
- 📡 Remote collector mode for monitoring multiple servers
- 📋 Export health data as JSON or CSV

Perfect for sysadmins, homelab enthusiasts, and anyone running servers with valuable data who wants peace of mind about their storage health.

## Quick Start Preview

```bash
# Deploy Scrutiny with Telegram alerts
bash scripts/deploy.sh --telegram-token "BOT_TOKEN" --telegram-chat "CHAT_ID"

# Quick terminal health check (no Docker needed)
bash scripts/health-check.sh
# /dev/sda  Samsung 870 EVO 1TB    ✅ PASSED  Temp: 34°C  Health: 98%
# /dev/nvme0n1  Samsung 980 Pro    ✅ PASSED  Temp: 42°C  Health: 95%
```

## Core Capabilities

1. S.M.A.R.T monitoring — Collect and analyze drive health attributes
2. Web dashboard — Visual health trends with InfluxDB-backed graphs
3. Multi-drive support — HDDs, SSDs, and NVMe simultaneously
4. Alert notifications — Telegram, email, Slack, Discord, custom webhooks
5. Temperature tracking — Warn on overheating drives
6. SSD wear tracking — Monitor write endurance and remaining life
7. Remote collectors — Monitor drives across multiple servers from one dashboard
8. Scheduled scans — Configurable cron-based S.M.A.R.T collection
9. Data export — JSON and CSV export for analysis
10. One-command deploy — Docker-based setup in under 5 minutes

## Dependencies
- `docker` (20.10+) and `docker compose`
- `smartmontools` (7.0+)
- Optional: `nvme-cli` (for NVMe drives)

## Installation Time
**5 minutes** — Run deploy script, access dashboard

## Pricing Justification
- Comparable SaaS: Datadog disk monitoring ($15+/mo), dedicated monitoring services ($10-50/mo)
- Our advantage: One-time $12, self-hosted, unlimited drives, no recurring fees
- Complexity: Medium (Docker deployment + multi-channel alerts + historical tracking)
