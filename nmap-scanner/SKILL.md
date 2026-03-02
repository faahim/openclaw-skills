---
name: nmap-scanner
description: >-
  Network discovery and security scanning with nmap. Scan hosts, detect services, check vulnerabilities, and generate reports — all from simple commands.
categories: [security, dev-tools]
dependencies: [bash, nmap]
---

# Nmap Scanner

## What This Does

Wraps nmap into simple, opinionated workflows for common network tasks: discover hosts on your LAN, scan for open ports, detect running services, check for vulnerabilities, and generate clean reports. No need to memorize nmap flags.

**Example:** "Scan my network, find all devices, check what ports are open, and alert me if anything unexpected shows up."

## Quick Start (5 minutes)

### 1. Install nmap

```bash
bash scripts/install.sh
```

### 2. Scan Your Network

```bash
# Discover all hosts on your local network
bash scripts/scan.sh discover

# Quick port scan on a specific host
bash scripts/scan.sh ports 192.168.1.1

# Full service detection
bash scripts/scan.sh services 192.168.1.0/24
```

## Core Workflows

### Workflow 1: Network Discovery

Find all live hosts on your network.

```bash
bash scripts/scan.sh discover [network]
```

**What it does:**
- Auto-detects your local subnet if no network specified
- Sends ARP pings (fast, reliable on LAN)
- Shows hostname, IP, MAC address, vendor

**Output:**
```
=== Network Discovery: 192.168.1.0/24 ===
Found 8 hosts:

  192.168.1.1    router.local          AA:BB:CC:DD:EE:FF  (TP-Link)
  192.168.1.10   desktop.local         11:22:33:44:55:66  (Apple)
  192.168.1.15   nas.local             AA:11:BB:22:CC:33  (Synology)
  192.168.1.20   printer.local         DD:EE:FF:00:11:22  (HP)
  ...
```

### Workflow 2: Port Scanning

Check what ports are open on a target.

```bash
# Quick scan (top 1000 ports)
bash scripts/scan.sh ports <target>

# Full scan (all 65535 ports)
bash scripts/scan.sh ports <target> --full

# Specific ports
bash scripts/scan.sh ports <target> --ports 22,80,443,8080
```

**Output:**
```
=== Port Scan: 192.168.1.1 ===

PORT     STATE  SERVICE
22/tcp   open   ssh
80/tcp   open   http
443/tcp  open   https
8080/tcp open   http-proxy

4 open ports found
```

### Workflow 3: Service Detection

Identify what software is running on open ports.

```bash
bash scripts/scan.sh services <target>
```

**Output:**
```
=== Service Detection: 192.168.1.1 ===

PORT     STATE  SERVICE     VERSION
22/tcp   open   ssh         OpenSSH 9.2p1 Ubuntu
80/tcp   open   http        nginx 1.24.0
443/tcp  open   https       nginx 1.24.0
3306/tcp open   mysql       MySQL 8.0.35

OS: Linux 5.15 (95% confidence)
```

### Workflow 4: Vulnerability Check

Run nmap's built-in vulnerability scripts against a target.

```bash
bash scripts/scan.sh vuln <target>
```

**Output:**
```
=== Vulnerability Scan: 192.168.1.1 ===

[!] CVE-2023-38408 — OpenSSH pre-auth double free (port 22)
    Risk: HIGH
    Fix: Upgrade to OpenSSH 9.3p2+

[!] SSL Certificate expiring in 12 days (port 443)
    Risk: MEDIUM
    Fix: Renew SSL certificate

[✓] No critical vulnerabilities on ports 80, 3306
```

### Workflow 5: Compare Scans (Diff)

Detect changes in your network over time.

```bash
# Save a baseline scan
bash scripts/scan.sh discover --save baseline

# Later, compare against baseline
bash scripts/scan.sh discover --diff baseline
```

**Output:**
```
=== Network Changes (vs baseline from 2026-02-28) ===

  [+] NEW:     192.168.1.25  unknown          (Intel Corporate)
  [-] GONE:    192.168.1.20  printer.local    (HP)
  [~] CHANGED: 192.168.1.15  port 8080 now open (was closed)
```

### Workflow 6: Generate Reports

```bash
# HTML report
bash scripts/scan.sh services <target> --report html

# JSON output (for scripting)
bash scripts/scan.sh ports <target> --report json

# CSV output
bash scripts/scan.sh discover --report csv
```

## Configuration

### Scan Profiles

```bash
# Create a config file for recurring scans
cat > ~/.nmap-scanner.yaml << 'EOF'
profiles:
  home:
    network: 192.168.1.0/24
    schedule: daily
    alerts:
      new_hosts: true
      new_ports: true
      notify: telegram  # or email, webhook

  servers:
    targets:
      - 10.0.0.1
      - 10.0.0.2
      - 10.0.0.3
    ports: 22,80,443,3306,5432
    schedule: hourly
    alerts:
      port_changes: true
EOF

# Run a named profile
bash scripts/scan.sh profile home
```

### Environment Variables

```bash
# Default network (auto-detected if not set)
export NMAP_DEFAULT_NETWORK="192.168.1.0/24"

# Report output directory
export NMAP_REPORT_DIR="$HOME/.nmap-scanner/reports"

# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"
```

## Advanced Usage

### Stealth Scan

```bash
# SYN scan (requires root) — less detectable
bash scripts/scan.sh ports <target> --stealth
```

### OS Detection

```bash
bash scripts/scan.sh os <target>
```

### Script Scanning (NSE)

```bash
# Run specific nmap scripts
bash scripts/scan.sh nse <target> --scripts "http-title,ssl-cert,dns-brute"

# Run all safe scripts
bash scripts/scan.sh nse <target> --scripts safe
```

### Scheduled Monitoring

```bash
# Add to crontab — scan network every hour, alert on changes
bash scripts/scan.sh monitor --install-cron

# This creates:
# */60 * * * * bash /path/to/scan.sh discover --diff last --alert
```

## Troubleshooting

### "nmap: command not found"

```bash
bash scripts/install.sh
```

### "Permission denied" or "requires root"

Some scans (SYN, OS detection) need root:
```bash
sudo bash scripts/scan.sh ports <target> --stealth
```

### Scan is very slow

Use quick mode for large networks:
```bash
bash scripts/scan.sh discover --fast    # ARP ping only
bash scripts/scan.sh ports <target> -T4 # Aggressive timing
```

### False positives in vulnerability scan

Nmap's vuln scripts can be noisy. Verify critical findings manually:
```bash
# Check a specific CVE
bash scripts/scan.sh nse <target> --scripts "vuln-CVE-2023-38408"
```

## Dependencies

- `bash` (4.0+)
- `nmap` (7.80+) — installed by scripts/install.sh
- Optional: `xsltproc` (for HTML reports)
- Optional: `jq` (for JSON processing)
