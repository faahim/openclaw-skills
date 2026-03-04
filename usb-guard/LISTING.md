# Listing Copy: USB Guard

## Metadata
- **Type:** Skill
- **Name:** usb-guard
- **Display Name:** USB Guard
- **Categories:** [security, automation]
- **Price:** $10
- **Dependencies:** [bash, usbutils, inotify-tools]

## Tagline

Monitor USB ports in real-time — Get instant alerts when unknown devices are plugged in

## Description

Unauthorized USB devices are one of the most overlooked security risks. Someone plugs in a rogue flash drive, a keystroke logger, or an unknown peripheral — and you'd never know unless you were watching. USB Guard watches for you.

USB Guard monitors your USB ports in real-time using kernel inotify (zero CPU overhead). It maintains an allowlist of trusted devices and instantly alerts you via Telegram, webhook, or log when anything unknown gets connected. Optional auto-block mode can disable unauthorized devices on the spot.

**What it does:**
- 🛡️ Real-time USB device monitoring (inotify-based, near-zero overhead)
- 📋 Allowlist management — trust known devices, flag everything else
- 🚨 Instant alerts via Telegram, webhook, or log file
- 🔒 Optional auto-block — unbind unknown devices from the kernel
- 📊 Full audit trail — every connect/disconnect event logged
- ⚡ 5-minute setup — scan current devices, start monitoring
- 🔄 Systemd service — run on boot, survive reboots
- 📤 Import/export allowlists across machines

## Quick Start Preview

```bash
# Scan current devices and build allowlist
bash scripts/usb-guard.sh --init

# Start monitoring with Telegram alerts
export USB_GUARD_TELEGRAM_TOKEN="your-token"
bash scripts/usb-guard.sh --monitor --alert telegram
```

## Core Capabilities

1. Real-time USB monitoring — Detect new devices within seconds using kernel inotify
2. Allowlist management — Add, remove, and export trusted device lists
3. Multi-channel alerts — Telegram, webhooks, log files, or stdout
4. Auto-block mode — Automatically unbind unauthorized USB devices (root)
5. Audit history — Full event log with CSV export for compliance
6. One-shot checks — Cron-friendly mode for periodic USB audits
7. Systemd integration — Install as a persistent system service
8. Cross-machine sync — Export/import allowlists between servers
9. Polling fallback — Works even without inotify-tools (2s polling)
10. Zero dependencies trap — Gracefully degrades if optional tools missing

## Dependencies
- `bash` (4.0+)
- `usbutils` (`lsusb`)
- `inotify-tools` (optional, falls back to polling)
- `curl` (for Telegram/webhook alerts)

## Installation Time
**5 minutes** — Init scan + start monitoring

## Pricing Justification

**Why $10:**
- Enterprise USB monitoring tools (USB Lock, Endpoint Protector): $5-15/endpoint/month
- Open-source USBGuard (kernel-level): Complex setup, C++ compilation required
- Our advantage: Simple bash, works everywhere, agent-integrated, one-time payment
