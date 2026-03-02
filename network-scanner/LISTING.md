# Listing Copy: Network Scanner

## Metadata
- **Type:** Skill
- **Name:** network-scanner
- **Display Name:** Network Scanner
- **Categories:** [security, home]
- **Price:** $10
- **Dependencies:** [nmap, arp-scan, jq, curl]
- **Icon:** 🔍

## Tagline

Discover and monitor all devices on your local network — get alerts when unknowns appear

## Description

You probably don't know half the devices on your network. Smart TVs, IoT gadgets, neighbors borrowing WiFi — they all show up silently. By the time you notice something wrong, it's too late.

Network Scanner discovers every device on your local network in seconds using ARP and ping sweeps. It shows IPs, MAC addresses, vendor names, and hostnames in a clean table. Save a baseline of your known devices, then run in monitor mode to get instant Telegram or webhook alerts when something new appears.

**What it does:**
- 🔍 Discover all devices on any network (192.168.x.x, 10.x.x.x, etc.)
- 📋 Show IP, MAC, vendor, hostname for every device
- 🆕 Detect and alert on new/unknown devices
- 🔐 Optional port scanning on discovered devices
- 📊 Export as table, JSON, or CSV
- ⏰ Run on a schedule via cron or systemd timer
- 📱 Alerts via Telegram, Slack webhook, or custom endpoint
- 🏠 100% local — no cloud services, no data leaves your network

Perfect for home network security, sysadmins monitoring office LANs, or anyone who wants to know exactly what's connected to their network.

## Quick Start Preview

```bash
# Discover all devices
sudo bash scripts/scan.sh

# Monitor for intruders
sudo bash scripts/scan.sh --monitor --alert telegram
```

## Core Capabilities

1. ARP + ping sweep discovery — finds every device, even stealthy ones
2. Vendor identification — maps MAC addresses to manufacturer names
3. Hostname resolution — reverse DNS + mDNS for device names
4. Baseline management — save known devices, alert on unknowns
5. Multi-network support — scan multiple subnets in one run
6. Port scanning — discover open services on found devices
7. Multiple output formats — table, JSON, CSV
8. Telegram alerts — instant notification for new devices
9. Webhook support — integrate with Slack, Discord, or any service
10. Systemd timer — automated scheduled scanning
11. Deduplication — won't re-alert for already-seen devices
12. Zero cloud dependency — everything runs locally
