# Listing Copy: Nmap Scanner

## Metadata
- **Type:** Skill
- **Name:** nmap-scanner
- **Display Name:** Nmap Scanner
- **Categories:** [security, dev-tools]
- **Price:** $10
- **Dependencies:** [bash, nmap]
- **Icon:** 🔍

## Tagline

Network discovery and security scanning — find hosts, detect services, check vulnerabilities, and monitor changes with simple commands

## Description

Manually running nmap with cryptic flags every time you need to scan your network is tedious. Remembering the difference between `-sS`, `-sV`, `-O`, and `--script vuln` shouldn't be a prerequisite for basic network security.

**Nmap Scanner** wraps nmap into simple, opinionated commands: `discover` finds all hosts on your LAN, `ports` checks for open ports, `services` identifies running software, and `vuln` checks for known vulnerabilities. Save baselines and diff against them to detect network changes over time. Get Telegram alerts when new hosts appear.

**What you get:**
- 🔍 One-command network discovery — find all devices on your LAN
- 🔓 Port scanning with service version detection
- ⚠️ Vulnerability checking with nmap NSE scripts
- 📊 Baseline diffing — detect new hosts, closed ports, changes
- 🔔 Optional Telegram/webhook alerts on network changes
- 📄 Reports in HTML, JSON, or CSV format
- ⏰ Cron-ready scheduled monitoring

Perfect for sysadmins, security professionals, and anyone who manages servers or home networks.

## Core Capabilities

1. **Network discovery** — ARP ping scan, auto-detect subnet, show hostnames + MAC vendors
2. **Port scanning** — Quick (top 1000), full (all 65535), or specific port ranges
3. **Service detection** — Identify software + versions on open ports
4. **OS fingerprinting** — Detect operating systems with confidence scores
5. **Vulnerability scanning** — Run nmap's NSE vuln scripts against targets
6. **Baseline diffing** — Save scans, compare later, detect changes
7. **Stealth scanning** — SYN scans for less detectable reconnaissance
8. **NSE scripting** — Run any nmap script (safe, vuln, http-*, ssl-*, etc.)
9. **Multi-format reports** — HTML, JSON, CSV output for integration
10. **Scheduled monitoring** — One-command crontab setup for recurring scans
11. **Telegram alerts** — Get notified when network changes are detected

## Quick Start

```bash
# Install nmap + dependencies
bash scripts/install.sh

# Discover hosts on your network
bash scripts/scan.sh discover

# Scan ports on a specific host
bash scripts/scan.sh ports 192.168.1.1

# Check for vulnerabilities
bash scripts/scan.sh vuln 10.0.0.1
```
