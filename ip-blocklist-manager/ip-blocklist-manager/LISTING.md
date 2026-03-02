# Listing Copy: IP Blocklist Manager

## Metadata
- **Type:** Skill
- **Name:** ip-blocklist-manager
- **Display Name:** IP Blocklist Manager
- **Categories:** [security, automation]
- **Price:** $15
- **Dependencies:** [bash, curl, ipset, iptables]
- **Icon:** 🛡️

## Tagline

Block malicious IPs automatically — Threat intel feeds to firewall rules in 5 minutes

## Description

Your server is under constant attack. Bots, scanners, and brute-force scripts probe every exposed port 24/7. Manually blocking IPs is futile — there are millions of known bad actors.

IP Blocklist Manager downloads IP blocklists from 6 public threat intelligence feeds (Spamhaus, Blocklist.de, Emerging Threats, DShield, FireHOL), deduplicates them, and applies firewall rules using ipset + iptables/nftables. One command blocks 25,000+ known malicious IPs. Scheduled updates keep your blocklist fresh every 6 hours.

**What it does:**
- 🛡️ Block 25,000+ malicious IPs from 6 threat intelligence feeds
- ⏱️ Auto-update every 6 hours via cron (atomic swap, zero downtime)
- 🔍 Check if any IP is blocked and which feed flagged it
- ✅ Whitelist legitimate IPs to prevent false positives
- 📊 View statistics: blocked count, feed breakdown, connection logs
- 🔥 Supports both iptables and nftables backends
- 📤 Export blocklists for use in other tools
- 🔔 Optional Telegram notifications on updates

Perfect for sysadmins, VPS owners, and anyone running internet-facing servers who wants automated threat protection without paying for enterprise solutions.

## Quick Start Preview

```bash
# Download 6 threat feeds + apply firewall rules
sudo bash scripts/run.sh --init

# Output:
# 📥 Downloading blocklists...
#   ✅ spamhaus-drop: 824 IPs
#   ✅ blocklist-de: 15,432 IPs
#   ✅ firehol-level1: 8,234 IPs
# 📊 Total unique entries: 24,891
# 🛡️ Applied to ipset 'blocklist'
# 🔥 iptables DROP rule active
# ✅ Done. 24,891 IPs blocked.
```

## Core Capabilities

1. Multi-feed aggregation — Pulls from Spamhaus, Blocklist.de, Emerging Threats, DShield, FireHOL
2. Atomic updates — ipset swap ensures zero-gap protection during updates
3. IP checking — Verify if any IP is blocked and trace it to the source feed
4. Whitelist management — Exclude legitimate IPs with one command
5. Dual firewall support — Works with iptables or nftables
6. Cron-ready — Install auto-update schedule with one command
7. Connection logging — Log blocked attempts to syslog/journald
8. Custom feeds — Add your own threat intelligence URLs
9. Export/import — Dump blocklists for backup or cross-server use
10. Clean uninstall — Remove all rules, sets, and cron jobs instantly

## Dependencies
- `bash` (4.0+)
- `curl`
- `ipset`
- `iptables` or `nftables`
- Root/sudo access

## Installation Time
**5 minutes** — Install deps, run init, set up cron
