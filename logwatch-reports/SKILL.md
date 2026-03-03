---
name: logwatch-reports
description: >-
  Install and configure Logwatch for automated system log summary reports. Get daily/weekly digests of SSH logins, disk usage, service errors, and security events delivered to your inbox or file.
categories: [security, analytics]
dependencies: [logwatch, sendmail or postfix (optional for email)]
---

# Logwatch Report Generator

## What This Does

Installs and configures [Logwatch](https://sourceforge.net/projects/logwatch/) — a customizable log analysis system that parses system logs and generates human-readable summary reports. Instead of manually grepping through `/var/log/`, get a clean digest of SSH attempts, disk usage, service failures, package updates, and security events.

**Example:** "Generate a daily report showing all failed SSH logins, disk usage warnings, and service crashes — emailed to you every morning or saved to a file."

## Quick Start (5 minutes)

### 1. Install Logwatch

```bash
bash scripts/install.sh
```

This installs logwatch and its dependencies via your system package manager.

### 2. Generate Your First Report

```bash
# Quick report for today
bash scripts/report.sh

# Detailed report for yesterday
bash scripts/report.sh --range yesterday --detail high

# Report for last 7 days
bash scripts/report.sh --range "between -7 days and today"
```

### 3. Set Up Daily Email Reports

```bash
# Configure daily email digest (requires working SMTP/sendmail)
bash scripts/setup-daily.sh --email admin@example.com --detail med

# Or save to file instead of email
bash scripts/setup-daily.sh --output /var/log/logwatch/daily-report.txt
```

## Core Workflows

### Workflow 1: On-Demand Report

**Use case:** Quick system health check

```bash
bash scripts/report.sh --detail med
```

**Output:**
```
################### Logwatch 7.9 (02/01/24) ####################
        Processing Initiated: Tue Mar  3 10:00:00 2026
        Date Range Processed: yesterday
        Detail Level: Med
        Logfiles: System, Auth, Syslog
################################################################

 --------------------- SSHD Begin ------------------------
 Failed logins from:
    192.168.1.105: 3 times
    10.0.0.42: 1 time

 Users logging in through sshd:
    root: 2 times
    clawd: 5 times
 -------------------- SSHD End -------------------------

 --------------------- Disk Space Begin --------------------
 Filesystem      Size  Used Avail Use%
 /dev/sda1        50G   32G   18G  64%
 /dev/sda2       200G  180G   20G  90%  **WARNING**
 -------------------- Disk Space End ---------------------

 --------------------- systemd Begin -----------------------
 Units failed: nginx.service (exit-code)
 -------------------- systemd End ------------------------
```

### Workflow 2: Security Audit Report

**Use case:** Check for intrusion attempts

```bash
bash scripts/report.sh --service sshd --service pam_unix --service sudo --detail high --range "between -7 days and today"
```

### Workflow 3: Daily Email Digest

**Use case:** Automated morning report

```bash
# Set up cron for daily 6 AM reports
bash scripts/setup-daily.sh --email admin@example.com --time "0 6 * * *" --detail med
```

### Workflow 4: Custom Service Report

**Use case:** Monitor specific services only

```bash
# Only check nginx and postfix
bash scripts/report.sh --service http --service postfix --detail high
```

### Workflow 5: Weekly Summary

```bash
bash scripts/setup-daily.sh --email admin@example.com --time "0 8 * * 1" --range "between -7 days and yesterday" --detail high
```

## Configuration

### Custom Logwatch Config

```bash
# Create override config
bash scripts/configure.sh --detail med --range yesterday --format text --output file --filename /var/log/logwatch/report.txt
```

This creates `/etc/logwatch/conf/logwatch.conf` with your preferences.

### Environment Variables

```bash
# Email delivery (if using email output)
export LOGWATCH_EMAIL="admin@example.com"
export LOGWATCH_DETAIL="Med"        # Low, Med, High
export LOGWATCH_RANGE="yesterday"   # today, yesterday, or date range
export LOGWATCH_FORMAT="text"       # text or html
```

### Detail Levels

| Level | What's Included |
|-------|----------------|
| **Low** | Summary counts only (failed logins: 5) |
| **Med** | Counts + source IPs, service names |
| **High** | Full details — every log entry matched |

### Available Services

Logwatch monitors these automatically if the service is running:

- `sshd` — SSH login attempts, failures, key auth
- `sudo` — Sudo command usage
- `pam_unix` — PAM authentication events
- `postfix` / `sendmail` — Email delivery
- `http` (Apache) / `nginx` — Web server access/errors
- `named` — DNS queries
- `dpkg` / `yum` — Package installations/updates
- `kernel` — Kernel messages, OOM kills
- `cron` — Cron job execution
- `disk-space` — Filesystem usage
- `systemd` — Service start/stop/fail events
- `iptables` / `firewalld` — Firewall events

## Advanced Usage

### HTML Email Reports

```bash
bash scripts/report.sh --format html --email admin@example.com
```

### Pipe to OpenClaw Agent

```bash
# Generate report and have your agent analyze it
bash scripts/report.sh --detail high > /tmp/logwatch-report.txt
# Then: "Read /tmp/logwatch-report.txt and flag anything concerning"
```

### Custom Log Parsers

```bash
# Add custom service filter
bash scripts/add-filter.sh --service myapp --logfile /var/log/myapp.log --pattern "ERROR|WARN|FATAL"
```

### Multiple Report Profiles

```bash
# Security-focused daily report
bash scripts/setup-daily.sh --profile security --service sshd,sudo,pam_unix,iptables --detail high --email security@example.com

# Ops-focused daily report
bash scripts/setup-daily.sh --profile ops --service disk-space,systemd,kernel --detail med --email ops@example.com
```

## Troubleshooting

### Issue: "logwatch: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
# Debian/Ubuntu: sudo apt-get install logwatch
# RHEL/CentOS:   sudo yum install logwatch
# Arch:          sudo pacman -S logwatch
```

### Issue: Email reports not arriving

**Check:**
1. Is a mail transfer agent installed? `which sendmail || which postfix`
2. Test sending: `echo "test" | mail -s "Test" you@example.com`
3. Use file output as fallback: `--output file --filename /path/to/report.txt`

### Issue: Report is empty

**Check:**
1. Verify logs exist: `ls -la /var/log/syslog /var/log/auth.log`
2. Check permissions: logwatch needs read access to log files
3. Try a wider range: `--range "between -7 days and today"`

### Issue: Missing service in report

**Fix:** The service may use a non-standard log path:
```bash
# Check available services
ls /usr/share/logwatch/scripts/services/
# Check log file groups
ls /usr/share/logwatch/conf/logfiles/
```

## Dependencies

- `logwatch` (installed via scripts/install.sh)
- `perl` (logwatch dependency, usually pre-installed)
- Optional: `sendmail` or `postfix` (for email delivery)
- Optional: `cronie` / `cron` (for scheduled reports)

## Key Principles

1. **Read-only** — Logwatch only reads logs, never modifies them
2. **Configurable scope** — Monitor all services or just specific ones
3. **Multiple outputs** — Email, file, or stdout
4. **Detail control** — Low/Med/High verbosity
5. **Zero performance impact** — Runs on-demand or via cron, not a daemon
