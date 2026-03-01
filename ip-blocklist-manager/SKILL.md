---
name: ip-blocklist-manager
description: >-
  Download threat intelligence feeds, manage IP blocklists with ipset/iptables, and auto-update daily to block malicious traffic.
categories: [security, automation]
dependencies: [bash, curl, ipset, iptables, jq]
---

# IP Blocklist Manager

## What This Does

Automatically downloads IP blocklists from threat intelligence feeds (abuse.ch, Spamhaus DROP, Emerging Threats, etc.), loads them into Linux ipset/iptables rules, and schedules daily updates. Blocks malicious IPs at the kernel level — botnets, scanners, known attackers — without any external service or subscription.

**Example:** "Download 5 threat feeds, block 50,000+ malicious IPs, auto-update every 6 hours, log blocked connections."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Most Linux systems already have iptables. Install ipset if missing:
sudo apt-get install -y ipset curl jq  # Debian/Ubuntu
# or
sudo yum install -y ipset curl jq      # RHEL/CentOS
```

### 2. Configure Feeds

```bash
# Copy the default config
cp scripts/config.sh.example scripts/config.sh

# Edit to enable/disable feeds, set alert preferences
nano scripts/config.sh
```

### 3. Run First Blocklist Update

```bash
# Download feeds and apply rules (requires root/sudo)
sudo bash scripts/run.sh --apply

# Output:
# [2026-03-01 20:00:00] Downloading Spamhaus DROP... 842 IPs
# [2026-03-01 20:00:02] Downloading abuse.ch Feodo... 1,247 IPs
# [2026-03-01 20:00:03] Downloading Emerging Threats... 3,891 IPs
# [2026-03-01 20:00:04] Loading 5,980 unique IPs into ipset 'blocklist'
# [2026-03-01 20:00:05] ✅ iptables DROP rule active — blocking 5,980 malicious IPs
```

### 4. Schedule Auto-Updates

```bash
# Add cron job to update every 6 hours
sudo bash scripts/run.sh --install-cron

# Verify:
sudo crontab -l | grep blocklist
# 0 */6 * * * /path/to/scripts/run.sh --apply --quiet >> /var/log/ip-blocklist.log 2>&1
```

## Core Workflows

### Workflow 1: One-Time Block

**Use case:** Quickly block known bad IPs without persistence

```bash
sudo bash scripts/run.sh --apply --no-persist
```

### Workflow 2: Full Setup with Persistence

**Use case:** Production server protection with auto-updates

```bash
# Apply rules + save for reboot persistence + install cron
sudo bash scripts/run.sh --apply --persist --install-cron
```

### Workflow 3: Dry Run (Preview Only)

**Use case:** See what would be blocked without applying

```bash
bash scripts/run.sh --dry-run

# Output:
# [DRY RUN] Would block 5,980 IPs from 3 feeds
# Top sources:
#   Emerging Threats: 3,891
#   abuse.ch Feodo:   1,247
#   Spamhaus DROP:      842
```

### Workflow 4: Check Status

**Use case:** See current blocklist stats

```bash
sudo bash scripts/run.sh --status

# Output:
# Blocklist 'ip-blocklist' active
# Total IPs blocked: 5,980
# Last updated: 2026-03-01 20:00:05
# Feeds: spamhaus-drop, abusech-feodo, emergingthreats
# Blocked today: 142 connection attempts
```

### Workflow 5: Whitelist IPs

**Use case:** Exclude specific IPs or ranges from blocking

```bash
# Add to whitelist
bash scripts/run.sh --whitelist-add 203.0.113.0/24

# Remove from whitelist
bash scripts/run.sh --whitelist-remove 203.0.113.0/24

# View whitelist
bash scripts/run.sh --whitelist-show
```

### Workflow 6: Custom Feed

**Use case:** Add your own blocklist URL

```bash
# Add custom feed
echo "https://example.com/my-blocklist.txt" >> scripts/custom-feeds.txt

# Re-apply
sudo bash scripts/run.sh --apply
```

## Configuration

### Config File (scripts/config.sh)

```bash
# ============================================================
# IP Blocklist Manager Configuration
# ============================================================

# --- Feeds (enable/disable) ---
FEED_SPAMHAUS_DROP=true        # Spamhaus Don't Route Or Peer
FEED_SPAMHAUS_EDROP=true       # Extended DROP
FEED_ABUSECH_FEODO=true        # Feodo Tracker (banking trojans)
FEED_ABUSECH_SSLBL=true        # SSL Blacklist
FEED_EMERGINGTHREATS=true      # Emerging Threats compromised IPs
FEED_BLOCKLIST_DE=true          # blocklist.de (fail2ban aggregated)
FEED_CINSSCORE=false            # CI Army (large list, ~15k IPs)
FEED_DSHIELD=true               # DShield top attackers

# --- ipset settings ---
IPSET_NAME="ip-blocklist"       # Name of the ipset
IPSET_MAXELEM=131072            # Max entries (increase for large lists)
IPSET_TIMEOUT=0                 # 0 = no expiry

# --- Paths ---
DATA_DIR="/var/lib/ip-blocklist"
LOG_FILE="/var/log/ip-blocklist.log"
WHITELIST_FILE="scripts/whitelist.txt"
CUSTOM_FEEDS_FILE="scripts/custom-feeds.txt"

# --- Cron ---
CRON_SCHEDULE="0 */6 * * *"    # Every 6 hours

# --- Logging ---
LOG_BLOCKED=true                # Log blocked connections via iptables LOG
LOG_PREFIX="[BLOCKLIST] "       # Prefix for log entries
```

### Whitelist File (scripts/whitelist.txt)

```
# IPs/CIDRs to never block (one per line)
# Your own server IPs
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
# Add your public IPs here:
# 203.0.113.50
```

## Advanced Usage

### Run as systemd Timer (Alternative to Cron)

```bash
sudo bash scripts/run.sh --install-systemd

# Creates:
# /etc/systemd/system/ip-blocklist.service
# /etc/systemd/system/ip-blocklist.timer
```

### Export Blocked IPs

```bash
# Export current blocklist to file
sudo bash scripts/run.sh --export > blocked-ips.txt

# Export with feed source annotations
sudo bash scripts/run.sh --export --annotated > blocked-ips-annotated.txt
```

### View Block Log

```bash
# Last 50 blocked connections
sudo bash scripts/run.sh --log 50

# Output:
# 2026-03-01 20:15:23 BLOCKED 185.220.101.34 → :443 (Spamhaus DROP)
# 2026-03-01 20:15:45 BLOCKED 45.148.10.22 → :22 (blocklist.de)
```

### Uninstall / Remove Rules

```bash
# Remove all rules and ipset
sudo bash scripts/run.sh --remove

# Remove cron job too
sudo bash scripts/run.sh --remove --remove-cron
```

## Troubleshooting

### Issue: "ipset: command not found"

**Fix:**
```bash
sudo apt-get install ipset    # Debian/Ubuntu
sudo yum install ipset        # RHEL/CentOS
```

### Issue: "iptables: Permission denied"

**Fix:** Run with sudo:
```bash
sudo bash scripts/run.sh --apply
```

### Issue: Legitimate traffic being blocked

**Fix:** Add the IP to whitelist:
```bash
bash scripts/run.sh --whitelist-add <IP>
sudo bash scripts/run.sh --apply  # Re-apply to refresh
```

### Issue: ipset "too many elements"

**Fix:** Increase max elements in config:
```bash
# In scripts/config.sh
IPSET_MAXELEM=262144  # Double the default
```

### Issue: Rules don't survive reboot

**Fix:** Use persist flag:
```bash
sudo bash scripts/run.sh --apply --persist
# This saves ipset and iptables rules for reboot
```

## Dependencies

- `bash` (4.0+)
- `curl` (downloading feeds)
- `ipset` (efficient IP set management)
- `iptables` (firewall rules)
- `jq` (optional, for JSON feeds)
- Optional: `systemd` (for timer-based updates)
- **Requires root/sudo** for firewall operations
