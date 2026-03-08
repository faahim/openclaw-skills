# Listing Copy: Network Device Discovery

## Metadata
- **Type:** Skill
- **Name:** network-discovery
- **Display Name:** Network Device Discovery
- **Categories:** [security, home]
- **Icon:** 🔍
- **Price:** $10
- **Dependencies:** [arp-scan, nmap, jq, curl]

## Tagline

Discover every device on your network — get alerts when unknown devices appear

## Description

You don't know what's on your network. Smart TVs, IoT devices, your neighbor's phone that somehow connected to your WiFi — they're all invisible until you look. By the time you notice a rogue device, it's been there for weeks.

Network Device Discovery scans your local network using ARP requests (the most reliable method), identifies every connected device by manufacturer, and tracks changes over time. When something new appears, you get an instant Telegram alert. No cloud services, no monthly fees — it runs right in your OpenClaw agent.

**What it does:**
- 🔍 Scan any subnet — find every device with an IP address
- 🏭 Identify manufacturers from MAC addresses (Apple, TP-Link, etc.)
- ⚠️ Alert on new/unknown devices via Telegram
- 📊 Track device history — see what came and went
- 🔎 Deep scan mode — detect open ports and services (via nmap)
- 📋 Export inventory as JSON or CSV
- 🏷️ Manage known devices — label and whitelist your stuff
- ⏱️ Watch mode — continuous monitoring at any interval
- 🔄 Diff tool — compare any two scans side by side

## Quick Start Preview

```bash
# Install deps + scan
bash scripts/install.sh
sudo bash scripts/scan.sh

# Output:
# IP Address        MAC Address        Manufacturer          Status
# 192.168.1.1       aa:bb:cc:dd:ee:01  TP-Link              ✅ Known
# 192.168.1.105     aa:bb:cc:dd:ee:03  (Unknown)            ⚠️ NEW
```

## Who It's For

Perfect for homelab enthusiasts, sysadmins, and security-conscious users who want to know exactly what's connected to their network — without installing a heavy monitoring stack.

## Dependencies
- `arp-scan` (ARP-based network scanner)
- `nmap` (deep scan / port detection)
- `jq` (JSON processing)
- `curl` (Telegram alerts)
- `bash` (4.0+)

## Installation Time
**5 minutes** — run install.sh, then scan
