---
name: log-analyzer
description: >-
  Parse, analyze, and monitor log files — detect errors, anomalies, and patterns with instant alerts.
categories: [analytics, automation]
dependencies: [bash, awk, grep, curl]
---

# Log Analyzer

## What This Does

Automatically parse and analyze log files (syslog, nginx, apache, app logs, journald). Detect error spikes, recurring patterns, slow requests, and anomalies. Get instant Telegram/webhook alerts when things go wrong. No external services — runs entirely on your machine.

**Example:** "Scan /var/log/nginx/error.log every 5 minutes, alert me if error rate exceeds 10/min or any 5xx spike detected."

## Quick Start (3 minutes)

### 1. Install (nothing extra needed)

```bash
# All dependencies are standard Linux tools
which awk grep sed curl || echo "Missing core tools"

# Make scripts executable
chmod +x scripts/*.sh
```

### 2. Analyze a Log File

```bash
# Quick summary of any log file
bash scripts/analyze.sh /var/log/syslog

# Output:
# ╔══════════════════════════════════════╗
# ║         LOG ANALYSIS REPORT          ║
# ╠══════════════════════════════════════╣
# ║ File: /var/log/syslog                ║
# ║ Lines: 48,231                        ║
# ║ Time range: Feb 20 00:00 → Feb 21 17:45 ║
# ║ Errors: 142 (0.29%)                  ║
# ║ Warnings: 891 (1.85%)               ║
# ║ Top error: "Connection refused" ×47  ║
# ╚══════════════════════════════════════╝
```

### 3. Monitor in Real-Time

```bash
# Watch a log file, alert on errors
bash scripts/monitor.sh \
  --file /var/log/nginx/error.log \
  --threshold 10 \
  --interval 300 \
  --alert telegram
```

## Core Workflows

### Workflow 1: Quick Log Summary

**Use case:** Understand what's happening in a log file

```bash
bash scripts/analyze.sh /var/log/syslog --format detailed
```

**Output includes:**
- Total lines, time range, file size
- Error/warning/info breakdown with percentages
- Top 10 most frequent error messages (deduplicated)
- Error frequency over time (hourly histogram)
- Unique IPs (for access logs)
- Slowest requests (for web server logs)

### Workflow 2: Error Pattern Detection

**Use case:** Find recurring issues

```bash
bash scripts/analyze.sh /var/log/nginx/error.log --patterns
```

**Output:**
```
PATTERN ANALYSIS
────────────────
Pattern 1: "upstream timed out" — 234 occurrences
  First: Feb 20 03:12:44  Last: Feb 21 17:30:02
  Frequency: ~5.6/hour  Trend: ↗ increasing

Pattern 2: "connect() failed" — 89 occurrences
  First: Feb 20 08:00:01  Last: Feb 21 16:55:33
  Frequency: ~2.1/hour  Trend: → stable

Pattern 3: "SSL_do_handshake() failed" — 12 occurrences
  First: Feb 21 14:00:00  Last: Feb 21 17:28:11
  Frequency: ~3.4/hour  Trend: ↗ NEW — started 3h ago
```

### Workflow 3: Real-Time Monitoring with Alerts

**Use case:** Watch logs and get alerted on spikes

```bash
bash scripts/monitor.sh \
  --file /var/log/nginx/error.log \
  --threshold 10 \
  --interval 300 \
  --alert telegram \
  --cooldown 1800
```

**Parameters:**
- `--threshold`: Alert if errors exceed this count per interval
- `--interval`: Check interval in seconds (default: 300)
- `--alert`: Alert method (telegram, webhook, stdout)
- `--cooldown`: Minimum seconds between alerts (default: 1800)

### Workflow 4: Multi-Log Dashboard

**Use case:** Analyze multiple log files at once

```bash
bash scripts/analyze.sh \
  /var/log/syslog \
  /var/log/nginx/error.log \
  /var/log/nginx/access.log \
  --format dashboard
```

### Workflow 5: Journald Analysis

**Use case:** Analyze systemd journal logs

```bash
bash scripts/analyze.sh --journald --unit nginx --since "1 hour ago"
bash scripts/analyze.sh --journald --priority err --since today
```

### Workflow 6: Access Log Analytics

**Use case:** Web traffic analysis from nginx/apache access logs

```bash
bash scripts/access-stats.sh /var/log/nginx/access.log
```

**Output:**
```
ACCESS LOG ANALYTICS
────────────────────
Total requests: 124,891
Unique IPs: 3,421
Status codes: 200 (89.2%) | 301 (5.1%) | 404 (3.8%) | 500 (1.9%)
Top paths:   /api/v1/users (12,344) | /login (8,921) | / (7,234)
Top IPs:     203.0.113.50 (2,341) | 198.51.100.12 (1,892)
Peak hour:   14:00-15:00 (8,234 requests)
Avg response: 245ms | P95: 1,200ms | P99: 3,400ms
```

## Configuration

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Webhook alerts
export ALERT_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Config File (optional)

```bash
cp scripts/config-template.sh config.sh
# Edit config.sh with your settings
source config.sh
```

## Advanced Usage

### Run as Cron Job

```bash
# Hourly log summary
0 * * * * cd /path/to/log-analyzer && bash scripts/analyze.sh /var/log/syslog --format brief >> reports/hourly.log

# Continuous monitoring (run in background)
nohup bash scripts/monitor.sh --file /var/log/nginx/error.log --threshold 10 --alert telegram &
```

### Custom Log Formats

```bash
# Custom regex for error detection
bash scripts/analyze.sh /var/log/app.log \
  --error-pattern "FATAL|CRITICAL|PANIC" \
  --warn-pattern "WARN|DEGRADED" \
  --timestamp-format "%Y-%m-%dT%H:%M:%S"
```

### Filter by Time Range

```bash
# Last hour only
bash scripts/analyze.sh /var/log/syslog --since "1 hour ago"

# Specific date range
bash scripts/analyze.sh /var/log/syslog --since "2026-02-20" --until "2026-02-21"
```

### JSON Output (for piping)

```bash
bash scripts/analyze.sh /var/log/syslog --format json | jq .
```

## Troubleshooting

### Issue: "Permission denied"

```bash
# Run with sudo or add user to appropriate group
sudo bash scripts/analyze.sh /var/log/syslog
# Or: sudo usermod -aG adm $USER
```

### Issue: Large log files (>1GB) are slow

```bash
# Use --tail to analyze only recent entries
bash scripts/analyze.sh /var/log/huge.log --tail 100000
```

### Issue: Telegram alerts not sending

```bash
# Test Telegram connection
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Test" | jq .ok
```

## Key Principles

1. **Fast** — Processes 100K lines in <5 seconds using awk/grep
2. **Smart deduplication** — Groups similar errors, shows patterns not noise
3. **Alert once** — Cooldown prevents alert storms
4. **Zero dependencies** — Standard Linux tools only (bash, awk, grep, sed, curl)
5. **Multiple formats** — Human-readable, JSON, or brief for cron jobs
