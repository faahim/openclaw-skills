# Listing Copy: ZRAM Manager

## Metadata
- **Type:** Skill
- **Name:** zram-manager
- **Display Name:** ZRAM Manager
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [bash, zramctl, modprobe]
- **Icon:** 🗜️

## Tagline

Compressed swap in RAM — Double your effective memory without adding hardware

## Description

Running out of memory on your VPS, Raspberry Pi, or container? Disk swap is painfully slow and wears out SSDs. ZRAM creates compressed swap space directly in RAM, giving you 2-4x more effective memory with minimal CPU overhead.

ZRAM Manager handles everything: loading the kernel module, configuring compression, setting up swap priorities, and making it persistent across reboots. One command to enable, one to persist. No manual sysctl tuning, no systemd unit files to write.

**What it does:**
- 🗜️ Create compressed swap in RAM (2-4x compression ratio)
- ⚡ zstd, lz4, lzo compression algorithms
- 🔄 Replace slow disk swap with fast ZRAM
- 📊 Monitor compression ratio and memory savings
- 🔧 Auto-tune kernel parameters for ZRAM
- 💾 Persist across reboots via systemd
- 🍓 Pi-optimized presets (lz4 for low CPU)
- 🏥 Health checks for cron monitoring

Perfect for VPS operators, Raspberry Pi enthusiasts, and anyone running services on limited-RAM machines.

## Quick Start Preview

```bash
# Check current memory status
bash scripts/zram-manager.sh status

# Enable ZRAM (50% of RAM, zstd compression)
sudo bash scripts/zram-manager.sh enable

# Make persistent across reboots
sudo bash scripts/zram-manager.sh persist

# Check compression stats
bash scripts/zram-manager.sh stats
```

## Dependencies
- `bash` (4.0+)
- `zramctl` (util-linux)
- `modprobe` (kmod)
- Linux kernel 3.14+

## Installation Time
**2 minutes** — No packages to install, just run the script
