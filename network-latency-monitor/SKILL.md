---
name: network-latency-monitor
description: >-
  Monitor network latency to multiple hosts with trend tracking, threshold alerts, and detailed reports.
categories: [automation, analytics]
dependencies: [bash, ping, awk, bc]
---

# Network Latency Monitor

## What This Does

Continuously monitors ICMP latency to multiple hosts, tracks trends over time, detects degradation, and alerts you when latency exceeds thresholds. All data stored locally in CSV — no external services needed.

**Example:** "Ping 5 hosts every 60 seconds. Alert via Telegram if latency to any host exceeds 200ms or packet loss exceeds 5%."

## Quick Start (3 minutes)

### 1. Install

```bash
# Copy scripts to a permanent location
INSTALL_DIR="${HOME}/.local/share/network-latency-monitor"
mkdir -p "$INSTALL_DIR"
cp -r scripts/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/*.sh

# Create data directory
mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/logs"
```

### 2. Monitor a Single Host

```bash
bash scripts/monitor.sh --host 8.8.8.8 --interval 30

# Output:
# [2026-03-03 14:00:00] 8.8.8.8 | avg=12.3ms | min=10.1ms | max=15.8ms | loss=0% | ✅ OK
# [2026-03-03 14:00:30] 8.8.8.8 | avg=11.9ms | min=9.8ms | max=14.2ms | loss=0% | ✅ OK
```

### 3. Monitor Multiple Hosts with Config

```bash
# Create config
cat > config.yaml << 'EOF'
hosts:
  - name: Google DNS
    address: 8.8.8.8
    threshold_ms: 100
  - name: Cloudflare DNS
    address: 1.1.1.1
    threshold_ms: 50
  - name: My Server
    address: your-server.com
    threshold_ms: 200

interval: 60
ping_count: 5
loss_threshold_pct: 5
data_dir: ./data
EOF

bash scripts/monitor.sh --config config.yaml
```

## Core Workflows

### Workflow 1: Continuous Monitoring with Alerts

```bash
bash scripts/monitor.sh \
  --host 8.8.8.8 \
  --host 1.1.1.1 \
  --host your-server.com \
  --interval 60 \
  --threshold 100 \
  --loss-threshold 5 \
  --alert-cmd 'echo "ALERT: $HOST latency ${AVG_MS}ms (threshold: ${THRESHOLD}ms)" | your-alert-command'
```

### Workflow 2: Generate Latency Report

```bash
# After collecting data, generate a report
bash scripts/report.sh --data-dir ./data --period 24h

# Output:
# ═══════════════════════════════════════════════════
#  Network Latency Report — Last 24 Hours
# ═══════════════════════════════════════════════════
#
#  Host: 8.8.8.8 (Google DNS)
#  ├── Avg Latency:  12.4ms
#  ├── Min/Max:      9.1ms / 45.2ms
#  ├── P95 Latency:  22.1ms
#  ├── Packet Loss:  0.1%
#  ├── Checks:       1440
#  └── Status:       ✅ Healthy
#
#  Host: your-server.com
#  ├── Avg Latency:  145.2ms
#  ├── Min/Max:      98.3ms / 520.1ms
#  ├── P95 Latency:  310.5ms
#  ├── Packet Loss:  2.3%
#  ├── Checks:       1440
#  └── Status:       ⚠️ Degraded (3 threshold breaches)
```

### Workflow 3: Detect Degradation Trends

```bash
bash scripts/report.sh --data-dir ./data --period 7d --trends

# Shows hour-by-hour latency trends and detects:
# - Gradual latency increases (creeping degradation)
# - Time-of-day patterns (peak hour congestion)
# - Packet loss correlation with latency spikes
```

### Workflow 4: Run as Cron Job

```bash
# Monitor every 5 minutes (add to crontab)
*/5 * * * * cd /path/to/monitor && bash scripts/monitor.sh --config config.yaml --once >> logs/cron.log 2>&1

# Daily report at 8am
0 8 * * * cd /path/to/monitor && bash scripts/report.sh --data-dir ./data --period 24h > /tmp/latency-report.txt
```

### Workflow 5: Compare Multiple Hosts

```bash
bash scripts/report.sh --data-dir ./data --period 1h --compare

# ═══════════════════════════════════════
#  Host Comparison — Last 1 Hour
# ═══════════════════════════════════════
#  Host              Avg     P95     Loss
#  ─────────────────────────────────────
#  8.8.8.8          12ms    22ms    0.0%
#  1.1.1.1           8ms    15ms    0.0%
#  your-server.com  142ms   305ms   1.2%
```

## Configuration

### Config File (YAML-like)

```yaml
# config.yaml
hosts:
  - name: Google DNS
    address: 8.8.8.8
    threshold_ms: 100
  - name: Cloudflare DNS
    address: 1.1.1.1
    threshold_ms: 50
  - name: Production Server
    address: prod.example.com
    threshold_ms: 200
  - name: Database Server
    address: 10.0.1.50
    threshold_ms: 20

# How often to ping (seconds)
interval: 60

# Number of pings per check
ping_count: 5

# Alert if packet loss exceeds this percentage
loss_threshold_pct: 5

# Where to store CSV data
data_dir: ./data

# Alert command (variables: $HOST, $NAME, $AVG_MS, $MAX_MS, $LOSS_PCT, $THRESHOLD)
alert_cmd: ""

# Retention: auto-delete data older than N days (0 = keep forever)
retention_days: 30
```

### Environment Variables

```bash
# Override config values
export NLM_INTERVAL=30
export NLM_THRESHOLD=100
export NLM_LOSS_THRESHOLD=5
export NLM_DATA_DIR="./data"

# Telegram alerts
export NLM_TELEGRAM_BOT_TOKEN="<token>"
export NLM_TELEGRAM_CHAT_ID="<chat-id>"
```

## Data Format

Data is stored as CSV files (one per host per day):

```
data/8.8.8.8/2026-03-03.csv
data/1.1.1.1/2026-03-03.csv
data/your-server.com/2026-03-03.csv
```

CSV format:
```csv
timestamp,host,avg_ms,min_ms,max_ms,loss_pct,ping_count
2026-03-03T14:00:00Z,8.8.8.8,12.3,10.1,15.8,0.0,5
2026-03-03T14:01:00Z,8.8.8.8,11.9,9.8,14.2,0.0,5
```

## Advanced Usage

### Custom Alert Integration

```bash
# Slack webhook
bash scripts/monitor.sh --config config.yaml \
  --alert-cmd 'curl -s -X POST "$SLACK_WEBHOOK" -d "{\"text\":\"🚨 $NAME ($HOST): ${AVG_MS}ms latency, ${LOSS_PCT}% loss\"}"'

# Telegram
bash scripts/monitor.sh --config config.yaml \
  --alert-cmd 'curl -s "https://api.telegram.org/bot${NLM_TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${NLM_TELEGRAM_CHAT_ID}&text=🚨 $NAME ($HOST): ${AVG_MS}ms latency"'
```

### Data Cleanup

```bash
# Remove data older than 30 days
bash scripts/cleanup.sh --data-dir ./data --older-than 30
```

### Export to JSON

```bash
bash scripts/report.sh --data-dir ./data --period 24h --format json > report.json
```

## Troubleshooting

### Issue: "ping: permission denied"

Some systems restrict raw ICMP. Fix:
```bash
# Option 1: Use setcap
sudo setcap cap_net_raw+ep $(which ping)

# Option 2: Run with sudo
sudo bash scripts/monitor.sh --host 8.8.8.8
```

### Issue: "bc: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install bc

# Alpine
apk add bc
```

### Issue: High latency readings on WiFi

WiFi inherently adds jitter. For accurate measurements:
- Use wired connection when possible
- Increase `ping_count` to 10+ for better averaging
- Set higher thresholds for WiFi-connected hosts

## Dependencies

- `bash` (4.0+)
- `ping` (iputils-ping or busybox)
- `awk` (any version)
- `bc` (for floating-point math)
- `date` (GNU coreutils)
- Optional: `curl` (for webhook alerts)
