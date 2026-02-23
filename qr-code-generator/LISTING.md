# Listing Copy: QR Code Generator

## Metadata
- **Type:** Skill
- **Name:** qr-code-generator
- **Display Name:** QR Code Generator
- **Categories:** [productivity, media]
- **Icon:** 📱
- **Dependencies:** [qrencode]

## Tagline

Generate QR codes from URLs, WiFi, vCards — as PNG, SVG, or terminal art

## Description

Manually creating QR codes means opening a sketchy website, uploading your data to someone else's server, and downloading a low-quality image. Your agent can't generate images natively — it needs a real tool.

QR Code Generator uses `qrencode` to create QR codes locally, instantly, with zero data leaving your machine. Encode URLs, plain text, WiFi credentials (scan-to-connect), vCards (scan-to-save contact), calendar events, geo locations, and more.

**What it does:**
- 📱 Generate QR codes from any text or URL
- 📶 WiFi QR codes — scan to auto-connect (WPA/WEP/open)
- 👤 vCard QR codes — scan to save contact info
- 🖼️ PNG, SVG, or UTF-8 terminal output
- 🎨 Custom colors, sizes, and error correction levels
- 📦 Batch generation from file (one per line)
- 🔒 100% local — no data sent to external services
- ⚡ Sub-second generation

Perfect for developers sharing URLs in SSH sessions, sysadmins posting WiFi QRs, or anyone automating QR generation in their workflows.

## Core Capabilities

1. URL/text encoding — Any string up to ~4KB as a QR code
2. WiFi QR codes — Auto-connect format for WPA/WEP/open networks
3. vCard contact cards — Name, phone, email, URL in scannable format
4. PNG output — Configurable pixel size for print or screen
5. SVG output — Scalable vector for any resolution
6. Terminal display — UTF-8 art, no file needed
7. Batch mode — Generate hundreds from a text file
8. Custom styling — Foreground/background colors, error correction
9. Pipe-friendly — Reads from stdin, writes to stdout
10. Cross-platform install — apt, brew, dnf, pacman, apk

## Dependencies
- `qrencode` (3.4+)
- `bash` (4.0+)

## Installation Time
**2 minutes** — one package install
