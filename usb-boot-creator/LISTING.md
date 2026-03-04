# Listing Copy: USB Boot Creator

## Metadata
- **Type:** Skill
- **Name:** usb-boot-creator
- **Display Name:** USB Boot Creator
- **Categories:** [dev-tools, automation]
- **Price:** $8
- **Dependencies:** [bash, curl, dd, lsblk, sha256sum]

## Tagline

Create bootable USB drives — Flash ISOs or set up multi-boot with Ventoy

## Description

Creating bootable USB drives shouldn't require hunting for the right tool, downloading sketchy apps, or wondering if your ISO is corrupted. You need a simple, reliable way to flash ISOs and manage multi-boot USB sticks.

USB Boot Creator handles the entire workflow: detect USB drives safely (never touches your system drive), download ISOs from official sources, verify SHA256 checksums, and flash with progress indication. Need multiple operating systems on one USB? It installs Ventoy for multi-boot support — just drop ISOs onto the drive and boot into a selection menu.

**What it does:**
- 🔍 Detect removable USB drives (with safety checks against system drives)
- 📥 Download ISOs with automatic checksum verification
- ⚡ Flash ISOs to USB with `dd` and progress tracking
- 🔄 Install Ventoy for multi-boot USB (boot multiple ISOs from one stick)
- 📋 Copy multiple ISOs to Ventoy drives in one command
- 💾 Backup existing USB drives to compressed images
- 🔐 SHA256/SHA512/MD5 checksum verification
- 📊 Built-in list of popular Linux distro ISO URLs

Perfect for developers, sysadmins, and Linux enthusiasts who regularly create bootable drives for installs, rescues, or testing.

## Quick Start Preview

```bash
# List USB drives
bash scripts/usb-boot.sh list-drives

# Flash an ISO
sudo bash scripts/usb-boot.sh flash --iso ubuntu.iso --drive /dev/sdb

# Multi-boot with Ventoy
sudo bash scripts/usb-boot.sh ventoy-install --drive /dev/sdb
bash scripts/usb-boot.sh ventoy-add --drive /dev/sdb --iso ubuntu.iso --iso fedora.iso
```

## Core Capabilities

1. Drive detection — Safely identifies removable USB drives only
2. ISO flashing — Write ISOs with dd, progress bar, and sync
3. Ventoy multi-boot — Install Ventoy for booting multiple ISOs from one USB
4. Checksum verification — SHA256/SHA512/MD5 with auto-fetch from URLs
5. ISO download — Fetch ISOs with progress and automatic verification
6. Drive backup — Compressed image backup before flashing
7. Safety guards — Refuses to touch system drives, mounted partitions, or mismatched sizes
8. Popular ISOs list — Quick reference for Ubuntu, Fedora, Debian, Arch, and more
9. Secure Boot support — Ventoy installation with Secure Boot enabled
10. Zero dependencies — Uses standard Linux tools (curl, dd, lsblk)

## Dependencies
- `bash` (4.0+), `curl`, `dd`, `lsblk`, `sha256sum`
- Optional: `pv` (progress bars), `jq` (Ventoy version detection)

## Installation Time
**2 minutes** — No installation needed, just run the script

## Pricing Justification

**Why $8:**
- Essential tool for any Linux user who installs/tests distros
- Replaces Etcher, Rufus, and manual dd commands
- Multi-boot via Ventoy is a premium feature
- One-time purchase vs recurring need
