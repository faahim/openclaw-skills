---
name: usb-guard
description: >-
  Monitor USB device connections, maintain allowlists, and get instant alerts when unknown devices are plugged in.
categories: [security, automation]
dependencies: [bash, usbutils, inotifywait]
---

# USB Guard

## What This Does

Monitors USB ports in real-time for new device connections. Maintains an allowlist of trusted devices and alerts you instantly (via Telegram, webhook, or log) when an unknown device is plugged in. Useful for servers, kiosks, shared workstations, or any machine where unauthorized USB devices are a security concern.

**Example:** "Alert me on Telegram whenever someone plugs in a USB device that isn't my keyboard, mouse, or yubikey."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y usbutils inotify-tools

# RHEL/Fedora
sudo dnf install -y usbutils inotify-tools

# Check they work
lsusb && echo "✅ usbutils OK"
which inotifywait && echo "✅ inotify-tools OK"
```

### 2. Scan Current Devices (Build Initial Allowlist)

```bash
# Auto-detect all currently connected USB devices and trust them
bash scripts/usb-guard.sh --init

# Output:
# 📋 Scanning connected USB devices...
# ✅ Added: 1d6b:0002 Linux Foundation 2.0 root hub
# ✅ Added: 046d:c52b Logitech Unifying Receiver
# ✅ Added: 1050:0407 Yubico YubiKey OTP+FIDO+CCID
# 📝 Allowlist saved to ~/.config/usb-guard/allowlist.conf (3 devices)
```

### 3. Start Monitoring

```bash
# Start monitoring (foreground)
bash scripts/usb-guard.sh --monitor

# Start monitoring (background daemon)
bash scripts/usb-guard.sh --daemon

# Output on new device:
# 🚨 [2026-03-04 17:55:00] UNKNOWN USB DEVICE DETECTED
#    Vendor: 0781  Product: 5567
#    Name: SanDisk Cruzer Blade
#    Port: usb1/1-2
#    Action: LOGGED + ALERT SENT
```

## Core Workflows

### Workflow 1: Real-Time USB Monitoring

**Use case:** Alert when any untrusted USB device is connected

```bash
# Monitor with Telegram alerts
export USB_GUARD_TELEGRAM_TOKEN="your-bot-token"
export USB_GUARD_TELEGRAM_CHAT="your-chat-id"

bash scripts/usb-guard.sh --monitor --alert telegram
```

**On unknown device:**
```
🚨 UNKNOWN USB DEVICE
Device: SanDisk Cruzer Blade (0781:5567)
Port: usb1/1-2
Time: 2026-03-04 17:55:00
Host: my-server
```

### Workflow 2: Manage Allowlist

**Use case:** Add/remove trusted devices

```bash
# List current allowlist
bash scripts/usb-guard.sh --list

# Add a device by vendor:product ID
bash scripts/usb-guard.sh --allow 0781:5567 --name "SanDisk Cruzer"

# Remove a device
bash scripts/usb-guard.sh --revoke 0781:5567

# Trust all currently connected devices
bash scripts/usb-guard.sh --trust-current
```

### Workflow 3: Audit USB History

**Use case:** Review what's been plugged in

```bash
# Show recent USB events
bash scripts/usb-guard.sh --history

# Output:
# 2026-03-04 17:50:00 | ALLOWED  | 046d:c52b | Logitech Unifying Receiver
# 2026-03-04 17:55:00 | BLOCKED  | 0781:5567 | SanDisk Cruzer Blade
# 2026-03-04 18:01:00 | ALLOWED  | 1050:0407 | Yubico YubiKey

# Export as CSV
bash scripts/usb-guard.sh --history --format csv > usb-events.csv
```

### Workflow 4: Auto-Block Mode (Advanced)

**Use case:** Automatically disable unauthorized USB devices

```bash
# ⚠️ Requires root. Unbinds unknown USB devices from the kernel.
sudo bash scripts/usb-guard.sh --monitor --auto-block

# Output:
# 🚨 [2026-03-04 17:55:00] UNKNOWN DEVICE BLOCKED
#    Device: 0781:5567 SanDisk Cruzer Blade
#    Action: Unbound from usb1/1-2 (device disabled)
```

## Configuration

### Config File

```bash
# Default location: ~/.config/usb-guard/config.conf
cat > ~/.config/usb-guard/config.conf << 'EOF'
# USB Guard Configuration

# Alert methods (comma-separated): telegram, webhook, log, stdout
ALERT_METHODS="log,stdout"

# Telegram (optional)
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Webhook (optional)
WEBHOOK_URL=""

# Auto-block unknown devices (requires root)
AUTO_BLOCK=false

# Log file
LOG_FILE="$HOME/.config/usb-guard/events.log"

# Poll interval in seconds (fallback if inotifywait unavailable)
POLL_INTERVAL=2

# Max log entries to keep
MAX_LOG_ENTRIES=10000
EOF
```

### Allowlist Format

```bash
# ~/.config/usb-guard/allowlist.conf
# Format: VENDOR:PRODUCT # Description
1d6b:0002 # Linux Foundation 2.0 root hub
1d6b:0003 # Linux Foundation 3.0 root hub
046d:c52b # Logitech Unifying Receiver
1050:0407 # Yubico YubiKey OTP+FIDO+CCID
```

## Advanced Usage

### Run as Systemd Service

```bash
# Install as system service
sudo bash scripts/usb-guard.sh --install-service

# Manage
sudo systemctl start usb-guard
sudo systemctl enable usb-guard  # Start on boot
sudo systemctl status usb-guard
journalctl -u usb-guard -f       # Follow logs
```

### Run via OpenClaw Cron

```bash
# Check for new USB events every 5 minutes
# In OpenClaw cron: run `bash scripts/usb-guard.sh --check-once`
# Returns exit code 1 if unknown devices found since last check
```

### Multiple Machine Sync

```bash
# Export allowlist
bash scripts/usb-guard.sh --export > my-allowlist.conf

# Import on another machine
bash scripts/usb-guard.sh --import my-allowlist.conf
```

## Troubleshooting

### Issue: "inotifywait: command not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install inotify-tools

# If unavailable, USB Guard falls back to polling mode (2s interval)
```

### Issue: "Permission denied" for auto-block

**Fix:** Auto-block requires root access to unbind USB devices.
```bash
sudo bash scripts/usb-guard.sh --monitor --auto-block
```

### Issue: Not detecting USB events

**Check:**
1. Verify udev is running: `systemctl status systemd-udevd`
2. Check USB subsystem: `ls /sys/bus/usb/devices/`
3. Try polling mode: `bash scripts/usb-guard.sh --monitor --poll`

## Dependencies

- `bash` (4.0+)
- `usbutils` (for `lsusb`)
- `inotify-tools` (for `inotifywait`) — optional, falls back to polling
- `curl` (for Telegram/webhook alerts)
- Optional: `systemd` (for service installation)

## Key Principles

1. **Zero false positives** — Only alerts on genuinely new/unknown devices
2. **Low overhead** — Uses kernel inotify, not CPU-burning polling
3. **Secure defaults** — Log-only mode by default, auto-block is opt-in
4. **Audit trail** — Every USB event logged with timestamp
