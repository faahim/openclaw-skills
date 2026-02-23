# Listing Copy: Speedtest Monitor

## Metadata
- **Type:** Skill
- **Name:** speedtest-monitor
- **Display Name:** Speedtest Monitor
- **Categories:** [automation, analytics]
- **Icon:** 📶
- **Dependencies:** [speedtest-cli, bash, jq, bc]

## Tagline

Monitor internet speed over time — Alert on ISP throttling and degradation

## Description

Tired of wondering if your ISP is actually delivering the speeds you pay for? Manually running speed tests doesn't catch intermittent throttling or peak-hour slowdowns.

Speedtest Monitor runs automated speed tests on a schedule, logs download/upload speeds and latency to CSV, and alerts you instantly via Telegram or webhook when performance drops below your thresholds. No cloud service, no monthly fee — runs entirely on your machine.

**What it does:**
- 📶 Run speed tests on schedule (every 5 min to 24 hours)
- 📊 Log results to CSV for trend analysis
- 🚨 Alert via Telegram, webhook, or log when speeds degrade
- 📈 Generate summary reports (avg/min/max speeds, degradation events)
- 🔧 One-shot mode for quick checks
- ⏱️ Alert cooldown to prevent notification spam
- 🗂️ JSON output for pipeline integration

Perfect for developers, sysadmins, and anyone who wants proof when their ISP underdelivers.

## Core Capabilities

1. Periodic speed testing — Automated Ookla speedtests at configurable intervals
2. CSV logging — Track download, upload, ping, server over time
3. Threshold alerts — Telegram/webhook notification when speeds drop
4. Report generation — Summarize speed trends from logged history
5. Alert cooldown — No notification spam on consecutive failures
6. Specific server testing — Pin tests to a particular Ookla server
7. JSON output — Pipe results into dashboards or monitoring tools
8. Cron-ready — Works as standalone daemon or cron job
9. Self-hosted — No external monitoring service needed
10. Lightweight — bash + speedtest-cli, minimal dependencies
