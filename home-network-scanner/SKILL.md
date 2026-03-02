---
name: home-network-scanner
description: >-
  Scan your local network for devices, track them over time, and get alerts when new unknown devices appear.
categories: [home, security]
dependencies: [nmap, jq, bash]
---

# Home Network Scanner

## What This Does

Scans your local network to discover all connected devices (phones, laptops, IoT gadgets, smart TVs, etc.), identifies them by MAC address and hostname, and tracks them over time. Get alerts when a new unknown device joins your network — catch unauthorized access or just keep tabs on what's connected.

**Example:** "Scan 192.168.1.0/24, find 14 devices, alert me that a new device `Xiaomi-IoT-Hub` appeared at 192.168.1.47."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y nmap jq

# Mac
brew install nmap jq

# Verify
nmap --version && jq --version
```

### 2. First Scan

```bash
# Auto-detect your network and scan
bash scripts/scan.sh

# Or specify a subnet
bash scripts/scan.sh --subnet 192.168.1.0/24
```

### 3. View Known Devices

```bash
bash scripts/scan.sh --list
```

### 4. Set Up Scheduled Scans

```bash
# Scan every 15 minutes via cron
bash scripts/scan.sh --install-cron 15
```

## Core Workflows

### Workflow 1: Discovery Scan

**Use case:** See everything on your network right now.

```bash
bash scripts/scan.sh --subnet 192.168.1.0/24
```

**Output:**
```
🔍 Scanning 192.168.1.0/24...
Found 12 devices:

  IP               MAC                HOSTNAME           STATUS
  192.168.1.1      AA:BB:CC:DD:EE:01  router.local       ✅ Known
  192.168.1.10     AA:BB:CC:DD:EE:02  MacBook-Pro        ✅ Known
  192.168.1.15     AA:BB:CC:DD:EE:03  iPhone-Fahim       ✅ Known
  192.168.1.47     11:22:33:44:55:66  Xiaomi-IoT-Hub     🆕 NEW
  192.168.1.102    77:88:99:AA:BB:CC  (unknown)          🆕 NEW

⚠️  2 new devices detected! Run with --approve to mark as known.
```

### Workflow 2: Approve Known Devices

**Use case:** Mark discovered devices as trusted.

```bash
# Approve by MAC address
bash scripts/scan.sh --approve AA:BB:CC:DD:EE:01 --name "Home Router"
bash scripts/scan.sh --approve 11:22:33:44:55:66 --name "Xiaomi IoT Hub"

# Approve all currently connected devices
bash scripts/scan.sh --approve-all
```

### Workflow 3: Alert on New Devices

**Use case:** Get notified when unknown devices appear.

```bash
# Scan and send Telegram alert for new devices
bash scripts/scan.sh --alert telegram

# Scan and run a custom command on new device
bash scripts/scan.sh --on-new 'echo "New device: $DEVICE_IP ($DEVICE_MAC)" | mail -s "Network Alert" admin@example.com'
```

### Workflow 4: Device History

**Use case:** See when devices were first/last seen.

```bash
bash scripts/scan.sh --history

# Output:
# MAC                HOSTNAME         FIRST SEEN           LAST SEEN            TIMES SEEN
# AA:BB:CC:DD:EE:01  Home Router      2026-02-15 08:00     2026-03-02 19:45     1247
# AA:BB:CC:DD:EE:02  MacBook-Pro      2026-02-15 08:00     2026-03-02 19:45     892
# 11:22:33:44:55:66  Xiaomi-IoT-Hub   2026-03-01 14:22     2026-03-02 19:45     48
```

### Workflow 5: Vendor Lookup

**Use case:** Identify device manufacturer from MAC address.

```bash
bash scripts/scan.sh --vendor

# Output shows manufacturer:
# AA:BB:CC:DD:EE:01  TP-Link         Home Router
# AA:BB:CC:DD:EE:02  Apple Inc.      MacBook-Pro
# 11:22:33:44:55:66  Xiaomi          Xiaomi-IoT-Hub
```

## Configuration

### Data Directory

All device data is stored in `~/.config/home-network-scanner/`:

```
~/.config/home-network-scanner/
├── known-devices.json    # Approved/named devices
├── scan-history.json     # Historical scan data
├── config.yaml           # Settings
└── logs/
    └── scan-YYYY-MM-DD.log
```

### Config File

```yaml
# ~/.config/home-network-scanner/config.yaml
subnet: "192.168.1.0/24"        # Default subnet to scan
scan_timeout: 30                 # Nmap timeout in seconds
alert_on_new: true               # Alert when new devices found
alert_method: "telegram"         # telegram, email, webhook, command
telegram_bot_token: ""           # For Telegram alerts
telegram_chat_id: ""             # For Telegram alerts
webhook_url: ""                  # For webhook alerts
custom_command: ""               # Custom alert command
vendor_lookup: true              # Resolve MAC vendor
history_retention_days: 90       # How long to keep history
```

### Environment Variables

```bash
# Telegram alerts
export NET_SCANNER_TELEGRAM_TOKEN="<bot-token>"
export NET_SCANNER_TELEGRAM_CHAT="<chat-id>"

# Override subnet
export NET_SCANNER_SUBNET="10.0.0.0/24"
```

## Advanced Usage

### Run as Cron Job

```bash
# Install cron (every 15 min, alert on new)
bash scripts/scan.sh --install-cron 15

# Manual crontab entry
*/15 * * * * cd /path/to/skill && bash scripts/scan.sh --alert telegram >> logs/cron.log 2>&1
```

### Export Devices

```bash
# Export to CSV
bash scripts/scan.sh --export csv > devices.csv

# Export to JSON
bash scripts/scan.sh --export json > devices.json
```

### Scan Specific Ports

```bash
# Check for open ports on all devices
bash scripts/scan.sh --ports 22,80,443,8080

# Output:
# 192.168.1.1    AA:BB:CC:DD:EE:01  Home Router    PORTS: 80,443
# 192.168.1.10   AA:BB:CC:DD:EE:02  MacBook-Pro    PORTS: 22
```

### Compare Two Scans

```bash
# Show devices that appeared/disappeared since last scan
bash scripts/scan.sh --diff
```

## Troubleshooting

### Issue: "nmap: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install -y nmap

# Mac
brew install nmap

# CentOS/RHEL
sudo yum install -y nmap
```

### Issue: "Permission denied" or incomplete results

Nmap needs root/sudo for full MAC address detection:
```bash
sudo bash scripts/scan.sh
```

### Issue: No devices found

1. Check subnet is correct: `ip route | grep default`
2. Check firewall isn't blocking: `sudo nmap -sn 192.168.1.0/24`
3. Some networks block ARP scanning — try: `bash scripts/scan.sh --tcp-ping`

### Issue: MAC addresses show as (unknown)

This happens when scanning across subnets. Scan the local subnet only.

## Dependencies

- `nmap` (network scanner — must be installed)
- `jq` (JSON processing)
- `bash` (4.0+)
- `curl` (for vendor lookup + Telegram alerts)
- Optional: `arp-scan` (faster alternative to nmap for local networks)

## Key Principles

1. **Non-invasive** — Uses ARP/ping scans only, no port scanning by default
2. **Persistent tracking** — Device history survives reboots
3. **Alert once** — New device alert fires once, not on every scan
4. **Privacy-first** — All data stays local, no cloud services
5. **Low overhead** — Scan completes in <30 seconds for /24 subnet
