# Listing Copy: IP Blocklist Manager

## Metadata
- **Type:** Skill
- **Name:** ip-blocklist-manager
- **Display Name:** IP Blocklist Manager
- **Categories:** [security, automation]
- **Icon:** 🛡️
- **Dependencies:** [bash, curl, ipset, iptables]

## Tagline

Block malicious IPs automatically — threat intel feeds to iptables in one command

## Description

Your server gets hit by bots, scanners, and known attackers 24/7. Manually maintaining blocklists is tedious and always out of date. You need automated, always-current protection.

IP Blocklist Manager downloads threat intelligence feeds from trusted sources (Spamhaus DROP, abuse.ch, Emerging Threats, DShield, blocklist.de), deduplicates them, and loads them into Linux ipset/iptables rules. One command blocks thousands of known-malicious IPs at the kernel level. Schedule auto-updates every 6 hours and forget about it.

**What it does:**
- 🛡️ Block 5,000-50,000+ malicious IPs from 8 threat intelligence feeds
- ⏱️ Auto-update every 6 hours via cron or systemd timer
- 📋 Whitelist your own IPs to prevent accidental blocking
- 📊 Track blocked connections and view stats
- 🔧 Persist rules across reboots
- ➕ Add custom blocklist feeds
- 🗑️ Clean uninstall — remove everything with one command

Perfect for anyone running a VPS, home server, or production infrastructure who wants automated IP-level threat protection without external services or subscriptions.

## Quick Start Preview

```bash
# Block malicious IPs from 8 threat feeds
sudo bash scripts/run.sh --apply

# [2026-03-01 20:00:00] ✓ spamhaus-drop: 842 IPs
# [2026-03-01 20:00:02] ✓ abusech-feodo: 1,247 IPs
# [2026-03-01 20:00:04] ✅ Loaded 5,980 IPs into ipset 'ip-blocklist'
```

## Core Capabilities

1. Multi-feed aggregation — 8 trusted threat intelligence sources out of the box
2. ipset + iptables — kernel-level blocking, zero performance impact
3. Auto-deduplication — no duplicate rules, clean blocklist
4. Whitelist support — never accidentally block your own IPs
5. Dry run mode — preview what gets blocked before applying
6. Cron & systemd — schedule auto-updates your way
7. Reboot persistence — rules survive restarts
8. Custom feeds — add your own blocklist URLs
9. Block logging — see what's getting caught
10. Clean uninstall — remove everything in one command

## Dependencies
- `bash` (4.0+), `curl`, `ipset`, `iptables`
- Requires root/sudo for firewall operations

## Installation Time
**5 minutes** — install ipset, configure feeds, run
