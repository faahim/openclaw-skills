# Listing Copy: Pi-hole DNS Manager

## Metadata
- **Type:** Skill
- **Name:** pihole-dns-manager
- **Display Name:** Pi-hole DNS Manager
- **Categories:** [home, security]
- **Price:** $12
- **Icon:** 🛡️
- **Dependencies:** [bash, curl, jq, pihole]

## Tagline

Block ads network-wide with Pi-hole — install, manage blocklists, and monitor DNS stats from your agent

## Description

Manually configuring DNS-level ad blocking is tedious. Installing Pi-hole, curating blocklists, whitelisting broken domains, and monitoring query stats across devices — it all adds up. You need a way to manage it without constantly SSH-ing into your server.

Pi-hole DNS Manager lets your OpenClaw agent install, configure, and fully manage Pi-hole. Add blocklist packs (malware, tracking, social, aggressive ads) with one command. Whitelist/blacklist domains instantly. Get daily DNS query reports sent to Telegram. Back up and restore your config. Manage local DNS records and CNAME entries. All from your agent — no web UI required.

**What it does:**
- 🛡️ One-command Pi-hole installation (automated or interactive)
- 📋 Curated blocklist packs — malware, tracking, social media, aggressive ads
- ✅ Whitelist/blacklist management with file import support
- 📊 DNS query stats — top blocked, top permitted, top clients
- 🔔 Daily reports via Telegram with cron scheduling
- 💾 Backup and restore Pi-hole config
- 🌐 Local DNS and CNAME record management
- 🔤 Regex-based domain filtering
- ⏸️ Temporary disable with auto-re-enable

Perfect for homelab enthusiasts, sysadmins, and anyone who wants network-wide ad blocking without per-device setup.

## Quick Start Preview

```bash
# Install Pi-hole
sudo bash scripts/install.sh

# Check status
bash scripts/pihole-manager.sh status

# Add malware + tracking blocklists
sudo bash scripts/pihole-manager.sh blocklist-pack malware
sudo bash scripts/pihole-manager.sh blocklist-pack tracking
sudo bash scripts/pihole-manager.sh gravity-update
```

## Core Capabilities

1. Automated Pi-hole installation — handles systemd-resolved conflicts, sets sensible defaults
2. Blocklist pack management — curated lists for malware, tracking, social, aggressive ads
3. Whitelist/blacklist — single domain, bulk file import, regex patterns
4. DNS query monitoring — top blocked/permitted domains, per-client breakdown
5. Telegram daily reports — automated via cron, HTML-formatted stats
6. Config backup/restore — tar.gz archives of gravity.db, settings, custom lists
7. Local DNS records — point internal domains to local IPs
8. CNAME management — alias domains without editing config files
9. Temporary disable — pause blocking for troubleshooting (auto-re-enable)
10. Self-update — check and apply Pi-hole updates

## Installation Time
**10 minutes** — run install script, point DNS
