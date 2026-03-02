---
name: ip-blocklist-manager
description: >-
  Download threat intelligence blocklists and block malicious IPs with iptables/nftables/ufw. Auto-update daily.
categories: [security, automation]
dependencies: [bash, curl, ipset, iptables]
---

# IP Blocklist Manager

## What This Does

Automatically downloads curated threat intelligence IP blocklists (botnets, scanners, spammers, brute-forcers), loads them into Linux ipset/iptables, and keeps them updated on a schedule. Blocks thousands of known-bad IPs with zero manual effort.

**Example:** "Download 5 blocklists covering 50,000+ malicious IPs, load into ipset, auto-update every 6 hours, get alerts on blocked traffic."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Most Linux systems have iptables. Install ipset for efficient bulk blocking:
sudo apt-get install -y ipset curl   # Debian/Ubuntu
# OR
sudo yum install -y ipset curl       # RHEL/CentOS
# OR
sudo pacman -S ipset curl            # Arch
```

### 2. Run First Blocklist Update

```bash
# Download blocklists and apply — requires root/sudo
sudo bash scripts/blocklist.sh update

# Output:
# [2026-03-02 20:00:00] 📥 Downloading firehol_level1... 2,847 IPs
# [2026-03-02 20:00:01] 📥 Downloading spamhaus_drop... 1,124 IPs  
# [2026-03-02 20:00:02] 📥 Downloading blocklist_de... 18,432 IPs
# [2026-03-02 20:00:03] 📥 Downloading emerging_threats... 4,291 IPs
# [2026-03-02 20:00:04] 📥 Downloading dshield_top20... 620 IPs
# [2026-03-02 20:00:05] ✅ Loaded 27,314 unique IPs into ipset 'blocklist'
# [2026-03-02 20:00:05] 🔒 iptables DROP rule active for set 'blocklist'
```

### 3. Verify It's Working

```bash
# Check how many IPs are blocked
sudo bash scripts/blocklist.sh status

# Test if a known-bad IP is blocked
sudo bash scripts/blocklist.sh check 185.220.101.1

# View recent blocked connections (requires logging enabled)
sudo bash scripts/blocklist.sh log --tail 20
```

## Core Workflows

### Workflow 1: Update Blocklists

**Use case:** Refresh all blocklists with latest threat intelligence

```bash
sudo bash scripts/blocklist.sh update
```

**Flags:**
- `--lists firehol,spamhaus` — Update specific lists only
- `--dry-run` — Download and parse but don't apply
- `--verbose` — Show per-IP details

### Workflow 2: Check Blocklist Status

```bash
sudo bash scripts/blocklist.sh status

# Output:
# IP Blocklist Manager — Status
# ─────────────────────────────
# Active set:    blocklist (27,314 entries)
# Last updated:  2026-03-02 20:00:05 UTC
# Lists enabled: 5/5
# iptables rule: ACTIVE (INPUT chain, position 1)
# Blocked today: 847 connections
```

### Workflow 3: Whitelist an IP

**Use case:** Exclude a legitimate IP that appears on a blocklist

```bash
# Add to whitelist (persists across updates)
sudo bash scripts/blocklist.sh whitelist add 203.0.113.50

# Remove from whitelist
sudo bash scripts/blocklist.sh whitelist remove 203.0.113.50

# Show whitelist
sudo bash scripts/blocklist.sh whitelist list
```

### Workflow 4: Check if IP is Blocked

```bash
sudo bash scripts/blocklist.sh check 185.220.101.1

# Output:
# ⛔ 185.220.101.1 is BLOCKED
# Found in: firehol_level1, blocklist_de
# Reason: Known Tor exit node / brute-force attacker
```

### Workflow 5: Enable Logging

```bash
# Log blocked connections (adds LOG rule before DROP)
sudo bash scripts/blocklist.sh logging on

# View blocked traffic
sudo bash scripts/blocklist.sh log --tail 50

# Output:
# Mar 02 20:15:33 BLOCKLIST_DROP: IN=eth0 SRC=185.220.101.1 DST=10.0.0.5 PROTO=TCP DPT=22
# Mar 02 20:15:34 BLOCKLIST_DROP: IN=eth0 SRC=45.33.32.156 DST=10.0.0.5 PROTO=TCP DPT=443
```

### Workflow 6: Schedule Auto-Updates

```bash
# Install cron job (updates every 6 hours)
sudo bash scripts/blocklist.sh cron install

# Custom interval
sudo bash scripts/blocklist.sh cron install --interval 12h

# Remove cron job
sudo bash scripts/blocklist.sh cron remove
```

## Configuration

### Config File

```bash
# Copy default config
sudo cp scripts/blocklist.conf /etc/blocklist-manager.conf

# Edit to customize
sudo nano /etc/blocklist-manager.conf
```

### Config Options (`/etc/blocklist-manager.conf`)

```bash
# ── Blocklist Sources ──
# Uncomment/comment to enable/disable lists
LISTS=(
  "firehol_level1|https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset"
  "spamhaus_drop|https://www.spamhaus.org/drop/drop.txt"
  "spamhaus_edrop|https://www.spamhaus.org/drop/edrop.txt"
  "blocklist_de|https://lists.blocklist.de/lists/all.txt"
  "emerging_threats|https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"
  "dshield_top20|https://www.dshield.org/block.txt"
  "abuse_ch_feodo|https://feodotracker.abuse.ch/downloads/ipblocklist.txt"
  # "cinsscore|https://cinsscore.com/list/ci-badguys.txt"          # Optional: CI Army
  # "bruteforce|https://danger.rulez.sk/projects/bruteforceblocker/blist.php"  # Optional
)

# ── ipset Configuration ──
IPSET_NAME="blocklist"
IPSET_MAXELEM=200000          # Max IPs in set
IPSET_TIMEOUT=0               # 0 = permanent until next update

# ── iptables Configuration ──
CHAIN="INPUT"                  # Chain to add DROP rule
POSITION=1                     # Position in chain (1 = first rule)
LOG_PREFIX="BLOCKLIST_DROP: "  # Prefix for logged drops
ENABLE_LOGGING=false           # Set true to log before dropping

# ── Whitelist ──
WHITELIST_FILE="/etc/blocklist-whitelist.txt"

# ── Paths ──
DATA_DIR="/var/lib/blocklist-manager"
LOG_FILE="/var/log/blocklist-manager.log"

# ── Alerts (optional) ──
# TELEGRAM_BOT_TOKEN=""
# TELEGRAM_CHAT_ID=""
# ALERT_THRESHOLD=1000          # Alert if >N blocks in 1 hour
```

## Advanced Usage

### Use with UFW

```bash
# If using UFW instead of raw iptables:
sudo bash scripts/blocklist.sh update --backend ufw

# This creates UFW rules from the blocklist
# Note: UFW is slower with large lists — ipset+iptables recommended
```

### Use with nftables

```bash
# For systems using nftables:
sudo bash scripts/blocklist.sh update --backend nftables
```

### Export Blocked IPs

```bash
# Export current blocklist to file
sudo bash scripts/blocklist.sh export > blocked-ips.txt

# Export with source attribution
sudo bash scripts/blocklist.sh export --detailed > blocked-ips-detailed.csv
```

### Statistics

```bash
# Show blocking statistics
sudo bash scripts/blocklist.sh stats

# Output:
# Blocklist Statistics (last 24h)
# ────────────────────────────────
# Total blocked:     2,847 connections
# Top source IPs:
#   185.220.101.1    — 342 attempts (Tor exit, SSH brute-force)
#   45.33.32.156     — 218 attempts (Port scanner)
#   91.240.118.172   — 156 attempts (Spam relay)
# Top target ports:
#   22 (SSH)         — 1,203 (42%)
#   443 (HTTPS)      — 612 (21%)
#   80 (HTTP)        — 498 (17%)
# Lists breakdown:
#   firehol_level1   — 2,847 IPs (matched 1,847 blocks)
#   blocklist_de     — 18,432 IPs (matched 642 blocks)
```

## Troubleshooting

### Issue: "ipset: command not found"

```bash
sudo apt-get install ipset    # Debian/Ubuntu
sudo yum install ipset        # RHEL/CentOS
```

### Issue: "iptables: Permission denied"

Run with sudo: `sudo bash scripts/blocklist.sh update`

### Issue: ipset set full (maxelem reached)

Edit config: increase `IPSET_MAXELEM` to 500000, then re-run update.

### Issue: Legitimate traffic blocked

```bash
# Check if IP is in blocklist
sudo bash scripts/blocklist.sh check <ip>

# Add to whitelist
sudo bash scripts/blocklist.sh whitelist add <ip>

# Force update to apply whitelist
sudo bash scripts/blocklist.sh update
```

### Issue: Rules don't survive reboot

```bash
# Install persistence (saves/restores ipset + iptables on boot)
sudo bash scripts/blocklist.sh persist install
```

## Blocklist Sources

| List | Focus | Size | Update Freq |
|------|-------|------|-------------|
| FireHOL Level 1 | Worst-of-the-worst attackers | ~3K IPs | 4x daily |
| Spamhaus DROP | Hijacked IP ranges | ~1K CIDRs | Daily |
| Spamhaus EDROP | Extended DROP | ~200 CIDRs | Daily |
| Blocklist.de | Reported attackers (SSH, FTP, mail) | ~18K IPs | Hourly |
| Emerging Threats | Active threat IPs | ~4K IPs | 4x daily |
| DShield Top 20 | Top attacking subnets | ~600 IPs | Daily |
| Abuse.ch Feodo | Banking trojan C2 servers | ~300 IPs | 4x daily |

## Key Principles

1. **ipset for performance** — Hash-based lookups, O(1) per packet vs O(n) for iptables rules
2. **Whitelist first** — Always check whitelist before blocking
3. **Atomic updates** — Build new set, swap in — zero downtime
4. **Log sparingly** — Logging every drop is expensive; enable only when debugging
5. **Persist across reboot** — Use ipset save/restore + iptables-persistent

## Dependencies

- `bash` (4.0+)
- `curl` (downloading lists)
- `ipset` (efficient IP set management)
- `iptables` or `nftables` (firewall rules)
- `grep`, `sed`, `sort` (text processing)
- Optional: `jq` (for JSON stats export)
