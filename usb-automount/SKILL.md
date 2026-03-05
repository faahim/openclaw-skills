---
name: usb-automount
description: >-
  Automatically mount USB drives when plugged in with custom mount points, permissions, and notifications.
categories: [home, automation]
dependencies: [bash, udevadm, systemd, udisksctl]
---

# USB Auto-Mount Manager

## What This Does

Automatically detect and mount USB drives when plugged in. Configure custom mount points, ownership, permissions, and get notifications when devices connect/disconnect. No more manually running `mount` commands.

**Example:** "Plug in a USB drive → auto-mounts to `/media/usb/<label>` → sends notification → optionally runs a backup script."

## Quick Start (5 minutes)

### 1. Check Dependencies

```bash
# These are standard on most Linux systems
which udevadm lsblk findmnt || echo "Missing tools — install udev and util-linux"

# Optional: udisks2 for user-level mounting
which udisksctl 2>/dev/null || echo "Optional: sudo apt install udisks2"
```

### 2. Install Auto-Mount Rules

```bash
# Install udev rule + mount script (requires sudo)
sudo bash scripts/install.sh
```

### 3. Test It

```bash
# Plug in a USB drive, then check:
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL

# View auto-mount logs:
journalctl -t usb-automount --since "5 minutes ago"
```

## Core Workflows

### Workflow 1: Basic Auto-Mount

**Use case:** Automatically mount any USB drive when plugged in.

```bash
# Install with defaults
sudo bash scripts/install.sh

# Drives mount to: /media/usb/<label> (or /media/usb/<uuid> if no label)
# Owned by: current user
# Permissions: 0755
```

**When you plug in a USB:**
```
[2026-03-05 14:00:00] ✅ Mounted /dev/sdb1 (MyDrive) → /media/usb/MyDrive
```

**When you unplug:**
```
[2026-03-05 14:05:00] 📤 Unmounted /dev/sdb1 (MyDrive) from /media/usb/MyDrive
```

### Workflow 2: Custom Mount Point

**Use case:** Always mount a specific drive to a specific path.

```bash
# Edit config
nano /etc/usb-automount/config.yaml

# Add mapping:
# mounts:
#   - label: "BACKUP-DRIVE"
#     path: /mnt/backups
#     owner: root
#     mode: "0700"
```

### Workflow 3: Run Script on Mount

**Use case:** Trigger a backup when a specific drive is plugged in.

```bash
# Add to config:
# mounts:
#   - label: "BACKUP-DRIVE"
#     path: /mnt/backups
#     on_mount: "/home/user/scripts/run-backup.sh"
#     on_unmount: "/home/user/scripts/backup-done.sh"
```

### Workflow 4: List Connected USB Devices

```bash
bash scripts/run.sh list
```

**Output:**
```
USB Devices:
  /dev/sdb1  MyDrive     ext4   16G  /media/usb/MyDrive     [mounted]
  /dev/sdc1  PHOTOS      vfat   64G  —                       [not mounted]
```

### Workflow 5: Manual Mount/Unmount

```bash
# Mount a specific device
bash scripts/run.sh mount /dev/sdb1

# Unmount
bash scripts/run.sh unmount /dev/sdb1

# Safely eject (unmount + power off)
bash scripts/run.sh eject /dev/sdb1
```

## Configuration

### Config File (/etc/usb-automount/config.yaml)

```yaml
# USB Auto-Mount Configuration
general:
  mount_base: /media/usb          # Base mount directory
  default_owner: 1000             # Default UID (your user)
  default_group: 1000             # Default GID
  default_mode: "0755"            # Default permissions
  auto_unmount_on_remove: true    # Clean up on unplug
  log_to_journal: true            # Log via systemd journal
  notify: true                    # Desktop notifications (if available)

# Filesystem-specific mount options
fs_options:
  vfat: "uid={owner},gid={group},umask=022,iocharset=utf8"
  ntfs: "uid={owner},gid={group},umask=022"
  ext4: "defaults"
  exfat: "uid={owner},gid={group},umask=022"
  btrfs: "defaults,compress=zstd"

# Per-device overrides (by label, UUID, or vendor:product)
mounts:
  # Example: specific drive to specific path
  # - label: "BACKUP-DRIVE"
  #   path: /mnt/backups
  #   owner: root
  #   mode: "0700"
  #   on_mount: "/path/to/script.sh"

# Ignore list — devices that should NOT be auto-mounted
ignore:
  # - label: "SYSTEM-RESERVE"
  # - uuid: "xxxx-xxxx"
```

## Advanced Usage

### Notification Integration

```bash
# Telegram notification on mount (add to config on_mount):
on_mount: "curl -s 'https://api.telegram.org/bot$BOT_TOKEN/sendMessage?chat_id=$CHAT_ID&text=USB mounted: {label} at {path}'"

# Or use any notification tool
on_mount: "notify-send 'USB Mounted' '{label} at {path}'"
```

### Auto-Backup on Mount

```bash
# Create backup script
cat > /home/user/scripts/usb-backup.sh << 'EOF'
#!/bin/bash
MOUNT_PATH="$1"
rsync -av --delete /home/user/documents/ "$MOUNT_PATH/backup/"
echo "Backup complete: $(date)" >> "$MOUNT_PATH/backup.log"
EOF
chmod +x /home/user/scripts/usb-backup.sh

# Add to config:
# mounts:
#   - label: "BACKUP"
#     path: /mnt/backup
#     on_mount: "/home/user/scripts/usb-backup.sh {path}"
```

### View Mount History

```bash
# Recent mount/unmount events
bash scripts/run.sh history

# Output:
# 2026-03-05 14:00  MOUNT    MyDrive (sdb1, ext4, 16G) → /media/usb/MyDrive
# 2026-03-05 14:05  UNMOUNT  MyDrive (sdb1) from /media/usb/MyDrive
# 2026-03-05 15:30  MOUNT    PHOTOS (sdc1, vfat, 64G) → /media/usb/PHOTOS
```

### Uninstall

```bash
sudo bash scripts/install.sh --uninstall
# Removes udev rules, systemd units, and config (with confirmation)
```

## Troubleshooting

### Issue: Drive not auto-mounting

**Check:**
1. udev rule is installed: `ls /etc/udev/rules.d/99-usb-automount.rules`
2. Service is active: `systemctl status usb-automount@`
3. Check logs: `journalctl -t usb-automount -n 20`
4. Reload rules: `sudo udevadm control --reload-rules && sudo udevadm trigger`

### Issue: Permission denied on mounted drive

**Fix:** Check `default_owner` in config matches your UID:
```bash
id -u  # Your UID
# Update config: default_owner: <your-uid>
sudo bash scripts/install.sh --reload
```

### Issue: NTFS/exFAT drives not mounting

**Fix:** Install filesystem drivers:
```bash
# Ubuntu/Debian
sudo apt install ntfs-3g exfatprogs

# Fedora/RHEL
sudo dnf install ntfs-3g exfatprogs
```

### Issue: Conflicts with desktop automounter

**Fix:** Disable the desktop automounter (GNOME/KDE):
```bash
# GNOME
gsettings set org.gnome.desktop.media-handling automount false

# Or just add desktop automounter-managed drives to the ignore list
```

## How It Works

1. **udev rule** detects USB block device add/remove events
2. **systemd instantiated service** runs the mount/unmount script
3. **Mount script** reads config, creates mount point, mounts with correct options
4. **Unmount script** cleanly unmounts and removes empty mount dirs
5. **Journal logging** tracks all events for debugging

## Dependencies

- `bash` (4.0+)
- `udevadm` (udev — standard on systemd Linux)
- `lsblk`, `blkid`, `findmnt` (util-linux)
- `mount`/`umount` (standard)
- Optional: `udisks2` (for non-root mounting)
- Optional: `ntfs-3g`, `exfatprogs` (for NTFS/exFAT support)
- Optional: `notify-send` (for desktop notifications)
