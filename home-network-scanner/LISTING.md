# Listing Copy: Home Network Scanner

## Metadata
- **Type:** Skill
- **Name:** home-network-scanner
- **Display Name:** Home Network Scanner
- **Categories:** [home, security]
- **Price:** $8
- **Dependencies:** [nmap, jq, bash, curl]
- **Icon:** 🏠

## Tagline

Scan your network for devices — Track and alert on new connections

## Description

Ever wonder what's actually connected to your home network? Between smart TVs, IoT gadgets, phones, and that one device you can't identify — it's easy to lose track. And if someone unauthorized hops on your WiFi, you might never know.

**Home Network Scanner** discovers every device on your local network using nmap, identifies them by MAC address and hostname, resolves vendors (Apple, Samsung, TP-Link, etc.), and tracks them over time. When a new unknown device appears, you get an instant alert via Telegram, webhook, or custom command.

**What it does:**
- 🔍 Scan any subnet — auto-detects your local network
- 📋 Track devices over time — first seen, last seen, frequency
- 🆕 Alert on new devices — Telegram, webhook, or custom command
- 🏭 Vendor lookup — identify manufacturer from MAC address
- 📊 Export to CSV/JSON — for analysis or documentation
- 🔐 Port scanning — check what services devices expose
- ⏰ Cron-ready — schedule scans every 5/15/60 minutes
- 📈 Diff mode — see what appeared/disappeared since last scan

**Perfect for** anyone who wants visibility into their home or office network — developers, sysadmins, privacy-conscious users, parents managing family devices, or small business owners tracking office equipment.

## Quick Start Preview

```bash
# Scan your local network
bash scripts/scan.sh

# Output:
# 🔍 Scanning 192.168.1.0/24...
# Found 12 devices:
#   192.168.1.1    AA:BB:CC:DD:EE:01  router.local    ✅ Known
#   192.168.1.47   11:22:33:44:55:66  Xiaomi-Hub      🆕 NEW
# ⚠️  1 new device detected!
```

## Core Capabilities

1. Network discovery — Find all devices on your LAN via ARP/ping scan
2. Device tracking — Persistent history of every device ever seen
3. New device alerts — Telegram, webhook, or custom command notifications
4. Vendor identification — Resolve manufacturer from MAC address (Apple, Samsung, etc.)
5. Device approval — Mark trusted devices, flag unknowns
6. Port scanning — Check open ports on discovered devices
7. CSV/JSON export — Export device inventory for docs or analysis
8. Diff comparison — See what changed between scans
9. Cron scheduling — Automated scans every N minutes
10. Zero cloud — All data stays local on your machine

## Dependencies
- `nmap` (network scanner)
- `jq` (JSON processing)
- `bash` (4.0+)
- `curl` (vendor lookup + alerts)

## Installation Time
**5 minutes** — install nmap, run first scan
