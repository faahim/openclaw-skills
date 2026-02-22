---
name: port-scanner
description: >-
  Scan networks for open ports, detect running services, check for security vulnerabilities, and generate audit reports.
categories: [security, dev-tools]
dependencies: [nmap, bash, jq]
---

# Port Scanner & Security Auditor

## What This Does

Scans hosts and networks for open ports, identifies running services and versions, checks for common vulnerabilities, and generates actionable security reports. Uses nmap under the hood — the industry standard for network discovery and security auditing.

**Example:** "Scan my server, find all open ports, flag anything risky, email me a report."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install nmap (required)
# Ubuntu/Debian
sudo apt-get install -y nmap jq

# CentOS/RHEL
sudo yum install -y nmap jq

# macOS
brew install nmap jq

# Verify
nmap --version
```

### 2. Quick Scan a Host

```bash
bash scripts/scan.sh --target example.com --mode quick

# Output:
# ╔══════════════════════════════════════════════╗
# ║  PORT SCAN REPORT — example.com             ║
# ╠══════════════════════════════════════════════╣
# ║ PORT     STATE   SERVICE     VERSION         ║
# ║ 22/tcp   open    ssh         OpenSSH 8.9     ║
# ║ 80/tcp   open    http        nginx 1.24      ║
# ║ 443/tcp  open    https       nginx 1.24      ║
# ╠══════════════════════════════════════════════╣
# ║ ⚠ FINDINGS: 1 warning, 0 critical           ║
# ║ → Port 22 open to internet (consider IP ACL) ║
# ╚══════════════════════════════════════════════╝
```

### 3. Full Security Audit

```bash
bash scripts/scan.sh --target 192.168.1.0/24 --mode full --output report.json

# Scans entire subnet, detects OS, service versions, runs vulnerability scripts
```

## Core Workflows

### Workflow 1: Quick Port Check

**Use case:** See what's open on a single host

```bash
bash scripts/scan.sh --target myserver.com --mode quick
```

Scans top 1000 ports. Fast (~30 seconds).

### Workflow 2: Full Security Audit

**Use case:** Deep scan with vulnerability detection

```bash
bash scripts/scan.sh --target myserver.com --mode full
```

Scans all 65535 ports, detects OS and service versions, runs NSE vulnerability scripts. Thorough (~5-15 minutes).

### Workflow 3: Subnet Discovery

**Use case:** Find all hosts on a network

```bash
bash scripts/scan.sh --target 192.168.1.0/24 --mode discover
```

Ping sweep + port scan on live hosts. Maps your network.

### Workflow 4: Specific Port Check

**Use case:** Check if specific services are running

```bash
bash scripts/scan.sh --target myserver.com --ports 22,80,443,3306,5432,6379,27017
```

Only scans the listed ports. Useful for verifying firewall rules.

### Workflow 5: Compare Scans (Drift Detection)

**Use case:** Detect new open ports since last scan

```bash
# Save baseline
bash scripts/scan.sh --target myserver.com --mode quick --output baseline.json

# Later, compare
bash scripts/scan.sh --target myserver.com --mode quick --output current.json
bash scripts/diff.sh baseline.json current.json

# Output:
# 🆕 NEW: 8080/tcp (http-proxy) — opened since baseline
# ❌ CLOSED: 3306/tcp (mysql) — no longer accessible
```

### Workflow 6: Scheduled Security Scan

**Use case:** Weekly automated audit

```bash
# Add to crontab — scan every Sunday at 3am
0 3 * * 0 cd /path/to/port-scanner && bash scripts/scan.sh --target myserver.com --mode full --output "reports/scan-$(date +\%F).json" --alert telegram 2>&1 >> logs/scan.log
```

## Configuration

### Environment Variables

```bash
# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Email alerts (optional)
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER="you@gmail.com"
export SMTP_PASS="app-password"
export ALERT_EMAIL="admin@example.com"
```

### Security Rules (Customize)

Edit `scripts/security-rules.json` to define what's flagged:

```json
{
  "critical_ports": [3306, 5432, 6379, 27017, 9200, 11211],
  "warn_ports": [22, 21, 23, 25, 445, 3389],
  "expected_open": [80, 443],
  "max_open_ports": 20,
  "flag_unversioned": true,
  "flag_outdated_ssh": true
}
```

- **critical_ports**: Database/cache ports that should NEVER be public
- **warn_ports**: Services that need access controls
- **expected_open**: Ports you expect to be open (no warnings)
- **max_open_ports**: Alert if more than N ports are open

## Advanced Usage

### JSON Output for Automation

```bash
bash scripts/scan.sh --target myserver.com --mode quick --format json

# Pipe to jq for filtering
bash scripts/scan.sh --target myserver.com --mode quick --format json | jq '.ports[] | select(.state == "open")'
```

### Multiple Targets

```bash
# From file (one target per line)
bash scripts/scan.sh --targets-file hosts.txt --mode quick

# hosts.txt:
# server1.example.com
# server2.example.com
# 10.0.0.0/24
```

### Custom nmap Arguments

```bash
# Pass raw nmap flags
bash scripts/scan.sh --target myserver.com --nmap-args "-sV -sC --script vuln -T4"
```

## Troubleshooting

### Issue: "nmap: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install -y nmap

# macOS
brew install nmap
```

### Issue: "Permission denied" or incomplete results

Some scan types need root:

```bash
sudo bash scripts/scan.sh --target myserver.com --mode full
```

### Issue: Scan takes too long

Use `--mode quick` or limit ports:

```bash
bash scripts/scan.sh --target myserver.com --ports 22,80,443
```

### Issue: Telegram alerts not working

```bash
# Test Telegram delivery
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Test"
```

## Key Principles

1. **Non-destructive** — Read-only scans, never exploits
2. **Actionable output** — Every finding includes a recommendation
3. **Diff-aware** — Compare scans over time to detect drift
4. **Alert on critical** — Database ports open to internet = instant alert
5. **JSON-native** — Structured output for automation pipelines
