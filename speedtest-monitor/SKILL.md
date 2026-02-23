---
name: speedtest-monitor
description: >-
  Monitor internet speed over time — track download, upload, and latency with alerts on degradation.
categories: [automation, analytics]
dependencies: [speedtest-cli, bash, jq, bc]
---

# Speedtest Monitor

## What This Does

Runs periodic internet speed tests using `speedtest-cli`, logs results to CSV/JSON, tracks trends over time, and alerts you via Telegram or webhook when speeds drop below your thresholds. Perfect for catching ISP throttling, network issues, or verifying you're getting what you pay for.

**Example:** "Test every hour, alert me if download drops below 50 Mbps or latency exceeds 50ms."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install speedtest-cli
pip3 install speedtest-cli 2>/dev/null || pip install speedtest-cli

# Verify
speedtest-cli --version

# Other deps (usually pre-installed)
which jq bc || sudo apt-get install -y jq bc
```

### 2. Run First Test

```bash
bash scripts/run.sh --once

# Output:
# [2026-02-23 09:00:00] ✅ Download: 95.2 Mbps | Upload: 22.4 Mbps | Ping: 12.3 ms | Server: Example ISP (City)
```

### 3. Run Continuous Monitoring

```bash
# Test every 30 minutes, alert if download < 50 Mbps
bash scripts/run.sh --interval 1800 --min-download 50

# With Telegram alerts
export TELEGRAM_BOT_TOKEN="<your-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"
bash scripts/run.sh --interval 1800 --min-download 50 --alert telegram
```

## Core Workflows

### Workflow 1: One-Shot Speed Test

```bash
bash scripts/run.sh --once
# [2026-02-23 09:00:00] ✅ Download: 95.2 Mbps | Upload: 22.4 Mbps | Ping: 12.3 ms | Server: Example ISP
```

### Workflow 2: Continuous Monitoring with Alerts

```bash
bash scripts/run.sh \
  --interval 3600 \
  --min-download 50 \
  --min-upload 10 \
  --max-ping 50 \
  --alert telegram \
  --log ~/speedtest-history.csv
```

**On degradation:**
```
[2026-02-23 15:00:00] ❌ Download: 12.8 Mbps | Upload: 3.1 Mbps | Ping: 89.2 ms | Server: Example ISP
🚨 SPEED ALERT: Download 12.8 Mbps (threshold: 50 Mbps) | Ping 89.2 ms (threshold: 50 ms)
```

### Workflow 3: Generate Speed Report

```bash
bash scripts/run.sh --report --log ~/speedtest-history.csv

# Output:
# === Internet Speed Report (Last 7 Days) ===
# Tests run: 168
# Avg Download: 87.4 Mbps (min: 12.8, max: 102.1)
# Avg Upload: 21.8 Mbps (min: 3.1, max: 24.9)
# Avg Ping: 15.2 ms (min: 8.1, max: 89.2)
# Degradation events: 3
# Worst period: 2026-02-23 14:00-16:00 (avg 15.2 Mbps download)
```

### Workflow 4: Specific Server Test

```bash
# List nearby servers
speedtest-cli --list | head -20

# Test against specific server
bash scripts/run.sh --once --server 12345
```

## Configuration

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Webhook alerts (Slack, Discord, etc.)
export SPEEDTEST_WEBHOOK_URL="https://hooks.slack.com/..."
```

### Command Line Options

| Flag | Default | Description |
|------|---------|-------------|
| `--once` | - | Run single test and exit |
| `--interval N` | 3600 | Seconds between tests |
| `--min-download N` | 0 | Alert if download below N Mbps |
| `--min-upload N` | 0 | Alert if upload below N Mbps |
| `--max-ping N` | 0 | Alert if ping above N ms |
| `--alert TYPE` | none | Alert via: telegram, webhook, log |
| `--log FILE` | ./speedtest.csv | CSV log file path |
| `--report` | - | Generate report from log |
| `--server ID` | auto | Speedtest server ID |
| `--json` | - | Output in JSON format |

## Advanced Usage

### Run as Cron Job

```bash
# Test every hour, log results
0 * * * * cd /path/to/skill && bash scripts/run.sh --once --log ~/speedtest.csv --min-download 50 --alert telegram 2>&1 >> ~/speedtest-cron.log
```

### JSON Output for Pipelines

```bash
bash scripts/run.sh --once --json
# {"timestamp":"2026-02-23T09:00:00Z","download_mbps":95.2,"upload_mbps":22.4,"ping_ms":12.3,"server":"Example ISP","status":"ok"}
```

### Compare ISP Performance Over Time

```bash
# Run for a week, then analyze
bash scripts/run.sh --report --log ~/speedtest.csv

# Export for spreadsheet
cat ~/speedtest.csv
# timestamp,download_mbps,upload_mbps,ping_ms,server,status
# 2026-02-23T09:00:00Z,95.2,22.4,12.3,Example ISP,ok
# ...
```

## Troubleshooting

### Issue: "speedtest-cli: command not found"

```bash
pip3 install speedtest-cli
# or
sudo apt-get install speedtest-cli
```

### Issue: Tests take too long

Speedtest-cli selects the nearest server automatically. If slow:
```bash
# Pick a specific nearby server
speedtest-cli --list | head -10
bash scripts/run.sh --once --server <id>
```

### Issue: Telegram alerts not working

```bash
# Test manually
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Test"
```

### Issue: Permission denied on log file

```bash
touch ~/speedtest.csv && chmod 644 ~/speedtest.csv
```

## Key Principles

1. **Lightweight** — Uses speedtest-cli, no heavy framework
2. **CSV logging** — Easy to import into spreadsheets or analyze
3. **Alert once** — Doesn't spam on consecutive failures (cooldown period)
4. **Cron-ready** — Works standalone or as scheduled job

## Dependencies

- `speedtest-cli` (pip package — runs actual Ookla speed tests)
- `bash` (4.0+)
- `jq` (JSON parsing)
- `bc` (floating point math)
- `curl` (for alerts)
