---
name: adguard-home
description: >-
  Install, configure, and manage AdGuard Home DNS ad-blocker from the command line.
categories: [home, security]
dependencies: [curl, jq, bash]
---

# AdGuard Home Manager

## What This Does

Installs and manages [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) — a network-wide DNS ad-blocker and privacy server. Block ads, trackers, and malware at the DNS level for your entire network. Manage filter lists, custom rules, clients, and DNS settings from the CLI.

**Example:** "Install AdGuard Home on my server, add the Steven Black hosts list, block facebook.com for the kids' devices, and check query stats."

## Quick Start (5 minutes)

### 1. Install AdGuard Home

```bash
# Binary install (recommended for bare metal / VPS)
sudo bash scripts/install.sh binary

# Docker install (if you prefer containers)
bash scripts/install.sh docker
```

After install, open the web UI at `http://<your-ip>:3000` to complete initial setup (set admin password).

### 2. Configure CLI Access

```bash
# Set your credentials
export AGH_HOST="http://localhost"
export AGH_PORT="3000"
export AGH_USER="admin"
export AGH_PASS="your-password-here"

# Add to ~/.bashrc for persistence
echo 'export AGH_HOST="http://localhost"' >> ~/.bashrc
echo 'export AGH_PORT="3000"' >> ~/.bashrc
echo 'export AGH_USER="admin"' >> ~/.bashrc
echo 'export AGH_PASS="your-password"' >> ~/.bashrc
```

### 3. Check Status

```bash
bash scripts/run.sh status
# Output:
# [2026-02-28 18:00:00] AdGuard Home Status:
#   Version:    v0.107.55
#   Running:    true
#   DNS Port:   53
#   HTTP Port:  3000
#   Protection: true
```

## Core Workflows

### Workflow 1: View Statistics & Query Log

```bash
# 24-hour stats overview
bash scripts/run.sh stats
# Output:
#   Total queries:      12,847
#   Blocked:            3,201
#   Blocked (%):        24.91%
#   Avg response (ms):  12

# Top queried/blocked domains and clients
bash scripts/run.sh top

# Recent query log
bash scripts/run.sh query-log 50
# Output:
# 18:42:01 ✅ google.com ← 192.168.1.5
# 18:42:00 ❌ ads.tracker.com ← 192.168.1.12
# 18:41:58 ✅ github.com ← 192.168.1.5
```

### Workflow 2: Manage Filter Lists

```bash
# List current filters
bash scripts/run.sh list-filters

# Add popular filter lists
bash scripts/run.sh add-filter "Steven Black Hosts" \
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

bash scripts/run.sh add-filter "OISD Big" \
  "https://big.oisd.nl"

bash scripts/run.sh add-filter "Hagezi Pro" \
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt"

# Force refresh all filters
bash scripts/run.sh refresh-filters

# Remove a filter
bash scripts/run.sh remove-filter "https://big.oisd.nl"
```

### Workflow 3: Block & Allow Domains

```bash
# Block a specific domain
bash scripts/run.sh block ads.example.com

# Whitelist a domain (override filter blocks)
bash scripts/run.sh allow login.microsoftonline.com

# Add custom adblock-syntax rule
bash scripts/run.sh add-rule "||doubleclick.net^"

# View all custom rules
bash scripts/run.sh list-rules
```

### Workflow 4: Temporarily Disable Protection

```bash
# Disable for 5 minutes (e.g., debugging connectivity)
bash scripts/run.sh disable 300

# Disable indefinitely
bash scripts/run.sh disable

# Re-enable
bash scripts/run.sh enable
```

### Workflow 5: Configure Upstream DNS

```bash
# Use DNS-over-HTTPS (Cloudflare + Google)
bash scripts/run.sh set-upstream \
  "https://dns.cloudflare.com/dns-query" \
  "https://dns.google/dns-query"

# Use Quad9 (malware blocking)
bash scripts/run.sh set-upstream \
  "https://dns.quad9.net/dns-query"

# Test upstream connectivity
bash scripts/run.sh test-upstream

# View full DNS config
bash scripts/run.sh dns-config
```

### Workflow 6: Health Check & Backup

```bash
# Run health check
bash scripts/run.sh health
# Output:
#   Service:     ✅ Running
#   DNS Resolve: ✅ Working
#   Oldest filter: 2026-02-27T12:00:00Z
#   Queries (24h): 12847 | Blocked: 3201

# Backup configuration
bash scripts/run.sh backup ./my-backups
# Creates: ./my-backups/adguard_backup_20260228_180000.json
```

## Configuration

### Environment Variables

```bash
AGH_HOST="http://localhost"   # AdGuard Home host
AGH_PORT="3000"               # Web API port
AGH_USER="admin"              # Admin username
AGH_PASS="your-password"      # Admin password
ADGUARD_INSTALL_DIR="/opt/AdGuardHome"  # Install location (for install.sh)
```

### Recommended Filter Lists

| List | URL | Rules | Focus |
|------|-----|-------|-------|
| AdGuard DNS | Built-in | ~50k | General ad/tracker blocking |
| Steven Black | `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts` | ~90k | Unified hosts |
| OISD Big | `https://big.oisd.nl` | ~200k | Comprehensive |
| Hagezi Pro | `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt` | ~180k | Pro blocking |
| 1Hosts Lite | `https://o0.pages.dev/Lite/adblock.txt` | ~80k | Lightweight |

## Advanced Usage

### Run as OpenClaw Cron Job

Monitor AdGuard Home health on a schedule:

```bash
# Check health every 30 minutes
# In your OpenClaw cron, run:
bash scripts/run.sh health

# Daily stats report
bash scripts/run.sh stats

# Weekly backup
bash scripts/run.sh backup /path/to/backups
```

### Point Your Network to AdGuard Home

After installation, configure your router or devices to use your server's IP as DNS:

```bash
# On Linux clients
sudo resolvectl dns eth0 <server-ip>

# Or edit /etc/resolv.conf
echo "nameserver <server-ip>" | sudo tee /etc/resolv.conf
```

### Docker Compose Setup

```yaml
# docker-compose.yml
services:
  adguardhome:
    image: adguard/adguardhome:latest
    restart: always
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "3000:3000/tcp"
    volumes:
      - ./data/work:/opt/adguardhome/work
      - ./data/conf:/opt/adguardhome/conf
```

## Troubleshooting

### Issue: Port 53 already in use

```bash
# Check what's using port 53
sudo ss -tlnp | grep :53

# On Ubuntu, disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
sudo rm /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

### Issue: API connection refused

```bash
# Check if AdGuard Home is running
sudo systemctl status AdGuardHome
# or for Docker:
docker ps | grep adguard

# Verify port
curl -s http://localhost:3000/control/status
```

### Issue: Filters not updating

```bash
# Force refresh
bash scripts/run.sh refresh-filters

# Check filter status
bash scripts/run.sh list-filters
```

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to AdGuard Home API)
- `jq` (JSON parsing)
- `dig` (optional, for health check DNS test)
- `tar` (for binary installation)
- `docker` (optional, for Docker installation)
