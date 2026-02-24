# Listing Copy: SMART Disk Health Monitor

## Metadata
- **Type:** Skill
- **Name:** smart-disk-monitor
- **Display Name:** SMART Disk Health Monitor
- **Categories:** [automation, security]
- **Price:** $12
- **Dependencies:** [smartmontools, bash, jq]

## Tagline

"Monitor disk health with SMART data — detect failing drives before you lose data"

## Description

Hard drives and SSDs fail. Usually without warning. By the time you notice, your data is gone. SMART (Self-Monitoring, Analysis, and Reporting Technology) data can predict disk failure weeks or months in advance — but nobody checks it manually.

SMART Disk Health Monitor automates the entire process. It reads SMART attributes from all your drives (SATA, SAS, NVMe), checks them against configurable thresholds, and alerts you instantly via Telegram when something looks wrong. Reallocated sectors creeping up? Temperature spike? SSD wear leveling dropping? You'll know before it becomes a crisis.

**What it does:**
- 🔍 Scan all drives (SATA, NVMe, SAS) for SMART health data
- 🌡️ Monitor temperature, reallocated sectors, pending sectors, wear level
- 🚨 Instant Telegram alerts when thresholds are crossed
- 📊 Track health trends over time with JSONL logging
- 🔧 Run SMART self-tests (short/long) on schedule
- ⚙️ Configurable thresholds via JSON
- 📅 Cron-ready — set it and forget it
- 🖥️ Works on Linux and macOS, physical and NVMe drives

Perfect for sysadmins, homelab enthusiasts, and anyone running servers with physical disks who doesn't want to wake up to data loss.

## Core Capabilities

1. Multi-drive scanning — Detects SATA, NVMe, and SAS drives automatically
2. Health assessment — Overall SMART health pass/fail plus individual attribute checks
3. Temperature monitoring — Warn at 50°C, critical at 60°C (configurable)
4. Sector monitoring — Tracks reallocated and pending sector counts
5. SSD wear tracking — Monitors write endurance remaining percentage
6. Telegram alerts — Instant notification when any threshold is crossed
7. JSONL logging — Append results for historical trend analysis
8. Trend analysis — Visualize temperature, sector, and wear trends over time
9. Self-test automation — Schedule short/long SMART tests via cron
10. Configurable thresholds — JSON config for per-environment tuning
11. Exit codes — Returns 0 (ok), 1 (warnings), 2 (critical) for scripting
12. One-click install — Auto-installs smartmontools on major distros
