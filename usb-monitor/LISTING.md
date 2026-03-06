# Listing Copy: USB Monitor

## Metadata
- **Type:** Skill
- **Name:** usb-monitor
- **Display Name:** USB Monitor
- **Categories:** [security, automation]
- **Price:** $8
- **Dependencies:** [bash, udevadm, lsusb]

## Tagline

Monitor USB connections in real-time — Get instant alerts on unknown devices

## Description

Plugging a rogue USB device into a server can mean data theft, malware injection, or unauthorized access. If you're not monitoring USB ports, you're flying blind.

USB Monitor watches your Linux system's USB ports in real-time using `udevadm` — no polling, no overhead. Every connection and disconnection is logged with full device details: vendor, product, serial number, and timestamp.

**What it does:**
- 🔌 Real-time USB connect/disconnect detection (event-driven, not polling)
- 🚨 Instant alerts via Telegram or webhook when unknown devices appear
- 📋 Whitelist trusted devices — only alert on unfamiliar hardware
- 📊 JSON or plain-text logging for audit trails
- 📸 Snapshot mode — list all currently connected USB devices
- 🔧 One-command systemd service installation for persistent monitoring

**Who it's for:** Sysadmins securing servers, developers debugging USB hardware, anyone who wants visibility into what's plugged into their machines.

## Quick Start Preview

```bash
# Monitor USB events with Telegram alerts
TELEGRAM_BOT_TOKEN="xxx" TELEGRAM_CHAT_ID="123" \
  bash scripts/usb-monitor.sh --alert telegram --whitelist scripts/whitelist.conf

# Output:
# [2026-03-06 23:55:01] 🔌 CONNECTED: SanDisk Ultra USB 3.0 (0781:5581)
# 🚨 Alert sent — device NOT in whitelist
```

## Core Capabilities

1. Real-time monitoring — Event-driven via udevadm (zero CPU polling)
2. Device identification — Vendor, product, serial number, USB port
3. Whitelist support — Define trusted devices, alert only on unknown
4. Telegram alerts — Instant notification on device connections
5. Webhook alerts — Send to Slack, Discord, or any endpoint
6. JSON output — Machine-readable logs for analysis
7. Snapshot mode — List all connected USB devices instantly
8. Auto-generate whitelist — Create whitelist from current devices
9. Systemd service — One-command install for persistent monitoring
10. Audit logging — Timestamped log file for compliance

## Dependencies
- `bash` (4.0+)
- `udevadm` (standard on Linux)
- `lsusb` (from usbutils)
- `curl` (for alerts)

## Installation Time
**3 minutes** — Check deps, run script
