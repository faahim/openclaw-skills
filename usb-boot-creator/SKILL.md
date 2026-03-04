---
name: usb-boot-creator
description: >-
  Create bootable USB drives with Ventoy or dd. Download ISOs, verify checksums, flash drives, and manage multi-boot USB sticks.
categories: [dev-tools, automation]
dependencies: [bash, curl, jq, dd, sha256sum]
---

# USB Boot Creator

## What This Does

Create bootable USB drives from ISO images — either single-boot with `dd` or multi-boot with Ventoy. Downloads ISOs from official sources, verifies checksums, detects USB drives, and flashes them safely.

**Example:** "Download Ubuntu 24.04 ISO, verify its SHA256, flash to /dev/sdb with progress indicator."

## Quick Start (5 minutes)

### 1. List Connected USB Drives

```bash
bash scripts/usb-boot.sh list-drives
```

**Output:**
```
USB Drives Detected:
  /dev/sdb — SanDisk Ultra (32GB) — NOT mounted
  /dev/sdc — Kingston DataTraveler (16GB) — Mounted at /mnt/usb
```

### 2. Flash an ISO (Single Boot with dd)

```bash
# Flash an ISO to a USB drive
sudo bash scripts/usb-boot.sh flash \
  --iso ~/Downloads/ubuntu-24.04-desktop-amd64.iso \
  --drive /dev/sdb
```

**Output:**
```
⚠️  WARNING: All data on /dev/sdb (SanDisk Ultra 32GB) will be erased!
Type 'YES' to confirm: YES
[████████████████████████████] 100% — 4.7GB written (12m 34s)
✅ USB drive /dev/sdb is now bootable with Ubuntu 24.04
```

### 3. Download + Verify + Flash (All-in-One)

```bash
sudo bash scripts/usb-boot.sh auto \
  --distro ubuntu-24.04 \
  --drive /dev/sdb
```

This downloads the ISO, verifies SHA256, and flashes — all in one command.

## Core Workflows

### Workflow 1: Download ISO with Checksum Verification

```bash
bash scripts/usb-boot.sh download \
  --url "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso" \
  --checksum "sha256:abc123..." \
  --output ~/ISOs/
```

**Output:**
```
📥 Downloading ubuntu-24.04-desktop-amd64.iso...
[████████████████████████████] 100% — 4.7GB (15m 22s)
🔐 Verifying SHA256 checksum...
✅ Checksum verified: abc123...
💾 Saved to ~/ISOs/ubuntu-24.04-desktop-amd64.iso
```

### Workflow 2: Install Ventoy (Multi-Boot USB)

```bash
# Install Ventoy to a USB drive (enables multi-boot)
sudo bash scripts/usb-boot.sh ventoy-install \
  --drive /dev/sdb \
  --secure-boot
```

**Output:**
```
📦 Downloading Ventoy v1.0.99...
✅ Ventoy installed on /dev/sdb
ℹ️  Now copy any ISO files to the Ventoy partition.
   The USB will boot into a menu letting you choose which ISO to run.
```

### Workflow 3: Add ISOs to Ventoy Drive

```bash
# Copy ISOs to a Ventoy-prepared USB
bash scripts/usb-boot.sh ventoy-add \
  --drive /dev/sdb \
  --iso ~/ISOs/ubuntu-24.04-desktop-amd64.iso \
  --iso ~/ISOs/fedora-40-workstation.iso \
  --iso ~/ISOs/archlinux-2024.06.01-x86_64.iso
```

**Output:**
```
📂 Mounting Ventoy partition...
📋 Copying 3 ISOs to /dev/sdb1:
  [1/3] ubuntu-24.04-desktop-amd64.iso (4.7GB) ✅
  [2/3] fedora-40-workstation.iso (2.1GB) ✅
  [3/3] archlinux-2024.06.01-x86_64.iso (860MB) ✅
✅ 3 ISOs added. USB is ready for multi-boot.
```

### Workflow 4: List Popular ISOs

```bash
bash scripts/usb-boot.sh list-isos
```

**Output:**
```
Popular Linux ISOs:
  ubuntu-24.04     — https://releases.ubuntu.com/24.04/...
  fedora-40        — https://download.fedoraproject.org/...
  debian-12        — https://cdimage.debian.org/...
  archlinux-latest — https://archlinux.org/download/
  linuxmint-22     — https://linuxmint.com/download.php
  nixos-24.05      — https://nixos.org/download/

Rescue/Utility ISOs:
  clonezilla       — https://clonezilla.org/downloads/...
  gparted-live     — https://gparted.org/download.php
  systemrescue     — https://www.system-rescue.org/...
  memtest86+       — https://www.memtest.org/
```

### Workflow 5: Verify Existing ISO

```bash
bash scripts/usb-boot.sh verify \
  --iso ~/ISOs/ubuntu-24.04-desktop-amd64.iso \
  --checksum-url "https://releases.ubuntu.com/24.04/SHA256SUMS"
```

## Configuration

### Environment Variables

```bash
# Default ISO download directory
export USB_BOOT_ISO_DIR="$HOME/ISOs"

# Skip confirmation prompts (DANGEROUS)
export USB_BOOT_NO_CONFIRM=false

# Ventoy version (auto-detects latest if not set)
export VENTOY_VERSION="1.0.99"
```

### Supported Distros (Auto-Download)

The `auto` command supports these distros with automatic URL + checksum resolution:

| Distro | Slug | Size |
|--------|------|------|
| Ubuntu 24.04 LTS | `ubuntu-24.04` | 4.7 GB |
| Fedora 40 | `fedora-40` | 2.1 GB |
| Debian 12 | `debian-12` | 3.7 GB |
| Arch Linux | `archlinux` | ~860 MB |
| Linux Mint 22 | `linuxmint-22` | 2.8 GB |
| Pop!_OS 22.04 | `popos-22.04` | 2.5 GB |

## Advanced Usage

### Create Windows Bootable USB

```bash
# For Windows ISOs, use Ventoy (dd won't work for NTFS)
sudo bash scripts/usb-boot.sh ventoy-install --drive /dev/sdb
bash scripts/usb-boot.sh ventoy-add --drive /dev/sdb --iso ~/ISOs/Win11_23H2.iso
```

### Backup USB Before Flashing

```bash
# Create a full image backup of the USB drive first
sudo bash scripts/usb-boot.sh backup \
  --drive /dev/sdb \
  --output ~/backups/usb-backup-$(date +%Y%m%d).img.gz
```

### Write Image with Custom Block Size

```bash
sudo bash scripts/usb-boot.sh flash \
  --iso ~/ISOs/custom.iso \
  --drive /dev/sdb \
  --bs 4M \
  --sync
```

## Troubleshooting

### Issue: "Permission denied"

**Fix:** Run with `sudo` — flashing drives requires root access.

### Issue: Drive not detected

**Check:**
1. Drive is plugged in: `lsblk`
2. Not a system drive: `findmnt /`
3. Drive isn't mounted: `umount /dev/sdbX` first

### Issue: "Drive is mounted"

**Fix:** The script will warn you. Unmount first:
```bash
sudo umount /dev/sdb*
```

### Issue: Ventoy download fails

**Fix:** Set version manually:
```bash
export VENTOY_VERSION="1.0.99"
sudo bash scripts/usb-boot.sh ventoy-install --drive /dev/sdb
```

## Safety Features

- **Drive detection** — Only lists removable USB devices (won't show /dev/sda)
- **Size check** — Warns if ISO is larger than USB capacity
- **Confirmation prompt** — Always asks before erasing (unless USB_BOOT_NO_CONFIRM=true)
- **Checksum verification** — Validates ISOs before flashing
- **Mount check** — Refuses to flash mounted drives

## Dependencies

- `bash` (4.0+)
- `curl` (downloading ISOs)
- `dd` (flashing)
- `sha256sum` / `md5sum` (verification)
- `lsblk` / `blkid` (drive detection)
- `pv` (optional — progress bar, installed automatically if missing)
- `jq` (JSON parsing for distro list)
