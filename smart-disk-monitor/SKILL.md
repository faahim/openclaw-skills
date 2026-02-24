---
name: smart-disk-monitor
description: >-
  Monitor disk health using SMART data — detect failing drives before data loss.
categories: [automation, security]
dependencies: [smartmontools, bash, jq]
---

# SMART Disk Health Monitor

## What This Does

Monitors your hard drives and SSDs using SMART (Self-Monitoring, Analysis, and Reporting Technology) data. Detects early signs of disk failure — reallocated sectors, pending sectors, temperature spikes, wear leveling — and alerts you before you lose data.

**Example:** "Check all drives daily, alert via Telegram if any SMART attribute crosses a warning threshold, track disk health history over time."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install smartmontools (provides smartctl)
# Ubuntu/Debian
sudo apt-get install -y smartmontools jq

# CentOS/RHEL
sudo yum install -y smartmontools jq

# macOS
brew install smartmontools jq

# Verify
smartctl --version
```

### 2. Check a Single Disk

```bash
# List available disks
bash scripts/run.sh --list

# Check a specific disk
sudo bash scripts/run.sh --disk /dev/sda

# Output:
# [2026-02-24 04:53:00] 📊 SMART Report: /dev/sda
# Model: Samsung SSD 870 EVO 1TB
# Health: ✅ PASSED
# Temperature: 34°C
# Power-On Hours: 8,432
# Reallocated Sectors: 0
# Wear Leveling: 97%
```

### 3. Monitor All Disks

```bash
# Check all disks at once
sudo bash scripts/run.sh --all

# With Telegram alerts on issues
export TELEGRAM_BOT_TOKEN="<your-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"
sudo bash scripts/run.sh --all --alert telegram
```

## Core Workflows

### Workflow 1: Full Health Check

**Use case:** Get a complete health report for all drives

```bash
sudo bash scripts/run.sh --all --verbose
```

**Output:**
```
═══════════════════════════════════════════════
  SMART Disk Health Report — 2026-02-24 04:53
═══════════════════════════════════════════════

Drive: /dev/sda (Samsung SSD 870 EVO 1TB)
  Health Status:    ✅ PASSED
  Temperature:      34°C (OK)
  Power-On Hours:   8,432
  Power Cycles:     1,247
  Reallocated:      0 sectors (OK)
  Pending Sectors:  0 (OK)
  Wear Leveling:    97% remaining
  Written:          12.4 TB total

Drive: /dev/sdb (WDC WD40EFRX-68N32N0)
  Health Status:    ✅ PASSED
  Temperature:      38°C (OK)
  Power-On Hours:   24,891
  Spin Retries:     0 (OK)
  Reallocated:      0 sectors (OK)
  Pending Sectors:  0 (OK)
  Seek Error Rate:  Normal

═══════════════════════════════════════════════
  Summary: 2 drives checked, 0 warnings, 0 critical
═══════════════════════════════════════════════
```

### Workflow 2: Alert on Degradation

**Use case:** Get notified when a drive starts failing

```bash
sudo bash scripts/run.sh --all --alert telegram --thresholds scripts/thresholds.json
```

**Alert example:**
```
🚨 SMART Alert: /dev/sdb
Drive: WDC WD40EFRX-68N32N0
⚠️ Reallocated Sectors: 8 (threshold: 0)
⚠️ Temperature: 52°C (threshold: 50°C)
Action: Back up data immediately. Drive showing early failure signs.
```

### Workflow 3: Track Health Over Time

**Use case:** Log SMART data daily, detect trends

```bash
# Log to history file
sudo bash scripts/run.sh --all --log /var/log/smart-history.jsonl

# View trends
bash scripts/trend.sh /var/log/smart-history.jsonl /dev/sda
```

**Output:**
```
Temperature trend (last 30 days):
  Min: 31°C | Avg: 35°C | Max: 42°C | Trend: ↗ +2°C/month

Reallocated sectors trend:
  Current: 0 | 30 days ago: 0 | Trend: → stable

Wear leveling trend (SSD):
  Current: 97% | 30 days ago: 98% | Rate: -1%/month
  Estimated life remaining: ~8 years
```

### Workflow 4: Run as Cron Job

```bash
# Daily health check at 6am with alerts
echo '0 6 * * * root /path/to/scripts/run.sh --all --alert telegram --log /var/log/smart-history.jsonl' | sudo tee /etc/cron.d/smart-monitor

# Weekly deep test (runs SMART extended self-test)
echo '0 2 * * 0 root /path/to/scripts/run.sh --all --self-test long' | sudo tee /etc/cron.d/smart-test
```

## Configuration

### Thresholds File (JSON)

```json
{
  "temperature_warn": 50,
  "temperature_crit": 60,
  "reallocated_warn": 1,
  "reallocated_crit": 10,
  "pending_warn": 1,
  "pending_crit": 5,
  "wear_level_warn": 20,
  "wear_level_crit": 10,
  "power_on_hours_warn": 35000,
  "power_on_hours_crit": 50000
}
```

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Custom thresholds file
export SMART_THRESHOLDS="/path/to/thresholds.json"

# History log location
export SMART_LOG="/var/log/smart-history.jsonl"
```

## Critical SMART Attributes Monitored

| ID | Attribute | What It Means | Bad Sign |
|----|-----------|---------------|----------|
| 5 | Reallocated Sectors | Bad sectors remapped to spares | Any increase |
| 10 | Spin Retry Count | Drive struggles to spin up | > 0 |
| 187 | Reported Uncorrectable | Errors that couldn't be fixed | Any increase |
| 188 | Command Timeout | Drive stopped responding | > 0 |
| 190/194 | Temperature | Drive temperature in °C | > 50°C |
| 196 | Reallocation Events | How often remapping happened | Any increase |
| 197 | Current Pending Sectors | Bad sectors waiting for remap | > 0 |
| 198 | Offline Uncorrectable | Bad sectors found in offline test | > 0 |
| 199 | UDMA CRC Errors | Cable/connection issues | Any increase |
| 231 | SSD Life Left | Remaining write endurance | < 20% |
| 233 | Media Wearout | Total writes vs rated endurance | High values |

## Troubleshooting

### Issue: "smartctl: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install -y smartmontools

# CentOS/RHEL
sudo yum install -y smartmontools
```

### Issue: "Permission denied"

SMART requires root access:
```bash
sudo bash scripts/run.sh --all
```

### Issue: "SMART not supported" on virtual machine

Virtual disks don't have SMART data. This tool is for physical disks only. Check with:
```bash
sudo smartctl -i /dev/sda | grep "SMART support"
```

### Issue: NVMe drives not detected

NVMe drives use a different path:
```bash
sudo bash scripts/run.sh --disk /dev/nvme0n1
# Or auto-detect:
sudo bash scripts/run.sh --all  # includes NVMe
```

## Dependencies

- `smartmontools` (provides `smartctl` — the core SMART tool)
- `bash` (4.0+)
- `jq` (JSON parsing for config/logs)
- `curl` (for Telegram alerts, optional)
- Root/sudo access (SMART requires hardware access)
