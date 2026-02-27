---
name: thermal-monitor
description: >-
  Monitor CPU and GPU temperatures, log thermal history, and alert on overheating.
categories: [automation, security]
dependencies: [lm-sensors, bash, awk]
---

# Thermal Monitor

## What This Does

Monitors CPU, GPU, and other hardware temperatures in real-time using lm-sensors. Logs thermal data over time, detects overheating, and sends alerts via Telegram, email, or webhook when temperatures exceed thresholds. Prevents thermal throttling and hardware damage.

**Example:** "Check temps every 60 seconds, alert via Telegram if CPU exceeds 85°C, log hourly averages for trend analysis."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

This installs `lm-sensors`, detects your hardware sensors, and creates a default config.

### 2. Check Current Temperatures

```bash
bash scripts/run.sh --once
```

**Output:**
```
[2026-02-27 07:00:00] 🌡️ Thermal Report
  CPU Package:  52°C  (warn: 85°C, crit: 95°C) ✅
  CPU Core 0:   50°C  ✅
  CPU Core 1:   53°C  ✅
  GPU:          45°C  (warn: 80°C, crit: 100°C) ✅
  NVMe SSD:     38°C  (warn: 70°C, crit: 75°C) ✅
```

### 3. Start Continuous Monitoring

```bash
bash scripts/run.sh --interval 60 --log /var/log/thermal-monitor.log
```

### 4. Enable Alerts

```bash
# Set up Telegram alerts
export THERMAL_TELEGRAM_BOT_TOKEN="<your-token>"
export THERMAL_TELEGRAM_CHAT_ID="<your-chat-id>"

bash scripts/run.sh --interval 60 --alert telegram --warn 85 --crit 95
```

## Core Workflows

### Workflow 1: One-Shot Temperature Check

**Use case:** Quick check of current system temperatures

```bash
bash scripts/run.sh --once
```

### Workflow 2: Continuous Monitoring with Alerts

**Use case:** Run as a background service, get notified on overheating

```bash
bash scripts/run.sh \
  --interval 60 \
  --alert telegram \
  --warn 85 \
  --crit 95 \
  --log /var/log/thermal-monitor.log
```

**On warning (>85°C):**
```
⚠️ THERMAL WARNING: CPU Package at 87°C (threshold: 85°C) on hostname
```

**On critical (>95°C):**
```
🔥 THERMAL CRITICAL: CPU Package at 96°C (threshold: 95°C) on hostname — RISK OF THROTTLING/DAMAGE
```

### Workflow 3: Temperature History & Trends

**Use case:** Analyze thermal data over time

```bash
# View last 24h average, min, max per sensor
bash scripts/run.sh --report daily --log /var/log/thermal-monitor.log

# Output:
# 📊 24h Thermal Summary (2026-02-27)
# ┌─────────────┬─────┬─────┬─────┬───────┐
# │ Sensor      │ Min │ Avg │ Max │ Trend │
# ├─────────────┼─────┼─────┼─────┼───────┤
# │ CPU Package │ 42  │ 58  │ 82  │ ↗     │
# │ GPU         │ 38  │ 45  │ 71  │ →     │
# │ NVMe SSD    │ 35  │ 39  │ 42  │ →     │
# └─────────────┴─────┴─────┴─────┴───────┘
```

### Workflow 4: Stress Test Monitoring

**Use case:** Monitor temps during workload/benchmarks

```bash
# Monitor at high frequency during stress test
bash scripts/run.sh --interval 5 --warn 90 --crit 100 --alert telegram --log stress-test.log
```

### Workflow 5: Run as Cron Job

```bash
# Log temps every 5 minutes
*/5 * * * * cd /path/to/thermal-monitor && bash scripts/run.sh --once --log /var/log/thermal-monitor.log --alert telegram --warn 85 --crit 95 2>&1
```

## Configuration

### Environment Variables

```bash
# Telegram alerts
export THERMAL_TELEGRAM_BOT_TOKEN="<token>"
export THERMAL_TELEGRAM_CHAT_ID="<chat-id>"

# Email alerts (SMTP)
export THERMAL_SMTP_HOST="smtp.gmail.com"
export THERMAL_SMTP_PORT="587"
export THERMAL_SMTP_USER="<email>"
export THERMAL_SMTP_PASS="<password>"
export THERMAL_SMTP_TO="<recipient>"

# Webhook alerts
export THERMAL_WEBHOOK_URL="https://hooks.slack.com/..."
```

### Command-Line Options

```
--once            Single check, then exit
--interval N      Check every N seconds (default: 60)
--warn N          Warning threshold in °C (default: 85)
--crit N          Critical threshold in °C (default: 95)
--alert TYPE      Alert method: telegram, email, webhook, all
--log FILE        Log temperatures to file (CSV format)
--report TYPE     Generate report: daily, weekly (requires --log)
--json            Output in JSON format
--quiet           Only output warnings/criticals
--cooldown N      Minimum seconds between repeat alerts (default: 300)
```

## Advanced Usage

### Custom Sensor Selection

```bash
# Monitor only specific sensors
bash scripts/run.sh --sensors "coretemp-*,nvme-*" --interval 30

# Exclude certain sensors
bash scripts/run.sh --exclude "acpitz-*" --interval 60
```

### JSON Output for Integration

```bash
bash scripts/run.sh --once --json
```

```json
{
  "timestamp": "2026-02-27T07:00:00Z",
  "hostname": "myserver",
  "sensors": [
    {"name": "CPU Package", "chip": "coretemp-isa-0000", "temp": 52, "warn": 85, "crit": 95, "status": "ok"},
    {"name": "GPU", "chip": "amdgpu-pci-0600", "temp": 45, "warn": 80, "crit": 100, "status": "ok"}
  ]
}
```

### Thermal Zone Fallback

If `lm-sensors` is unavailable (e.g., containers), the script falls back to reading `/sys/class/thermal/thermal_zone*/temp` directly:

```bash
bash scripts/run.sh --once --fallback-sysfs
```

## Troubleshooting

### Issue: "No sensors detected"

**Fix:**
```bash
# Run sensor detection
sudo sensors-detect --auto
# Load detected kernel modules
sudo modprobe coretemp  # Intel
sudo modprobe k10temp   # AMD
```

### Issue: "lm-sensors not installed"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
sudo apt-get install -y lm-sensors  # Debian/Ubuntu
sudo yum install -y lm_sensors      # RHEL/CentOS
```

### Issue: Telegram alerts not arriving

**Check:**
1. Token: `echo $THERMAL_TELEGRAM_BOT_TOKEN`
2. Chat ID: `curl -s "https://api.telegram.org/bot$THERMAL_TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$THERMAL_TELEGRAM_CHAT_ID&text=Test"`

### Issue: GPU temperature not showing

**Fix:** Install GPU-specific drivers:
```bash
# NVIDIA
sudo apt-get install nvidia-smi
# AMD
# amdgpu driver usually auto-detected by lm-sensors
```

## Dependencies

- `bash` (4.0+)
- `lm-sensors` (installed via `scripts/install.sh`)
- `awk` (for data processing)
- `curl` (for alerts)
- Optional: `nvidia-smi` (NVIDIA GPU temps)
