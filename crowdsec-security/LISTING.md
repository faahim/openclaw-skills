# Listing Copy: CrowdSec Security Manager

## Metadata
- **Type:** Skill
- **Name:** crowdsec-security
- **Display Name:** CrowdSec Security Manager
- **Categories:** [security, automation]
- **Price:** $15
- **Dependencies:** [bash, curl, jq, systemd]
- **Icon:** 🛡️

## Tagline

Collaborative intrusion prevention — detect attacks, ban IPs, share threat intelligence automatically.

## Description

Your server logs are full of attackers you're ignoring. SSH brute-force bots hammer your port 22 every hour. Scanners probe your web server for vulnerabilities around the clock. Most go unnoticed until something breaks.

CrowdSec Security Manager installs and configures CrowdSec — an open-source, community-powered intrusion prevention system. It watches your logs in real-time, detects attack patterns (brute force, port scans, web exploits), and automatically bans malicious IPs. The killer feature: threat intelligence is shared across the entire CrowdSec community, so when one server detects an attacker, yours is already protected.

**What it does:**
- 🛡️ Install CrowdSec engine with one command
- 🔥 Auto-detect and protect SSH, Nginx, Apache
- 🚫 Block attackers via iptables, Nginx, or Cloudflare
- 🌍 Subscribe to community blocklists (50,000+ known bad IPs)
- 📱 Telegram/Slack alerts on every ban
- 📋 Whitelist trusted IPs and CIDRs
- 📊 Real-time status dashboard and metrics
- 💾 Backup and restore configurations
- 🔧 Create custom detection scenarios

Perfect for anyone running a VPS, homelab, or production server who wants real security beyond basic firewalls.

## Quick Start Preview

```bash
# Install CrowdSec
bash scripts/install.sh

# Add firewall blocking
bash scripts/setup-bouncer.sh firewall

# Check status
bash scripts/status.sh
# → Engine: ✅ Running | Bouncers: 1 active | Last 24h: 12 bans
```

## Core Capabilities

1. One-command install — Debian/Ubuntu, RHEL/CentOS, Fedora, Alpine
2. Auto-detection — Finds and configures SSH, Nginx, Apache automatically
3. Firewall bouncer — Ban via iptables/nftables at the OS level
4. Nginx bouncer — Return 403 to banned IPs at the web server
5. Cloudflare bouncer — Block at the CDN edge before traffic hits your server
6. Community blocklists — 50,000+ known malicious IPs, updated continuously
7. Telegram alerts — Get notified on every detected attack with IP, country, scenario
8. Whitelist management — Protect trusted IPs from false positive bans
9. Custom scenarios — Define your own detection rules (rate limiting, custom patterns)
10. Backup & restore — Full config export/import for server migrations
11. Prometheus metrics — Integrate with Grafana for visual dashboards
12. Multi-server support — Centralized detection across your fleet
