---
name: journalctl-analyzer
description: >-
  Analyze systemd journal logs to detect errors, track service health, and generate incident reports.
categories: [analytics, automation]
dependencies: [bash, journalctl, jq, awk]
---

# Journalctl Analyzer

## What This Does

Parses systemd journal logs to find errors, crashes, OOM kills, failed services, and security events. Generates structured reports, tracks recurring issues, and alerts on critical patterns. Works on any systemd-based Linux system.

**Example:** "Scan last 24h of logs, find all failed services, OOM kills, and auth failures. Output a prioritized incident report."

## Quick Start (2 minutes)

### 1. Verify Dependencies

```bash
# All should be pre-installed on systemd-based Linux
which journalctl jq awk && echo "Ready!"
```

### 2. Run Quick Health Check

```bash
bash scripts/analyze.sh --quick
```

### 3. Full Analysis (last 24 hours)

```bash
bash scripts/analyze.sh --since "24 hours ago" --output report.json
```

## Core Workflows

### Workflow 1: Service Health Report

**Use case:** See which services have failed or restarted recently

```bash
bash scripts/analyze.sh --mode services --since "7 days ago"
```

**Output:**
```
=== Service Health Report (last 7 days) ===

FAILED SERVICES:
  nginx.service          — failed 3 times (last: 2026-02-25 10:30:15)
  postgresql.service     — failed 1 time  (last: 2026-02-24 03:12:44)

RESTARTED SERVICES (>3 restarts):
  openclaw.service       — 12 restarts
  docker.service         — 5 restarts

HIGH-FREQUENCY ERRORS:
  sshd[*]: Failed password  — 847 occurrences
  kernel: Out of memory     — 3 occurrences
```

### Workflow 2: Security Audit

**Use case:** Detect brute force attempts, unauthorized access, sudo abuse

```bash
bash scripts/analyze.sh --mode security --since "24 hours ago"
```

**Output:**
```
=== Security Audit (last 24h) ===

SSH BRUTE FORCE:
  192.168.1.55   — 234 failed attempts
  10.0.0.99      — 87 failed attempts

SUDO EVENTS:
  user 'deploy' ran: rm -rf /var/log  ⚠️ SUSPICIOUS
  user 'admin' ran: systemctl restart nginx  ✅ OK

AUTH FAILURES:
  PAM: 12 authentication failures for user 'root'
```

### Workflow 3: OOM & Resource Analysis

**Use case:** Find memory kills and resource exhaustion events

```bash
bash scripts/analyze.sh --mode resources --since "7 days ago"
```

**Output:**
```
=== Resource Analysis (last 7 days) ===

OOM KILLS:
  2026-02-23 14:22:01 — Killed process 'java' (RSS: 2.1GB)
  2026-02-22 09:15:33 — Killed process 'node' (RSS: 1.8GB)

DISK PRESSURE:
  2026-02-24 — "No space left on device" x 7

CPU THROTTLING:
  None detected
```

### Workflow 4: Continuous Monitoring

**Use case:** Watch logs in real-time, alert on critical patterns

```bash
bash scripts/analyze.sh --mode watch --alert-cmd 'echo "ALERT: $MESSAGE"'
```

### Workflow 5: JSON Report for Automation

**Use case:** Machine-readable output for dashboards or further processing

```bash
bash scripts/analyze.sh --since "24 hours ago" --format json --output /tmp/report.json
```

## Configuration

### Environment Variables

```bash
# Alert via Telegram (optional)
export TELEGRAM_BOT_TOKEN="<your-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Custom log priority threshold (default: err)
export JOURNAL_MIN_PRIORITY="warning"

# Max lines to process (default: 50000)
export JOURNAL_MAX_LINES="100000"
```

### Ignore Patterns

Create `~/.config/journalctl-analyzer/ignore.txt`:

```
# One pattern per line (grep -E syntax)
systemd-resolved.*DNSSEC
snapd.*auto-refresh
NetworkManager.*dhcp
```

## Advanced Usage

### Filter by Unit

```bash
# Analyze only nginx logs
bash scripts/analyze.sh --unit nginx.service --since "24 hours ago"

# Multiple units
bash scripts/analyze.sh --unit "nginx.service,postgresql.service" --since "7 days ago"
```

### Custom Time Ranges

```bash
# Specific date range
bash scripts/analyze.sh --since "2026-02-20" --until "2026-02-25"

# Since last boot
bash scripts/analyze.sh --boot
```

### Cron Integration

```bash
# Daily report at 8am
0 8 * * * bash /path/to/scripts/analyze.sh --since "24 hours ago" --format json --output /var/log/daily-report.json --alert telegram
```

## Troubleshooting

### Issue: "No journal files found"

**Fix:** Ensure journald is running and you have read permissions:
```bash
sudo usermod -a -G systemd-journal $USER
# Then re-login
```

### Issue: Analysis is slow

**Fix:** Limit scope:
```bash
bash scripts/analyze.sh --since "1 hour ago" --max-lines 10000
```

### Issue: Too many false positives

**Fix:** Add patterns to ignore file:
```bash
echo "some_noisy_pattern" >> ~/.config/journalctl-analyzer/ignore.txt
```

## Key Principles

1. **Non-destructive** — Read-only, never modifies logs
2. **Prioritized** — Critical issues first (OOM > errors > warnings)
3. **Deduplication** — Groups repeated errors, shows counts
4. **Fast** — Processes 50k lines in seconds via awk/grep pipelines
5. **Alertable** — Pipe results to Telegram, email, or webhooks
