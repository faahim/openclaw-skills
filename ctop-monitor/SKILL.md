---
name: ctop-monitor
description: >-
  Real-time Docker container metrics monitoring with ctop. View CPU, memory, network, and disk I/O per container in a top-like terminal UI.
categories: [dev-tools, automation]
dependencies: [docker, ctop]
---

# Ctop Container Monitor

## What This Does

Monitor all running Docker containers in real-time with a terminal UI — like `htop` but for containers. See CPU usage, memory consumption, network I/O, and block I/O at a glance. Includes scripts for automated alerts when containers exceed resource thresholds.

**Example:** "View all 12 containers sorted by CPU usage, get a Telegram alert when any container exceeds 90% memory."

## Quick Start (3 minutes)

### 1. Install ctop

```bash
bash scripts/install.sh
```

### 2. Launch Interactive Monitor

```bash
# Real-time container dashboard
ctop
```

**Keyboard shortcuts:**
- `s` — Change sort column (CPU / Mem / Net / IO)
- `f` — Filter containers by name
- `h` — Toggle header
- `Enter` — Expand container details (logs, env, config)
- `l` — View container logs
- `S` — Save current view to CSV
- `q` — Quit

### 3. Set Up Automated Alerts

```bash
# Monitor and alert when any container exceeds thresholds
bash scripts/monitor.sh --cpu-warn 80 --mem-warn 85 --interval 60
```

## Core Workflows

### Workflow 1: Interactive Dashboard

**Use case:** Quick visual check on all containers

```bash
# Launch with specific sort
ctop -s cpu

# Filter to specific containers
ctop -f "web\|api\|db"

# Connect to remote Docker host
DOCKER_HOST=tcp://remote:2375 ctop
```

### Workflow 2: One-Shot Status Report

**Use case:** Get a snapshot of container health without interactive mode

```bash
bash scripts/report.sh
```

**Output:**
```
=== Container Resource Report (2026-03-02 23:55:00 UTC) ===

CONTAINER          CPU%    MEM USAGE / LIMIT    MEM%    NET I/O           BLOCK I/O
nginx-proxy        2.3%    45.2MB / 512MB       8.8%    1.2GB / 890MB     12MB / 0B
postgres-db        15.7%   384MB / 1GB          37.5%   450MB / 1.1GB     2.3GB / 156MB
redis-cache        0.8%    28MB / 256MB         10.9%   89MB / 67MB       0B / 0B
app-server         42.1%   712MB / 2GB          34.7%   2.1GB / 3.4GB     890MB / 45MB

⚠️  app-server: CPU at 42.1% (trending up)
✅  All containers within memory limits
```

### Workflow 3: Continuous Monitoring with Alerts

**Use case:** Run as a background service, alert on threshold breaches

```bash
# Alert via Telegram when thresholds exceeded
export TELEGRAM_BOT_TOKEN="your-token"
export TELEGRAM_CHAT_ID="your-chat-id"

bash scripts/monitor.sh \
  --cpu-warn 80 \
  --cpu-crit 95 \
  --mem-warn 85 \
  --mem-crit 95 \
  --interval 30 \
  --alert telegram
```

**On threshold breach:**
```
🚨 CRITICAL: app-server CPU at 97.2% (threshold: 95%)
⚠️ WARNING: postgres-db memory at 87.3% (threshold: 85%)
```

### Workflow 4: Historical Resource Logging

**Use case:** Track resource usage over time for capacity planning

```bash
# Log container stats every 5 minutes to CSV
bash scripts/logger.sh --interval 300 --output logs/container-stats.csv

# Generate daily summary
bash scripts/summary.sh --date 2026-03-02 --input logs/container-stats.csv
```

**CSV output:**
```csv
timestamp,container,cpu_pct,mem_usage_mb,mem_limit_mb,mem_pct,net_rx_mb,net_tx_mb
2026-03-02T12:00:00,nginx-proxy,2.3,45.2,512,8.8,1200,890
2026-03-02T12:00:00,postgres-db,15.7,384,1024,37.5,450,1100
```

### Workflow 5: Container Restart on High Resource Usage

**Use case:** Auto-restart containers that exceed limits

```bash
bash scripts/monitor.sh \
  --cpu-crit 95 \
  --mem-crit 95 \
  --action restart \
  --cooldown 300 \
  --alert telegram
```

**Action log:**
```
[2026-03-02 14:30:00] ❌ app-server: CPU at 97% — restarting container
[2026-03-02 14:30:05] ✅ app-server: restarted successfully
[2026-03-02 14:30:05] 📨 Telegram alert sent
```

## Configuration

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<bot-token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Remote Docker host (optional)
export DOCKER_HOST="tcp://remote-host:2375"

# Custom thresholds
export CTOP_CPU_WARN=80
export CTOP_CPU_CRIT=95
export CTOP_MEM_WARN=85
export CTOP_MEM_CRIT=95
```

### Config File

```bash
# Copy template
cp scripts/config-template.yaml config.yaml
```

```yaml
# config.yaml
thresholds:
  cpu_warn: 80
  cpu_crit: 95
  mem_warn: 85
  mem_crit: 95

alerts:
  telegram:
    bot_token: "${TELEGRAM_BOT_TOKEN}"
    chat_id: "${TELEGRAM_CHAT_ID}"
  webhook:
    url: "https://hooks.slack.com/services/..."

logging:
  enabled: true
  interval: 300  # seconds
  output: logs/container-stats.csv
  retention_days: 30

actions:
  restart_on_crit: false
  cooldown: 300  # seconds between restarts
  exclude:
    - "postgres-db"  # never auto-restart database
```

## Advanced Usage

### Run as Cron Job

```bash
# Check every 5 minutes, alert on issues
*/5 * * * * cd /path/to/skill && bash scripts/monitor.sh --config config.yaml --once >> logs/monitor.log 2>&1
```

### Docker Compose Integration

```bash
# Monitor only containers from a specific compose project
bash scripts/monitor.sh --filter "com.docker.compose.project=myapp"
```

### Multiple Docker Hosts

```bash
# Monitor containers across multiple hosts
bash scripts/multi-host.sh \
  --host "prod:tcp://prod-server:2375" \
  --host "staging:tcp://staging-server:2375" \
  --alert telegram
```

### Export Metrics for Grafana

```bash
# Output Prometheus-compatible metrics
bash scripts/metrics.sh --format prometheus --port 9090
```

## Troubleshooting

### Issue: "Cannot connect to Docker daemon"

**Fix:**
```bash
# Check Docker is running
sudo systemctl status docker

# Add user to docker group (avoids sudo)
sudo usermod -aG docker $USER
newgrp docker
```

### Issue: "ctop: command not found"

**Fix:**
```bash
# Re-run installer
bash scripts/install.sh

# Or install manually
sudo wget https://github.com/bcicen/ctop/releases/latest/download/ctop-linux-amd64 -O /usr/local/bin/ctop
sudo chmod +x /usr/local/bin/ctop
```

### Issue: Telegram alerts not sending

**Check:**
```bash
# Test bot token
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe" | jq .ok

# Test sending
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=Test"
```

### Issue: High CPU from monitoring script itself

**Fix:** Increase monitoring interval
```bash
bash scripts/monitor.sh --interval 120  # Check every 2 min instead of 30s
```

## Dependencies

- `docker` (Docker Engine running)
- `ctop` (installed by scripts/install.sh)
- `curl` (for alerts)
- `jq` (for JSON parsing)
- `awk` (for stats parsing)
- Optional: `cron` (for scheduled monitoring)
