# Listing Copy: USB Auto-Mount Manager

## Metadata
- **Type:** Skill
- **Name:** usb-automount
- **Display Name:** USB Auto-Mount Manager
- **Categories:** [home, automation]
- **Icon:** 🔌
- **Price:** $8
- **Dependencies:** [bash, udevadm, lsblk, systemd]

## Tagline

Automatically mount USB drives with custom paths, permissions, and hook scripts.

## Description

Plugging in a USB drive shouldn't require opening a terminal and typing mount commands. But on headless servers, Raspberry Pis, and minimal Linux setups, that's exactly what happens.

USB Auto-Mount Manager installs udev rules and a systemd service that automatically detect USB drives, mount them to organized paths (`/media/usb/<label>`), and handle permissions correctly. No desktop environment needed.

**What it does:**
- 🔌 Auto-mount USB drives on plug-in (udev + systemd)
- 📁 Organized mount points by drive label or UUID
- 🔐 Configurable ownership and permissions per filesystem
- 🪝 Hook scripts — run backups, sync, or notify on mount/unmount
- 📋 Mount history logging via systemd journal
- 💿 Safe eject with power-off support
- ⚙️ Per-device overrides and ignore lists
- 🧹 Auto-cleanup on unplug

**Supported filesystems:** ext4, btrfs, xfs, vfat (FAT32), exFAT, NTFS

## Quick Start Preview

```bash
# Install (one command)
sudo bash scripts/install.sh

# Plug in a USB drive...
# → Auto-mounts to /media/usb/MyDrive

# List connected USB devices
bash scripts/run.sh list

# Safely eject
bash scripts/run.sh eject sdb
```

## Core Capabilities

1. Automatic USB detection — udev rules trigger on plug-in/removal
2. Smart mount paths — Uses drive label, falls back to UUID
3. Filesystem-aware options — Correct mount flags for FAT32, NTFS, ext4, etc.
4. Hook scripts — Trigger backups or notifications on mount/unmount
5. Per-device config — Custom paths and permissions per drive
6. Ignore list — Skip specific drives from auto-mounting
7. Safe eject — Unmount + power-off in one command
8. History logging — Track all mount/unmount events
9. Headless-friendly — No desktop environment required
10. Clean uninstall — Remove everything with one command

## Dependencies

- `bash` (4.0+)
- `udevadm` (udev)
- `lsblk`, `blkid`, `findmnt` (util-linux)
- `systemd`
- Optional: `udisks2`, `ntfs-3g`, `exfatprogs`

## Installation Time

**2 minutes** — Run install script, done.

## Pricing Justification

**Why $8:**
- Saves manual mount/unmount on every USB insertion
- Essential for headless servers and Raspberry Pi setups
- Includes hook system for backup automation
- One-time payment vs recurring headaches
