---
name: swap-manager
description: >-
  Create, resize, and optimize swap files and zram. Monitor memory pressure and get alerts before OOM kills.
categories: [automation, dev-tools]
dependencies: [bash, free, swapon, fallocate]
---

# Swap & Memory Manager

## What This Does

Automates swap file creation, resizing, and optimization on Linux servers. Configures zram for compressed in-memory swap, tunes swappiness and memory pressure settings, and monitors for low-memory conditions with alerts.

**Example:** "Create a 4G swap file, enable zram, set swappiness to 10, alert me if free memory drops below 200MB."

## Quick Start (2 minutes)

### 1. Check Current Memory & Swap

```bash
bash scripts/swap-manager.sh status
```

**Output:**
```
═══ Memory & Swap Status ═══
RAM:  Total: 4096MB  Used: 2847MB  Free: 1249MB  (69% used)
Swap: Total: 0MB     Used: 0MB     Free: 0MB
Swappiness: 60
VFS Cache Pressure: 100

Active swap devices:
  (none)

Recommendations:
  ⚠️  No swap configured — OOM kills likely under load
  ⚠️  Swappiness=60 is high for SSD systems (recommend 10-20)
```

### 2. Create Swap File

```bash
# Create a 2G swap file (requires sudo)
sudo bash scripts/swap-manager.sh create --size 2G
```

**Output:**
```
[✓] Creating 2G swap file at /swapfile...
[✓] Setting permissions (600)...
[✓] Formatting as swap...
[✓] Enabling swap...
[✓] Adding to /etc/fstab for persistence...
[✓] Swap file active!

New status:
Swap: Total: 2048MB  Used: 0MB  Free: 2048MB
```

### 3. Tune Swappiness

```bash
# Set swappiness to 10 (good for SSD servers)
sudo bash scripts/swap-manager.sh tune --swappiness 10
```

## Core Workflows

### Workflow 1: Full Server Setup (New VPS)

**Use case:** Fresh VPS with no swap — set up everything optimally

```bash
sudo bash scripts/swap-manager.sh setup-optimal
```

This auto-detects RAM and:
- Creates swap file (2x RAM if ≤2GB, 1x RAM if ≤8GB, 4GB if >8GB)
- Sets swappiness to 10 (SSD) or 60 (HDD)
- Sets vfs_cache_pressure to 50
- Persists all settings across reboots

### Workflow 2: Enable Zram (Compressed Swap in RAM)

**Use case:** Get more effective swap using compression — great for low-RAM servers

```bash
sudo bash scripts/swap-manager.sh zram --enable --size 50
```

Allocates 50% of RAM as zram (compressed, ~2-3x effective capacity).

### Workflow 3: Resize Existing Swap

**Use case:** Running low on swap, need to increase

```bash
sudo bash scripts/swap-manager.sh resize --size 4G
```

Safely disables old swap, creates new file, re-enables.

### Workflow 4: Memory Pressure Monitor

**Use case:** Get alerted before OOM killer strikes

```bash
bash scripts/swap-manager.sh monitor --threshold 200 --interval 30
```

Checks every 30 seconds. When available memory drops below 200MB:
```
🚨 LOW MEMORY ALERT — Available: 142MB (threshold: 200MB)
  Top consumers:
    PID 1234  mysqld    — 1.2GB
    PID 5678  node      — 890MB
    PID 9012  redis     — 340MB
```

### Workflow 5: Memory Report

**Use case:** Understand what's eating memory

```bash
bash scripts/swap-manager.sh report
```

**Output:**
```
═══ Memory Report ═══
RAM:  4096MB total — 2847MB used (69%)
Swap: 2048MB total — 128MB used (6%)

Top 10 Memory Consumers:
  PID    RSS(MB)  Command
  1234   1248     mysqld
  5678   890      node /app/server.js
  9012   340      redis-server
  3456   210      python3 worker.py
  ...

Swap Usage by Process:
  PID    Swap(MB)  Command
  7890   98        java -jar app.jar
  1234   30        mysqld

Kernel Memory:
  Buffers:    128MB
  Cached:     892MB
  Slab:       156MB
  PageTables: 24MB
```

## Configuration

### Persistent Settings

The tool persists all settings via standard Linux mechanisms:
- Swap file → `/etc/fstab`
- Swappiness → `/etc/sysctl.d/99-swap-manager.conf`
- Zram → systemd service or `/etc/modules-load.d/`

### Environment Variables

```bash
# Override default swap file path
export SWAP_FILE="/var/swap/swapfile"

# Override default swappiness for setup-optimal
export SWAP_SWAPPINESS=10

# Alert destination (optional)
export SWAP_ALERT_CMD="curl -s https://ntfy.sh/my-alerts -d"
```

## Advanced Usage

### Remove Swap

```bash
sudo bash scripts/swap-manager.sh remove
# Disables swap, removes from fstab, deletes file
```

### Disable Zram

```bash
sudo bash scripts/swap-manager.sh zram --disable
```

### Run Monitor as Cron

```bash
# Check every 5 minutes, alert if <300MB available
*/5 * * * * bash /path/to/scripts/swap-manager.sh check --threshold 300 >> /var/log/swap-monitor.log 2>&1
```

### Custom Alert Hook

```bash
# Send alert to Telegram/Slack/ntfy on low memory
bash scripts/swap-manager.sh monitor \
  --threshold 200 \
  --interval 60 \
  --on-alert 'curl -s "https://ntfy.sh/alerts" -d "Low memory: ${AVAILABLE_MB}MB free"'
```

## Troubleshooting

### Issue: "swapon: /swapfile: Operation not permitted"

**Fix:** You're likely on a VPS with swap disabled by the provider. Check:
```bash
cat /proc/sys/vm/swappiness
# If this fails, the kernel doesn't support swap modification
```

Some providers (like certain OpenVZ containers) don't allow swap. Use zram instead.

### Issue: "fallocate: fallocate failed: Operation not supported"

**Fix:** Filesystem doesn't support fallocate (common on ZFS/BTRFS). The script auto-falls back to `dd`:
```bash
dd if=/dev/zero of=/swapfile bs=1M count=2048
```

### Issue: Swap is enabled but never used

**Fix:** Swappiness might be 0. Check and adjust:
```bash
cat /proc/sys/vm/swappiness
sudo bash scripts/swap-manager.sh tune --swappiness 10
```

## Dependencies

- `bash` (4.0+)
- `free`, `swapon`, `swapoff` (util-linux — pre-installed on all Linux)
- `fallocate` or `dd` (for creating swap files)
- `mkswap` (for formatting swap — pre-installed)
- Optional: `zramctl` (for zram — usually pre-installed on modern kernels)
- **Requires:** Linux (not macOS/Windows)
- **Requires:** `sudo` for write operations
