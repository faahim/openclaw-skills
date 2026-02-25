# Listing Copy: Journalctl Analyzer

## Metadata
- **Type:** Skill
- **Name:** journalctl-analyzer
- **Display Name:** Journalctl Analyzer
- **Categories:** [analytics, automation]
- **Price:** $10
- **Dependencies:** [bash, journalctl, jq, awk]
- **Icon:** 📋

## Tagline
Analyze systemd logs — detect errors, OOM kills, and security threats instantly

## Description

Troubleshooting Linux servers means drowning in logs. Scrolling through thousands of journalctl lines looking for the one error that crashed your service at 3am is painful and slow. You need structured analysis, not raw text.

Journalctl Analyzer parses your systemd journal logs and surfaces what matters: failed services, OOM kills, SSH brute force attempts, disk pressure, and recurring errors — all prioritized by severity. One command gives you a full incident report.

**What it does:**
- 🔍 Service health reports — failed units, restart loops, error counts
- 🛡️ Security audits — SSH brute force IPs, suspicious sudo commands, auth failures
- 💾 Resource analysis — OOM kills, disk pressure, kernel errors
- ⚡ Quick health check — priority counts + currently failed units
- 👁️ Live watch mode — real-time error stream with alerting
- 📊 JSON output — machine-readable reports for dashboards and automation
- 🔔 Telegram alerts — notify on critical issues automatically
- 🔇 Ignore patterns — filter out known noisy log entries

Perfect for sysadmins, DevOps engineers, and anyone running Linux servers who needs fast, structured log analysis without installing heavy monitoring stacks.

## Core Capabilities

1. Service health report — find failed/restarting services with error counts and timestamps
2. Security audit — detect SSH brute force, suspicious sudo, PAM auth failures
3. OOM kill detection — find memory kills with process names and RSS sizes
4. Disk pressure alerts — catch "no space left" and filesystem-full events
5. Kernel error summary — deduplicated kernel errors ranked by frequency
6. Quick health check — one-command overview with priority breakdown
7. Live watch mode — stream errors in real-time with custom alert hooks
8. JSON reports — pipe to dashboards, automation, or cron jobs
9. Unit filtering — analyze specific services or multiple units
10. Noise reduction — configurable ignore patterns for known false positives
11. Cron-ready — scheduled daily/hourly reports with Telegram alerting
12. Zero dependencies — uses journalctl, jq, awk (all pre-installed on systemd Linux)

## Dependencies
- `bash` (4.0+)
- `journalctl` (systemd)
- `jq` (JSON processing)
- `awk` (text processing)

## Installation Time
**2 minutes** — no installation needed, just run the script
