# Listing Copy: Swap & Memory Manager

## Metadata
- **Type:** Skill
- **Name:** swap-manager
- **Display Name:** Swap & Memory Manager
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [bash, util-linux]
- **Icon:** 🧠

## Tagline
Create, optimize, and monitor swap & memory — prevent OOM kills on any Linux server

## Description

Running a VPS or server without proper swap is a ticking time bomb. One traffic spike and the OOM killer takes out your database. Manually creating swap files, tuning swappiness, and monitoring memory pressure means SSH'ing in and remembering a dozen commands.

Swap & Memory Manager handles all of it in one script. Create optimally-sized swap files, enable zram for compressed in-memory swap, tune kernel parameters, and monitor for low-memory conditions — all with simple commands your OpenClaw agent can run.

**What it does:**
- 🔧 Create, resize, and remove swap files with fstab persistence
- ⚡ Enable zram (compressed swap in RAM — 2-3x effective capacity)
- 🎛️ Tune swappiness and vfs_cache_pressure with persistence
- 🤖 Auto-detect RAM and configure optimal settings
- 📊 Detailed memory reports (top consumers, swap usage by process, kernel memory)
- 🚨 Memory pressure monitoring with custom alert hooks (Telegram, ntfy, Slack)
- ⏰ Cron-ready one-shot checks for scheduled monitoring

Perfect for developers, sysadmins, and anyone running Linux servers who wants reliable memory management without memorizing sysctl commands.

## Core Capabilities

1. Swap file creation — fallocate with dd fallback, auto-fstab persistence
2. Swap resizing — safe disable-recreate-enable workflow
3. Zram setup — compressed in-memory swap with priority configuration
4. Optimal auto-setup — detects RAM, creates right-sized swap, tunes kernel
5. Swappiness tuning — runtime + persistent via sysctl.d
6. Memory reporting — top consumers, swap-per-process, kernel breakdown
7. Continuous monitoring — configurable threshold and interval
8. Cron-ready checks — one-shot memory threshold check with exit codes
9. Custom alerts — hook any notification service via --on-alert
10. Clean removal — swap disable, file delete, fstab cleanup

## Installation Time
**2 minutes** — Copy script, run `status` to see current state
