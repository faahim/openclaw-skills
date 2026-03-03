# Listing Copy: Logwatch Report Generator

## Metadata
- **Type:** Skill
- **Name:** logwatch-reports
- **Display Name:** Logwatch Report Generator
- **Categories:** [security, analytics]
- **Price:** $8
- **Dependencies:** [logwatch, perl]

## Tagline

Monitor system logs with automated daily digests — SSH, disk, services, security events

## Description

Manually reading through `/var/log/` is nobody's idea of a good time. By the time you spot a brute-force SSH attempt or a full disk, the damage is already done. You need automated log summaries.

Logwatch Report Generator installs and configures [Logwatch](https://sourceforge.net/projects/logwatch/) on your system — a battle-tested log analysis tool that parses syslog, auth, service logs, and more into clean, human-readable summary reports. Get daily or weekly digests delivered to your email or saved to a file, with zero ongoing maintenance.

**What it does:**
- 📊 Parse 20+ log sources (SSH, sudo, systemd, disk, kernel, web servers, etc.)
- 📧 Automated email digests on any schedule (daily, weekly, custom cron)
- 🔍 Three detail levels — quick overview or full forensic detail
- 🔐 Security-focused — failed logins, sudo abuse, firewall events
- 💾 Save reports to file for archival or agent analysis
- 🛠️ Custom service filters for your own application logs
- ⚡ 5-minute setup — one script installs everything

Perfect for sysadmins, developers running production servers, and homelab enthusiasts who want to know what's happening on their machines without staring at raw logs.

## Quick Start Preview

```bash
# Install logwatch
bash scripts/install.sh

# Generate a report
bash scripts/report.sh --detail high

# Set up daily email
bash scripts/setup-daily.sh --email admin@example.com
```

## Core Capabilities

1. System log parsing — Analyze 20+ log sources automatically
2. SSH security reports — Track failed logins, brute-force attempts, key usage
3. Disk usage monitoring — Warnings when filesystems fill up
4. Service health checks — Detect failed systemd units and crashes
5. Kernel event tracking — OOM kills, hardware errors, panics
6. Package audit trail — Track what was installed/updated/removed
7. Cron job monitoring — See which scheduled tasks ran or failed
8. Custom app filters — Add your own log parsers with one command
9. Multi-format output — Plain text or HTML reports
10. Flexible scheduling — Daily, weekly, or custom cron expressions
11. Multiple profiles — Different reports for security vs ops teams
12. File or email delivery — Choose your preferred output method

## Dependencies
- `logwatch` (auto-installed by scripts/install.sh)
- `perl` (usually pre-installed)
- Optional: `sendmail`/`postfix` for email delivery

## Installation Time
**5 minutes**

## Pricing Justification
- LarryBrain comparable: $5-12 for monitoring tools
- Alternative: Manual log reading (hours/week) or Datadog/Splunk ($100+/mo)
- One-time $8 for permanent automated log analysis
