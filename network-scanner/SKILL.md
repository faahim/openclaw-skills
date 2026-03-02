---
name: network-scanner
description: >-
  Discover and monitor all devices on your local network. Detect new/unknown devices, track history, and get alerts on changes.
categories: [security, home]
dependencies: [nmap, arp-scan, jq]
---

# Network Scanner

## What This Does

Scans your local network to discover all connected devices — IPs, MACs, hostnames, and vendors. Tracks device history so you know when new/unknown devices appear. Set it on a schedule to monitor your network and get alerts when something unexpected joins.

**Example:** "Scan 192.168.1.0/24 every hour, alert me via Telegram if a new device appears."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y nmap arp-scan jq

# Mac
brew install nmap arp-scan jq

# Verify
nmap --version && arp-scan --version && jq --version
```

### 2. Run First Scan

```bash
# Auto-detect your network and scan
sudo bash scripts/scan.sh

# Or specify a network
sudo bash scripts/scan.sh --network 192.168.1.0/24

# Output:
# [2026-03-02 04:00:00] 🔍 Scanning 192.168.1.0/24...
# [2026-03-02 04:00:15] ✅ Found 12 devices
#
# IP              MAC                Vendor              Hostname
# 192.168.1.1     aa:bb:cc:dd:ee:ff  TP-Link             router.local
# 192.168.1.10    11:22:33:44:55:66  Apple               macbook.local
# 192.168.1.15    77:88:99:aa:bb:cc  Samsung             —
# ...
```

### 3. Monitor for New Devices

```bash
# Compare against known devices and alert on unknowns
sudo bash scripts/scan.sh --monitor --alert telegram

# First run creates baseline. Subsequent runs compare against it.
# 🆕 NEW DEVICE: 192.168.1.42 (de:ad:be:ef:00:01) — Unknown vendor
```

## Core Workflows

### Workflow 1: One-Time Network Discovery

**Use case:** See everything on your network right now

```bash
sudo bash scripts/scan.sh --network 192.168.1.0/24 --output table
```

**Output:**
```
┌─────────────────┬───────────────────┬──────────────┬─────────────────┐
│ IP              │ MAC               │ Vendor       │ Hostname        │
├─────────────────┼───────────────────┼──────────────┼─────────────────┤
│ 192.168.1.1     │ aa:bb:cc:dd:ee:ff │ TP-Link      │ router.local    │
│ 192.168.1.10    │ 11:22:33:44:55:66 │ Apple        │ macbook.local   │
│ 192.168.1.15    │ 77:88:99:aa:bb:cc │ Samsung      │ galaxy-s24      │
│ 192.168.1.20    │ dd:ee:ff:00:11:22 │ Raspberry Pi │ pihole.local    │
└─────────────────┴───────────────────┴──────────────┴─────────────────┘
Found: 4 devices on 192.168.1.0/24
```

### Workflow 2: Continuous Monitoring with Alerts

**Use case:** Get notified when unknown devices join your network

```bash
# Set up known devices baseline
sudo bash scripts/scan.sh --save-baseline

# Run monitor (compares to baseline)
sudo bash scripts/scan.sh --monitor --alert telegram

# Or add to crontab for hourly monitoring
echo "0 * * * * cd $(pwd) && sudo bash scripts/scan.sh --monitor --alert telegram >> logs/scan.log 2>&1" | sudo crontab -
```

### Workflow 3: Export for Analysis

**Use case:** Get machine-readable output for further processing

```bash
# JSON output
sudo bash scripts/scan.sh --output json > devices.json

# CSV output
sudo bash scripts/scan.sh --output csv > devices.csv
```

### Workflow 4: Port Scan Discovered Devices

**Use case:** Check what services are running on discovered devices

```bash
# Quick scan: top 100 ports on all found devices
sudo bash scripts/scan.sh --ports

# Output includes open ports per device:
# 192.168.1.1 — Ports: 80(http), 443(https), 53(dns)
# 192.168.1.20 — Ports: 22(ssh), 80(http), 8080(http-alt)
```

## Configuration

### Environment Variables

```bash
# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Default network (auto-detected if not set)
export SCAN_NETWORK="192.168.1.0/24"

# Data directory for baselines and logs
export SCAN_DATA_DIR="$HOME/.network-scanner"
```

### Known Devices File

After first scan, edit `~/.network-scanner/known-devices.json` to label your devices:

```json
[
  {
    "mac": "aa:bb:cc:dd:ee:ff",
    "label": "Main Router",
    "trusted": true
  },
  {
    "mac": "11:22:33:44:55:66",
    "label": "My MacBook",
    "trusted": true
  }
]
```

Unlabeled devices trigger alerts in monitor mode.

## Advanced Usage

### Run as Systemd Timer

```bash
# Install systemd service + timer
sudo bash scripts/install-service.sh

# Runs every 30 minutes, logs to journald
sudo systemctl status network-scanner.timer
```

### Scan Multiple Networks

```bash
sudo bash scripts/scan.sh \
  --network 192.168.1.0/24 \
  --network 10.0.0.0/24 \
  --monitor --alert telegram
```

### Webhook Alert

```bash
sudo bash scripts/scan.sh --monitor \
  --alert webhook \
  --webhook-url "https://hooks.slack.com/services/XXX/YYY/ZZZ"
```

## Troubleshooting

### Issue: "arp-scan: command not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install -y arp-scan

# Mac
brew install arp-scan
```

### Issue: "Permission denied" or incomplete results

**Fix:** Run with `sudo` — network scanning requires root/admin for ARP and raw socket access.

### Issue: Missing vendor information

**Fix:** Update nmap's MAC vendor database:
```bash
sudo nmap --script-updatedb
```

### Issue: Scan too slow on large networks

**Fix:** Use faster timing:
```bash
sudo bash scripts/scan.sh --network 10.0.0.0/16 --fast
```

## How It Works

1. **ARP Scan** (`arp-scan`) — Fast layer-2 discovery, finds all devices responding to ARP
2. **Nmap Scan** (`nmap -sn`) — Ping sweep for devices that don't respond to ARP
3. **Vendor Lookup** — MAC address → vendor name via nmap's OUI database
4. **Hostname Resolution** — Reverse DNS + mDNS for device names
5. **Baseline Comparison** — Diff against known devices to find new/unknown ones
6. **Alerting** — Telegram, webhook, or stdout for new device notifications

## Dependencies

- `nmap` (network scanning)
- `arp-scan` (ARP-based discovery)
- `jq` (JSON processing)
- `curl` (for alerts)
- Root/sudo access (required for network scanning)

## Key Principles

1. **Fast discovery** — ARP + ping sweep finds devices in seconds
2. **Persistent tracking** — Baseline file tracks known vs unknown devices
3. **Alert once** — Won't spam for already-seen unknown devices
4. **Multiple outputs** — Table, JSON, CSV for any use case
5. **Privacy-first** — All data stays local, no cloud services
