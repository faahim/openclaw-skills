# Listing Copy: Log Analyzer

## Metadata
- **Type:** Skill
- **Name:** log-analyzer
- **Display Name:** Log Analyzer
- **Categories:** [analytics, automation]
- **Price:** $12
- **Icon:** 🔍
- **Dependencies:** [bash, awk, grep, curl]

## Tagline

Parse and monitor log files — detect errors, patterns, and anomalies with instant alerts

## Description

Staring at log files is tedious. Scrolling through thousands of lines hoping to spot the error that crashed your app at 3am isn't a strategy — it's a prayer.

Log Analyzer parses any log file (syslog, nginx, apache, app logs, journald), detects error spikes and recurring patterns, and alerts you instantly via Telegram or webhook. It deduplicates errors, shows hourly histograms, and runs entirely on your machine with zero external dependencies.

**What it does:**
- 📊 Instant log summaries — errors, warnings, patterns, time ranges
- 🔍 Smart pattern detection — deduplicates and groups similar errors
- 📈 Hourly error histograms — spot spikes visually
- 🚨 Real-time monitoring with Telegram/webhook alerts
- 🌐 Access log analytics — status codes, top paths, IPs, hourly traffic
- 📋 Multiple output formats — detailed, brief, JSON, dashboard
- 🔄 Log rotation detection — handles rotating logs gracefully

Perfect for developers, sysadmins, and anyone running servers who needs to know when things break — without paying for Datadog or Splunk.

## Quick Start Preview

```bash
# Analyze any log file
bash scripts/analyze.sh /var/log/syslog

# Monitor with alerts
bash scripts/monitor.sh --file /var/log/nginx/error.log --threshold 10 --alert telegram

# Access log analytics
bash scripts/access-stats.sh /var/log/nginx/access.log
```

## Core Capabilities

1. Log file analysis — Error/warning counts, percentages, time ranges
2. Pattern detection — Deduplicate errors, track frequency trends
3. Hourly histograms — Visualize error frequency over time
4. Real-time monitoring — Watch files, alert on error spikes
5. Access log analytics — Status codes, top paths, IPs, methods
6. Journald support — Analyze systemd journal with unit/priority filters
7. Multi-log dashboard — Analyze multiple files at once
8. JSON output — Machine-readable format for piping
9. Telegram/webhook alerts — Instant notifications with cooldown
10. Zero dependencies — Standard Linux tools only (bash, awk, grep)
