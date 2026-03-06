---
name: zram-manager
description: >-
  Configure and manage ZRAM compressed swap for better memory utilization on low-RAM servers, VPS, and Raspberry Pi.
categories: [automation, dev-tools]
dependencies: [bash, modprobe, zramctl]
---

# ZRAM Manager

## What This Does

Configures ZRAM — compressed swap space in RAM — so your server handles memory pressure without hitting slow disk swap. Essential for VPS instances, Raspberry Pis, and containers with limited RAM. ZRAM compresses memory pages in-place, giving you 2-4x effective RAM increase with minimal CPU overhead.

**Example:** "Turn 1GB RAM into effectively 2-3GB using ZRAM compression, with automatic setup that survives reboots."

## Quick Start (2 minutes)

### 1. Check Current Memory Setup

```bash
bash scripts/zram-manager.sh status
```

**Output:**
```
=== Memory Status ===
Total RAM: 2048 MB
Used RAM:  1234 MB (60%)
Swap:      0 MB (no swap configured)
ZRAM:      Not configured

Recommendation: Enable ZRAM with 1024 MB (50% of RAM)
```

### 2. Enable ZRAM

```bash
# Auto-configure (50% of RAM, zstd compression)
sudo bash scripts/zram-manager.sh enable

# Or specify size and algorithm
sudo bash scripts/zram-manager.sh enable --size 1G --algo zstd
```

**Output:**
```
✅ ZRAM device created: /dev/zram0
   Size: 1024 MB
   Algorithm: zstd
   Priority: 100 (preferred over disk swap)
   Status: Active
```

### 3. Make Persistent (Survives Reboots)

```bash
sudo bash scripts/zram-manager.sh persist
```

## Core Workflows

### Workflow 1: Enable ZRAM on a VPS

**Use case:** Your 1-2GB VPS runs out of memory under load

```bash
# Check current state
bash scripts/zram-manager.sh status

# Enable with zstd compression (best ratio)
sudo bash scripts/zram-manager.sh enable --size 1G --algo zstd

# Make it persist across reboots
sudo bash scripts/zram-manager.sh persist
```

### Workflow 2: Replace Disk Swap with ZRAM

**Use case:** You have slow disk swap and want faster compressed swap

```bash
# Disable disk swap, enable ZRAM
sudo bash scripts/zram-manager.sh replace-swap

# This will:
# 1. Disable existing disk swap
# 2. Create ZRAM device at 50% of RAM
# 3. Set ZRAM as primary swap (higher priority)
# 4. Optionally keep disk swap as fallback
```

### Workflow 3: Monitor ZRAM Performance

**Use case:** Check how well ZRAM is working

```bash
bash scripts/zram-manager.sh stats
```

**Output:**
```
=== ZRAM Statistics ===
Device: /dev/zram0
Algorithm: zstd
Disk Size: 1024 MB
Compressed: 456 MB → 178 MB (2.56:1 ratio)
Zero Pages: 12340 (memory saved from zero-filled pages)
Read/Write: 89432 / 45678
CPU overhead: ~2% (minimal)
```

### Workflow 4: Tune for Raspberry Pi

**Use case:** Maximize RAM on a Pi with 1-4GB

```bash
# Pi-optimized settings (lz4 for lower CPU, 75% of RAM)
sudo bash scripts/zram-manager.sh enable --size 75% --algo lz4 --streams 4
sudo bash scripts/zram-manager.sh persist
```

### Workflow 5: Disable ZRAM

```bash
# Remove ZRAM and restore previous swap
sudo bash scripts/zram-manager.sh disable

# Also remove persistence
sudo bash scripts/zram-manager.sh disable --purge
```

## Configuration

### Compression Algorithms

| Algorithm | Ratio | Speed | CPU | Best For |
|-----------|-------|-------|-----|----------|
| `zstd` | Best (3-4x) | Fast | Low | VPS, servers (recommended) |
| `lz4` | Good (2-3x) | Fastest | Minimal | Raspberry Pi, low-power |
| `lzo` | Good (2-3x) | Fast | Low | General purpose |
| `lzo-rle` | Good (2-3x) | Fast | Low | Default on many distros |
| `zlib` | Best (3-5x) | Slow | High | Max compression (not recommended) |

### Size Guidelines

| Total RAM | Recommended ZRAM | Effective Total |
|-----------|-----------------|-----------------|
| 512 MB | 256 MB (50%) | ~768 MB |
| 1 GB | 512 MB (50%) | ~1.5 GB |
| 2 GB | 1 GB (50%) | ~3 GB |
| 4 GB | 2 GB (50%) | ~6 GB |
| 8 GB+ | 4 GB (50%) | ~12 GB |

### Environment Variables

```bash
# Override defaults
export ZRAM_SIZE="1G"           # Fixed size
export ZRAM_SIZE_PERCENT="50"   # Or percentage of RAM
export ZRAM_ALGO="zstd"         # Compression algorithm
export ZRAM_STREAMS="4"         # Compression streams (default: nproc)
export ZRAM_PRIORITY="100"      # Swap priority (higher = preferred)
```

## Advanced Usage

### Multiple ZRAM Devices

```bash
# Create multiple devices for parallel compression
sudo bash scripts/zram-manager.sh enable --devices 4 --size 256M --algo zstd
```

### Custom Sysctl Tuning

```bash
# Optimize kernel swap behavior for ZRAM
sudo bash scripts/zram-manager.sh tune

# Sets:
# vm.swappiness = 180 (aggressive ZRAM usage — fine since it's in RAM)
# vm.watermark_boost_factor = 0
# vm.watermark_scale_factor = 125
# vm.page-cluster = 0 (disable readahead for swap, not needed for ZRAM)
```

### Integration with OpenClaw Cron

```bash
# Monitor ZRAM and alert if compression ratio drops
# Add to OpenClaw cron (check every hour):
bash scripts/zram-manager.sh check --min-ratio 1.5 --alert
```

## Troubleshooting

### Issue: "modprobe: FATAL: Module zram not found"

**Fix:** Install zram kernel module
```bash
# Ubuntu/Debian
sudo apt-get install linux-modules-extra-$(uname -r)
sudo modprobe zram

# If still missing, your kernel may not support ZRAM
uname -r  # Check kernel version (needs 3.14+)
```

### Issue: "Cannot create ZRAM device"

**Check:**
```bash
# Verify module is loaded
lsmod | grep zram

# Check if zram devices exist
ls /dev/zram*

# Check kernel config
grep ZRAM /boot/config-$(uname -r) 2>/dev/null || zgrep ZRAM /proc/config.gz 2>/dev/null
```

### Issue: High CPU usage with ZRAM

**Fix:** Switch to a faster algorithm
```bash
sudo bash scripts/zram-manager.sh disable
sudo bash scripts/zram-manager.sh enable --algo lz4  # Fastest, lowest CPU
```

### Issue: OOM killer still triggers

**Fix:** ZRAM is full. Increase size or add disk swap as fallback
```bash
sudo bash scripts/zram-manager.sh disable
sudo bash scripts/zram-manager.sh enable --size 75%  # Increase from 50% to 75%
```

## Dependencies

- `bash` (4.0+)
- `zramctl` (util-linux, usually pre-installed)
- `modprobe` (kmod, usually pre-installed)
- Linux kernel 3.14+ with ZRAM support
- Root/sudo access for device creation
