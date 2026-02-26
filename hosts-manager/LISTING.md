# Listing Copy: Hosts File Manager

## Metadata
- **Type:** Skill
- **Name:** hosts-manager
- **Display Name:** Hosts File Manager
- **Categories:** [security, home]
- **Icon:** 🛡️
- **Dependencies:** [bash, curl, grep, awk]

## Tagline
Manage /etc/hosts — block 50K+ ads/trackers, custom DNS, automatic backups

## Description

Tired of ads, trackers, and malware domains slowing down your browsing? Your system's `/etc/hosts` file is the fastest, most reliable way to block them — no browser extension, no external DNS service, no subscriptions.

Hosts File Manager downloads and applies curated blocklists (Steven Black, Energized) with a single command. It blocks 50,000+ ad and tracker domains system-wide, affecting every browser and app. Add custom DNS mappings for your homelab, whitelist domains you need, and restore from automatic backups if anything goes wrong.

**What it does:**
- 🛡️ Block 50K+ ad, tracker, and malware domains system-wide
- 🏠 Add custom DNS mappings (homelab.local → 192.168.1.50)
- ✅ Whitelist domains that should never be blocked
- 💾 Automatic backup before every change
- 🔄 One-command blocklist updates
- 🔍 Search and list blocked domains
- ⏪ Instant restore from any backup
- 🧹 Flush DNS cache across Linux/macOS

Perfect for developers, sysadmins, homelab enthusiasts, and anyone who wants system-wide ad blocking without third-party tools.

## Quick Start Preview

```bash
# Block 58K+ ad/tracker domains
sudo bash scripts/hosts-manager.sh block --list steven-black

# Add custom DNS
sudo bash scripts/hosts-manager.sh add 192.168.1.50 homelab.local

# Whitelist a domain
sudo bash scripts/hosts-manager.sh whitelist analytics.mysite.com
```
