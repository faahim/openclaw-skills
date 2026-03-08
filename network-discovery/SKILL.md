---
name: network-discovery
description: >-
  Discover all devices on your local network, identify manufacturers, and get alerts when new or unknown devices appear.
categories: [security, home]
dependencies: [arp-scan, nmap, curl, jq]
---

# Network Device Discovery

## What This Does

Scans your local network to find every connected device — computers, phones, IoT devices, smart home gadgets, anything with an IP. Identifies manufacturers from MAC addresses, tracks devices over time, and alerts you when something new or unknown appears on your network.

**Example:** "Scan 192.168.1.0/24, find 23 devices, flag 2 unknown ones, send Telegram alert."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y arp-scan nmap jq

# Mac
brew install arp-scan nmap jq

# Verify
which arp-scan nmap jq
```

### 2. Run First Scan

```bash
# Auto-detect network and scan (requires sudo for arp-scan)
sudo bash scripts/scan.sh

# Output:
# [2026-03-08 12:00:00] 🔍 Scanning 192.168.1.0/24...
# [2026-03-08 12:00:05] Found 14 devices
#
# IP Address        MAC Address        Manufacturer          Status
# 192.168.1.1       aa:bb:cc:dd:ee:01  TP-Link              ✅ Known
# 192.168.1.42      aa:bb:cc:dd:ee:02  Apple, Inc.          ✅ Known
# 192.168.1.105     aa:bb:cc:dd:ee:03  (Unknown)            ⚠️ NEW
```

### 3. Set Up Alerts (Optional)

```bash
# Telegram alerts for new devices
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

# Scan with alerts enabled
sudo bash scripts/scan.sh --alert telegram
```

## Core Workflows

### Workflow 1: Quick Network Scan

**Use case:** See what's on your network right now

```bash
sudo bash scripts/scan.sh
```

### Workflow 2: Continuous Monitoring

**Use case:** Run every 5 minutes, alert on new devices

```bash
sudo bash scripts/scan.sh --watch --interval 300 --alert telegram
```

### Workflow 3: Scan Specific Subnet

```bash
sudo bash scripts/scan.sh --subnet 10.0.0.0/24
```

### Workflow 4: Deep Scan (Port Detection)

**Use case:** Identify what services each device is running

```bash
sudo bash scripts/scan.sh --deep
```

Adds open port detection via nmap (HTTP, SSH, SMB, etc.)

### Workflow 5: Export Device Inventory

```bash
sudo bash scripts/scan.sh --output json > devices.json
sudo bash scripts/scan.sh --output csv > devices.csv
```

### Workflow 6: Manage Known Devices

```bash
# Add a device to known list (won't trigger alerts)
bash scripts/manage.sh add "aa:bb:cc:dd:ee:ff" "Living Room TV"

# List all known devices
bash scripts/manage.sh list

# Remove a device
bash scripts/manage.sh remove "aa:bb:cc:dd:ee:ff"
```

## Configuration

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Custom data directory (default: ~/.network-discovery)
export NETDISC_DATA_DIR="$HOME/.network-discovery"
```

### Known Devices File

Stored at `~/.network-discovery/known-devices.json`:

```json
[
  {"mac": "aa:bb:cc:dd:ee:01", "name": "Router", "added": "2026-03-08"},
  {"mac": "aa:bb:cc:dd:ee:02", "name": "My Laptop", "added": "2026-03-08"},
  {"mac": "aa:bb:cc:dd:ee:03", "name": "Smart TV", "added": "2026-03-08"}
]
```

## Advanced Usage

### Run as Cron Job

```bash
# Scan every 10 minutes, alert on new devices
*/10 * * * * cd /path/to/skill && sudo bash scripts/scan.sh --alert telegram >> /var/log/network-discovery.log 2>&1
```

### Integration with OpenClaw Cron

```
Ask your OpenClaw agent:
"Scan my network every 15 minutes and alert me on Telegram if any new device appears"
```

### Compare Scans

```bash
# Show what changed between last two scans
bash scripts/diff.sh

# Output:
# ➕ NEW: 192.168.1.105 (aa:bb:cc:dd:ee:03) — Unknown manufacturer
# ➖ GONE: 192.168.1.42 (aa:bb:cc:dd:ee:02) — Apple, Inc. (was "My Laptop")
```

## Troubleshooting

### Issue: "arp-scan: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install -y arp-scan

# Mac
brew install arp-scan
```

### Issue: "Permission denied" or empty results

arp-scan requires root/sudo to send ARP packets:
```bash
sudo bash scripts/scan.sh
```

### Issue: Wrong subnet detected

Specify it manually:
```bash
sudo bash scripts/scan.sh --subnet 192.168.1.0/24
```

### Issue: Manufacturer shows "(Unknown)"

Update the OUI database:
```bash
sudo arp-scan --update-ieee-oui
# OR
sudo ieee-oui --update
```

## How It Works

1. **ARP Scan** — Sends ARP requests to every IP in the subnet. Faster and more reliable than ping sweeps.
2. **MAC Lookup** — Matches MAC address prefixes to manufacturer database (IEEE OUI).
3. **Device Tracking** — Stores scan results in `~/.network-discovery/scans/`. Compares with previous scans.
4. **Deep Scan (optional)** — Uses nmap to detect open ports and services on discovered devices.
5. **Alerting** — Compares against known-devices list. New MACs trigger alerts.

## Dependencies

- `arp-scan` (ARP-based network scanner)
- `nmap` (port/service detection, deep scan only)
- `jq` (JSON processing)
- `curl` (Telegram alerts)
- `bash` (4.0+)
