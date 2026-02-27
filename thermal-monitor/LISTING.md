# Listing Copy: Thermal Monitor

## Metadata
- **Type:** Skill
- **Name:** thermal-monitor
- **Display Name:** Thermal Monitor
- **Categories:** [automation, security]
- **Price:** $8
- **Icon:** 🌡️
- **Dependencies:** [lm-sensors, bash, curl]

## Tagline

Monitor CPU & GPU temperatures — Get instant alerts before overheating damages hardware

## Description

Overheating kills hardware silently. By the time you notice thermal throttling, your CPU has been cooking for hours. Server rooms, home labs, and even laptops need temperature monitoring — but enterprise tools cost $50+/month.

Thermal Monitor uses lm-sensors to track CPU, GPU, NVMe, and other hardware temperatures in real-time. Set warning and critical thresholds, get instant alerts via Telegram, email, or webhook. Log thermal data as CSV for trend analysis.

**What it does:**
- 🌡️ Monitor all hardware sensors (CPU, GPU, NVMe, motherboard)
- ⚠️ Configurable warning and critical temperature thresholds
- 🔔 Instant alerts via Telegram, email, or webhook
- 📊 CSV logging with daily/weekly trend reports
- 🔄 Continuous monitoring or one-shot checks
- 🐳 Works in containers via sysfs fallback
- 📋 JSON output for integration with other tools
- 🛡️ Smart cooldown to prevent alert spam

Perfect for sysadmins, homelabbers, and anyone running servers or headless machines who needs to know when things get hot — before they get damaged.

## Quick Start Preview

```bash
# Install lm-sensors and detect hardware
bash scripts/install.sh

# Check current temperatures
bash scripts/run.sh --once

# Continuous monitoring with Telegram alerts
bash scripts/run.sh --interval 60 --alert telegram --warn 85 --crit 95
```

## Core Capabilities

1. Hardware sensor detection — Auto-detects CPU, GPU, NVMe, and motherboard sensors
2. Real-time monitoring — Check temperatures at configurable intervals (1s to 24h)
3. Multi-channel alerts — Telegram, email, webhook, or all simultaneously
4. CSV data logging — Track temperatures over time for trend analysis
5. Daily/weekly reports — Min, avg, max per sensor with trend indicators
6. NVIDIA GPU support — Reads GPU temps via nvidia-smi when available
7. Sysfs fallback — Works in containers or when lm-sensors unavailable
8. JSON output — Pipe data to dashboards or monitoring systems
9. Alert cooldown — Prevents notification spam on sustained high temps
10. Sensor filtering — Monitor specific chips or exclude noisy sensors
11. Cron-ready — Run as scheduled job for periodic checks
12. Cross-distro — Debian, Ubuntu, RHEL, CentOS, Arch Linux

## Dependencies
- `bash` (4.0+)
- `lm-sensors` (auto-installed)
- `curl` (for alerts)
- `awk` (for data processing)
- Optional: `nvidia-smi` (NVIDIA GPU)

## Installation Time
**5 minutes** — One script installs everything
