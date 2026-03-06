---
name: usb-monitor
description: >-
  Monitor USB device connections and disconnections with real-time alerts via Telegram, webhook, or log file.
categories: [security, automation]
dependencies: [bash, udevadm, lsusb]
---

# USB Monitor

## What This Does

Monitors USB ports for device connections and disconnections in real-time. Logs every event with timestamps, device details (vendor, product, serial), and optionally sends instant alerts via Telegram or webhook. Useful for security auditing (detect unauthorized USB devices), server monitoring, and hardware debugging.

**Example:** "Alert me on Telegram whenever a USB drive is plugged into my server."

## Quick Start (3 minutes)

### 1. Check Dependencies

```bash
# These are standard on most Linux systems
which udevadm lsusb || echo "Install usbutils: sudo apt install usbutils"
```

### 2. Run the Monitor

```bash
# Monitor all USB events, log to stdout
bash scripts/usb-monitor.sh

# With Telegram alerts
TELEGRAM_BOT_TOKEN="your-token" TELEGRAM_CHAT_ID="your-chat-id" \
  bash scripts/usb-monitor.sh --alert telegram

# Log to file
bash scripts/usb-monitor.sh --log /var/log/usb-events.log
```

### 3. Example Output

```
[2026-03-06 23:55:01] 🔌 CONNECTED: SanDisk Ultra USB 3.0 (0781:5581) at /dev/sdb
[2026-03-06 23:57:15] ⏏️  DISCONNECTED: SanDisk Ultra USB 3.0 (0781:5581)
[2026-03-07 00:02:33] 🔌 CONNECTED: Logitech USB Receiver (046d:c534) at usb1/1-2
```

## Core Workflows

### Workflow 1: Security Monitoring

**Use case:** Detect unauthorized USB devices on a server

```bash
# Monitor and alert on any USB connection
bash scripts/usb-monitor.sh \
  --alert telegram \
  --whitelist scripts/whitelist.conf

# whitelist.conf format (vendor:product pairs):
# 046d:c534  # Logitech receiver
# 8087:0029  # Intel Bluetooth
```

When a non-whitelisted device connects:
```
🚨 UNKNOWN USB DEVICE CONNECTED
Device: Kingston DataTraveler (0951:1666)
Port: usb1/1-3
Time: 2026-03-06 23:55:01
NOT in whitelist — possible security concern
```

### Workflow 2: Log All USB Events

**Use case:** Audit trail of all USB activity

```bash
bash scripts/usb-monitor.sh \
  --log /var/log/usb-monitor.log \
  --json
```

JSON output:
```json
{"timestamp":"2026-03-06T23:55:01Z","event":"connect","vendor":"SanDisk","product":"Ultra USB 3.0","vid":"0781","pid":"5581","serial":"ABC123","port":"usb1/1-3"}
```

### Workflow 3: Snapshot Current USB Devices

**Use case:** List all currently connected USB devices

```bash
bash scripts/usb-monitor.sh --snapshot
```

Output:
```
Currently connected USB devices:
  1. Intel Bluetooth (8087:0029) — Bus 001 Device 003
  2. Logitech USB Receiver (046d:c534) — Bus 001 Device 004
  3. USB Hub (1a40:0101) — Bus 002 Device 001
Total: 3 devices
```

### Workflow 4: Webhook Alerts

**Use case:** Send USB events to Slack, Discord, or any webhook

```bash
bash scripts/usb-monitor.sh \
  --alert webhook \
  --webhook-url "https://hooks.slack.com/services/T.../B.../xxx"
```

## Configuration

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<bot-token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Webhook alerts
export USB_WEBHOOK_URL="https://hooks.slack.com/..."

# Log file (default: stdout)
export USB_LOG_FILE="/var/log/usb-monitor.log"
```

### Whitelist File

```bash
# scripts/whitelist.conf
# Format: VID:PID  # Comment
046d:c534  # Logitech USB Receiver
8087:0029  # Intel Bluetooth
1d6b:0002  # Linux Foundation USB 2.0 Hub
1d6b:0003  # Linux Foundation USB 3.0 Hub
```

Devices in the whitelist won't trigger alerts (still logged).

## Advanced Usage

### Run as a systemd Service

```bash
# Install service
sudo bash scripts/install-service.sh

# This creates /etc/systemd/system/usb-monitor.service
# and enables it to start on boot

# Manage
sudo systemctl status usb-monitor
sudo systemctl stop usb-monitor
sudo journalctl -u usb-monitor -f
```

### Run with OpenClaw Cron

```bash
# Take a USB snapshot every hour for auditing
# Add to OpenClaw cron:
bash scripts/usb-monitor.sh --snapshot --json >> /var/log/usb-snapshots.jsonl
```

### Generate Whitelist from Current Devices

```bash
# Auto-generate whitelist from currently connected devices
bash scripts/usb-monitor.sh --generate-whitelist > scripts/whitelist.conf
```

## Troubleshooting

### Issue: "udevadm not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt install udev

# Already included in most distros
```

### Issue: Permission denied

**Fix:** Run with sudo or add user to `plugdev` group:
```bash
sudo usermod -aG plugdev $USER
# Re-login after
```

### Issue: No events detected

**Check:** Make sure `udevadm monitor` works:
```bash
sudo udevadm monitor --subsystem-match=usb --property
# Plug in a USB device — you should see output
```

## Dependencies

- `bash` (4.0+)
- `udevadm` (part of systemd/udev — standard on Linux)
- `lsusb` (from `usbutils` package)
- `curl` (for Telegram/webhook alerts)
- Optional: `jq` (for JSON output formatting)

## Key Principles

1. **Real-time** — Uses udevadm monitor for instant detection
2. **Low overhead** — No polling, event-driven
3. **Security-first** — Whitelist support, alert on unknown devices
4. **Flexible output** — Plain text, JSON, file, stdout
5. **Alert once** — Deduplicates rapid connect/disconnect events
