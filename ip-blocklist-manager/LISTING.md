# Listing Copy: IP Blocklist Manager

## Metadata
- **Type:** Skill
- **Name:** ip-blocklist-manager
- **Display Name:** IP Blocklist Manager
- **Categories:** [security, automation]
- **Price:** $15
- **Dependencies:** [bash, curl, ipset, iptables]

## Tagline

Block thousands of malicious IPs automatically — threat intel blocklists for Linux firewalls

## Description

Every server gets hammered by botnets, port scanners, brute-forcers, and spammers. Most of these attacks come from known-bad IPs that are already catalogued by threat intelligence feeds. Why let them even reach your services?

IP Blocklist Manager downloads curated threat intelligence feeds (FireHOL, Spamhaus, Blocklist.de, Emerging Threats, DShield, Abuse.ch), deduplicates them, loads 25,000+ malicious IPs into Linux ipset for O(1) packet filtering, and keeps them updated automatically. One command to set up, zero ongoing maintenance.

**What it does:**
- 🛡️ Block 25,000+ known-malicious IPs from 7 curated threat feeds
- ⚡ ipset hash tables — O(1) lookup per packet, zero performance impact
- 🔄 Auto-update via cron (every 6h by default)
- 📋 Whitelist management — never accidentally block legitimate IPs
- 📊 Statistics — see what's being blocked and from where
- 🔔 Optional Telegram alerts on updates
- 💾 Persist across reboots with systemd
- 🧹 Clean uninstall — one command removes everything

Perfect for VPS operators, self-hosters, sysadmins, and anyone running internet-facing services who wants automated protection from known threats.

## Quick Start Preview

```bash
# Download blocklists and apply
sudo bash scripts/blocklist.sh update

# Check status
sudo bash scripts/blocklist.sh status

# Auto-update every 6 hours
sudo bash scripts/blocklist.sh cron install
```

## Core Capabilities

1. Multi-source blocklists — 7 curated threat intelligence feeds included
2. ipset performance — Hash-based O(1) lookups, handles 200K+ IPs effortlessly
3. Atomic updates — Zero-downtime swap, never unprotected during refresh
4. Whitelist management — Persistent whitelist survives updates
5. IP lookup — Check if any IP is blocked and which lists flagged it
6. Traffic logging — Optional kernel-level logging of blocked connections
7. Cron scheduling — Auto-update every 1/6/12/24 hours
8. Reboot persistence — systemd service restores rules on boot
9. Telegram alerts — Get notified on blocklist updates
10. Clean uninstall — Remove all rules, sets, and cron jobs in one command

## Dependencies
- `bash` (4.0+)
- `curl`
- `ipset`
- `iptables`

## Installation Time
**5 minutes** — install ipset, run update, install cron

## Pricing Justification

**Why $15:**
- Comparable to SaaS: CrowdSec free tier, Fail2ban free but reactive-only
- Our advantage: Proactive blocking (block BEFORE attack), no signup, no external services
- Complexity: Medium (ipset, iptables, cron, systemd, multiple feed parsers)
- Value: Blocks thousands of attacks/day automatically
