---
name: qr-code-generator
description: >-
  Generate QR codes from text, URLs, WiFi credentials, vCards, and more — as PNG, SVG, or terminal art.
categories: [productivity, media]
dependencies: [qrencode]
---

# QR Code Generator

## What This Does

Generate QR codes from any text input — URLs, WiFi passwords, contact cards, plain text. Output as PNG images, SVG vectors, or UTF-8 terminal art. Supports batch generation, custom sizes, colors, and error correction levels.

**Example:** "Generate a QR code for my WiFi network, save as PNG, and create a printable contact card QR."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Install qrencode
bash scripts/install.sh
```

### 2. Generate Your First QR Code

```bash
# Simple URL → PNG
bash scripts/run.sh --text "https://example.com" --output qr.png

# Display in terminal (no file needed)
bash scripts/run.sh --text "Hello World" --terminal

# WiFi QR code
bash scripts/run.sh --wifi --ssid "MyNetwork" --password "secret123" --encryption WPA --output wifi.png
```

## Core Workflows

### Workflow 1: URL QR Code

```bash
bash scripts/run.sh --text "https://yoursite.com" --output site-qr.png --size 10
# Output: site-qr.png (PNG, 370x370px)
```

### Workflow 2: WiFi Network QR Code

Scan this with any phone to auto-connect to WiFi.

```bash
bash scripts/run.sh --wifi \
  --ssid "Office-5G" \
  --password "hunter2" \
  --encryption WPA \
  --output office-wifi.png
```

### Workflow 3: vCard Contact QR

```bash
bash scripts/run.sh --vcard \
  --name "John Doe" \
  --phone "+1234567890" \
  --email "john@example.com" \
  --url "https://johndoe.com" \
  --output john-contact.png
```

### Workflow 4: Terminal Display (No File)

```bash
# Quick QR in terminal — great for sharing URLs in SSH sessions
bash scripts/run.sh --text "https://example.com" --terminal
```

### Workflow 5: SVG Output (Vector, Scalable)

```bash
bash scripts/run.sh --text "https://example.com" --format svg --output qr.svg
```

### Workflow 6: Batch Generation

```bash
# Generate QR codes from a file (one URL per line)
bash scripts/run.sh --batch urls.txt --output-dir ./qr-codes/

# urls.txt:
# https://example.com
# https://github.com
# https://google.com
```

### Workflow 7: Custom Colors & Size

```bash
bash scripts/run.sh --text "Styled QR" \
  --output styled.png \
  --size 12 \
  --foreground "000080" \
  --background "FFFFFF" \
  --level H
```

## Configuration

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--text` | Text to encode | (required) |
| `--output` | Output file path | stdout |
| `--format` | Output format: `png`, `svg`, `terminal` | `png` |
| `--terminal` | Display as UTF-8 art in terminal | false |
| `--size` | Module size in pixels (PNG) | 8 |
| `--level` | Error correction: L, M, Q, H | M |
| `--foreground` | Foreground color (hex) | 000000 |
| `--background` | Background color (hex) | FFFFFF |
| `--wifi` | Generate WiFi QR code | false |
| `--ssid` | WiFi network name | - |
| `--password` | WiFi password | - |
| `--encryption` | WiFi encryption: WPA, WEP, nopass | WPA |
| `--vcard` | Generate vCard QR | false |
| `--name` | vCard full name | - |
| `--phone` | vCard phone number | - |
| `--email` | vCard email address | - |
| `--url` | vCard website URL | - |
| `--batch` | File with one text per line | - |
| `--output-dir` | Directory for batch output | ./qr-output |

### Error Correction Levels

| Level | Recovery | Best For |
|-------|----------|----------|
| L | ~7% | Small QR, maximum data |
| M | ~15% | General use (default) |
| Q | ~25% | Printed materials |
| H | ~30% | Logo overlay, damaged prints |

## Advanced Usage

### Pipe-Friendly

```bash
# Pipe text into QR generator
echo "https://example.com" | bash scripts/run.sh --stdin --terminal

# Generate and immediately copy to clipboard (macOS)
bash scripts/run.sh --text "hello" --output /dev/stdout | pbcopy

# Generate and upload somewhere
bash scripts/run.sh --text "data" --output qr.png && curl -F "file=@qr.png" https://upload.service/
```

### OpenClaw Cron Integration

```bash
# Daily WiFi password rotation QR
PASSWORD=$(openssl rand -base64 12)
bash scripts/run.sh --wifi --ssid "GuestWiFi" --password "$PASSWORD" --output /var/www/guest-wifi.png
echo "New guest WiFi password: $PASSWORD"
```

### Encode Binary/Special Data

```bash
# Email mailto link
bash scripts/run.sh --text "mailto:hello@example.com?subject=Hello" --output email-qr.png

# SMS
bash scripts/run.sh --text "smsto:+1234567890:Hello from QR" --output sms-qr.png

# Geo location
bash scripts/run.sh --text "geo:40.7128,-74.0060" --output location-qr.png

# Calendar event
bash scripts/run.sh --text "BEGIN:VEVENT
SUMMARY:Meeting
DTSTART:20260301T100000
DTEND:20260301T110000
END:VEVENT" --output event-qr.png
```

## Troubleshooting

### Issue: "command not found: qrencode"

```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: sudo apt-get install -y qrencode
# macOS: brew install qrencode
# Alpine: apk add libqrencode-tools
```

### Issue: QR code too dense / won't scan

Increase error correction and size:
```bash
bash scripts/run.sh --text "long data..." --size 12 --level H --output big-qr.png
```

### Issue: Colors not rendering

Colors must be 6-digit hex without `#`:
```bash
# ✅ Correct
--foreground "FF0000"
# ❌ Wrong
--foreground "#FF0000"
```

## Dependencies

- `qrencode` (3.4+) — Core QR generation engine
- `bash` (4.0+)
- Optional: `imagemagick` for advanced image manipulation
