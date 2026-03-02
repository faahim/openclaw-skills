---
name: ip-blocklist-manager
description: >-
  Download, manage, and apply IP blocklists from public threat intelligence feeds.
  Automatically block malicious IPs using ipset + iptables/nftables.
categories: [security, automation]
dependencies: [bash, curl, ipset, iptables]
---

# IP Blocklist Manager

## What This Does

Automatically downloads IP blocklists from public threat intelligence feeds (Spamhaus, AbuseIPDB, Blocklist.de, Emerging Threats, etc.), aggregates them into ipset sets, and applies firewall rules to block malicious traffic. Runs on a schedule to keep blocklists fresh.

**Example:** "Block 50,000+ known malicious IPs from 8 threat feeds, auto-update every 6 hours, log blocked connections."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Check/install required tools
sudo apt-get update && sudo apt-get install -y ipset iptables curl gzip

# Verify
which ipset iptables curl && echo "✅ Dependencies ready"
```

### 2. Initial Setup

```bash
# Create working directories
sudo mkdir -p /etc/ip-blocklist /var/log/ip-blocklist /var/lib/ip-blocklist

# Copy config
sudo cp scripts/config.sh /etc/ip-blocklist/config.sh

# Run initial blocklist download + apply
sudo bash scripts/run.sh --init
```

### 3. Schedule Auto-Updates

```bash
# Update blocklists every 6 hours
sudo bash scripts/run.sh --install-cron

# Or manually add to crontab:
# 0 */6 * * * /path/to/scripts/run.sh --update >> /var/log/ip-blocklist/update.log 2>&1
```

## Core Workflows

### Workflow 1: Download & Apply All Feeds

**Use case:** First-time setup — download all configured threat feeds and apply blocklist.

```bash
sudo bash scripts/run.sh --init
```

**Output:**
```
[2026-03-02 21:00:00] 📥 Downloading blocklists...
[2026-03-02 21:00:01]   ✅ spamhaus-drop: 824 IPs
[2026-03-02 21:00:02]   ✅ spamhaus-edrop: 213 IPs
[2026-03-02 21:00:03]   ✅ blocklist-de: 15,432 IPs
[2026-03-02 21:00:04]   ✅ emerging-threats: 2,891 IPs
[2026-03-02 21:00:05]   ✅ dshield-top20: 20 networks
[2026-03-02 21:00:05]   ✅ firehol-level1: 8,234 IPs
[2026-03-02 21:00:06] 🔄 Deduplicating...
[2026-03-02 21:00:06] 📊 Total unique entries: 24,891
[2026-03-02 21:00:07] 🛡️  Applied to ipset 'blocklist'
[2026-03-02 21:00:07] 🔥 iptables DROP rule active
[2026-03-02 21:00:07] ✅ Done. 24,891 IPs blocked.
```

### Workflow 2: Update Blocklists

**Use case:** Refresh blocklists from all feeds (run via cron).

```bash
sudo bash scripts/run.sh --update
```

**Output:**
```
[2026-03-02 03:00:00] 📥 Updating blocklists...
[2026-03-02 03:00:05] 📊 Previous: 24,891 | New: 25,102 | Added: 342 | Removed: 131
[2026-03-02 03:00:06] 🛡️  ipset updated (atomic swap)
[2026-03-02 03:00:06] ✅ Update complete.
```

### Workflow 3: Check If an IP Is Blocked

**Use case:** Verify if a specific IP is in the blocklist.

```bash
sudo bash scripts/run.sh --check 185.220.101.34
```

**Output:**
```
🚫 185.220.101.34 IS in blocklist
   Source: blocklist-de (added 2026-03-01)
   Category: SSH brute-force
```

### Workflow 4: Whitelist an IP

**Use case:** Exclude a legitimate IP from being blocked.

```bash
sudo bash scripts/run.sh --whitelist 203.0.113.50
```

**Output:**
```
✅ 203.0.113.50 added to whitelist
   Will be excluded from all future blocklist updates.
```

### Workflow 5: View Statistics

```bash
sudo bash scripts/run.sh --stats
```

**Output:**
```
📊 IP Blocklist Statistics
━━━━━━━━━━━━━━━━━━━━━━━━━
Total blocked IPs:     25,102
Active feeds:          6/6
Last update:           2026-03-02 03:00:06
Next update:           2026-03-02 09:00:00

Feed breakdown:
  spamhaus-drop:       824
  spamhaus-edrop:      213
  blocklist-de:        15,432
  emerging-threats:    2,891
  dshield-top20:       20 (networks)
  firehol-level1:      8,234

Whitelist entries:     3
Last 24h blocked:      1,247 connections (from iptables LOG)
```

### Workflow 6: Remove Blocklist (Uninstall)

```bash
sudo bash scripts/run.sh --remove
```

**Output:**
```
🗑️  Removing IP blocklist...
   ✅ iptables rules removed
   ✅ ipset set destroyed
   ✅ Cron job removed
   ✅ Clean uninstall complete.
```

## Configuration

### Config File (/etc/ip-blocklist/config.sh)

```bash
# Feeds to download (comment out to disable)
FEEDS=(
  "spamhaus-drop|https://www.spamhaus.org/drop/drop.txt|cidr"
  "spamhaus-edrop|https://www.spamhaus.org/drop/edrop.txt|cidr"
  "blocklist-de|https://lists.blocklist.de/lists/all.txt|ip"
  "emerging-threats|https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt|ip"
  "dshield-top20|https://feeds.dshield.org/block.txt|dshield"
  "firehol-level1|https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset|cidr"
)

# ipset configuration
IPSET_NAME="blocklist"
IPSET_MAXELEM=200000        # Max entries (increase for more feeds)
IPSET_HASHSIZE=16384        # Hash table size

# Firewall chain
CHAIN_NAME="BLOCKLIST"
LOG_BLOCKED=true            # Log blocked connections to syslog
LOG_PREFIX="[BLOCKED] "

# Whitelist file
WHITELIST_FILE="/etc/ip-blocklist/whitelist.txt"

# Update schedule (used by --install-cron)
CRON_SCHEDULE="0 */6 * * *"  # Every 6 hours

# Data directory
DATA_DIR="/var/lib/ip-blocklist"
LOG_DIR="/var/log/ip-blocklist"

# Notification (optional)
NOTIFY_ON_UPDATE=false
# TELEGRAM_BOT_TOKEN=""
# TELEGRAM_CHAT_ID=""
```

### Whitelist File (/etc/ip-blocklist/whitelist.txt)

```
# One IP or CIDR per line
# Lines starting with # are comments
203.0.113.50
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
```

## Advanced Usage

### Add Custom Feed

Edit `/etc/ip-blocklist/config.sh` and add to FEEDS array:

```bash
FEEDS+=(
  "my-custom-feed|https://example.com/blocklist.txt|ip"
)
```

Format types: `ip` (one IP per line), `cidr` (CIDR notation), `dshield` (DShield block format)

### Use with nftables Instead of iptables

```bash
# In config.sh:
FIREWALL_BACKEND="nftables"  # default: "iptables"
```

### Export Blocklist

```bash
# Export current blocklist as plain text
sudo bash scripts/run.sh --export > blocked-ips.txt

# Export as ipset restore format
sudo bash scripts/run.sh --export-ipset > blocklist.ipset
```

### Dry Run (Don't Apply)

```bash
sudo bash scripts/run.sh --update --dry-run
```

Shows what would change without modifying firewall rules.

## Troubleshooting

### Issue: "ipset: command not found"

```bash
sudo apt-get install ipset        # Debian/Ubuntu
sudo yum install ipset             # RHEL/CentOS
sudo pacman -S ipset               # Arch
```

### Issue: "ipset: Hash is full, cannot add more elements"

Increase IPSET_MAXELEM in config:
```bash
IPSET_MAXELEM=500000
sudo bash scripts/run.sh --init  # Recreate with new size
```

### Issue: Legitimate traffic being blocked

1. Check if IP is blocked: `sudo bash scripts/run.sh --check <ip>`
2. Add to whitelist: `sudo bash scripts/run.sh --whitelist <ip>`
3. Force update: `sudo bash scripts/run.sh --update`

### Issue: Feed download fails

Check connectivity and feed URL:
```bash
curl -sI https://www.spamhaus.org/drop/drop.txt
```

Failed feeds are skipped — other feeds still apply. Check logs:
```bash
cat /var/log/ip-blocklist/update.log
```

## Dependencies

- `bash` (4.0+)
- `curl` (downloading feeds)
- `ipset` (managing IP sets)
- `iptables` or `nftables` (firewall rules)
- `gzip` (optional, for compressed feeds)
- Root/sudo access required
