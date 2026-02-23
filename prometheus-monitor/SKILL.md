---
name: prometheus-monitor
description: >-
  Install and configure Prometheus + Node Exporter for system and service monitoring with alerting.
categories: [automation, analytics]
dependencies: [bash, curl, tar, systemd]
---

# Prometheus Monitor

## What This Does

Sets up a complete Prometheus monitoring stack on any Linux server. Installs Prometheus and Node Exporter as systemd services, configures scrape targets, and sets up alerting rules with webhook/Telegram notifications. No Docker required — runs natively.

**Example:** "Monitor CPU, memory, disk, and network on 5 servers. Get a Telegram alert when disk usage exceeds 85%."

## Quick Start (10 minutes)

### 1. Install Prometheus + Node Exporter

```bash
# Run the installer (auto-detects arch: amd64/arm64)
sudo bash scripts/install.sh
```

This will:
- Download latest Prometheus + Node Exporter binaries
- Create `prometheus` system user
- Set up systemd services
- Start both services
- Prometheus UI available at `http://localhost:9090`
- Node Exporter metrics at `http://localhost:9100/metrics`

### 2. Verify Installation

```bash
# Check services are running
systemctl status prometheus node_exporter

# Query a metric
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result'
```

### 3. Add Alert Rules

```bash
# Copy alert rules template
sudo cp scripts/alert-rules.yml /etc/prometheus/rules/alerts.yml

# Edit thresholds as needed
sudo nano /etc/prometheus/rules/alerts.yml

# Reload Prometheus config
sudo systemctl reload prometheus
```

## Core Workflows

### Workflow 1: Monitor Local Server

Default setup — monitors the machine Prometheus runs on.

```bash
sudo bash scripts/install.sh
# Done. Prometheus scrapes Node Exporter every 15s automatically.
```

**Key metrics available:**
- `node_cpu_seconds_total` — CPU usage per core
- `node_memory_MemAvailable_bytes` — Available RAM
- `node_filesystem_avail_bytes` — Disk space
- `node_network_receive_bytes_total` — Network traffic
- `node_load1` / `node_load5` / `node_load15` — Load averages

### Workflow 2: Monitor Remote Servers

Add remote Node Exporter targets to Prometheus config.

```bash
# Install Node Exporter on remote servers
# (run on each remote server)
sudo bash scripts/install-node-exporter.sh

# Then add targets on the Prometheus server
sudo bash scripts/add-target.sh 192.168.1.10:9100 "web-server-1"
sudo bash scripts/add-target.sh 192.168.1.11:9100 "db-server-1"

# Reload config
sudo systemctl reload prometheus
```

### Workflow 3: Set Up Telegram Alerts

```bash
# Configure Alertmanager with Telegram
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

sudo bash scripts/setup-alertmanager.sh

# Test alert
bash scripts/test-alert.sh
```

**Alert examples:**
- 🔴 **HighCPU**: CPU usage > 80% for 5 minutes
- 🔴 **HighMemory**: Memory usage > 90% for 5 minutes
- 🔴 **DiskAlmostFull**: Disk usage > 85%
- 🔴 **InstanceDown**: Target unreachable for 2 minutes
- 🟡 **HighLoad**: Load average > number of CPUs for 15 minutes

### Workflow 4: Query Metrics (PromQL)

```bash
# CPU usage percentage (last 5 min average)
curl -s 'http://localhost:9090/api/v1/query?query=100-(avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))*100)' | jq '.data.result[0].value[1]'

# Memory usage percentage
curl -s 'http://localhost:9090/api/v1/query?query=100*(1-node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes)' | jq '.data.result[0].value[1]'

# Disk usage percentage for root partition
curl -s 'http://localhost:9090/api/v1/query?query=100*(1-node_filesystem_avail_bytes{mountpoint="/"}/node_filesystem_size_bytes{mountpoint="/"})' | jq '.data.result[0].value[1]'

# Network bytes received in last hour
curl -s 'http://localhost:9090/api/v1/query?query=increase(node_network_receive_bytes_total{device="eth0"}[1h])' | jq '.data.result[0].value[1]'
```

### Workflow 5: Check Service Health

```bash
# Get status of all targets
bash scripts/status.sh

# Output:
# ✅ localhost:9090 (prometheus) — UP — scraped 2s ago
# ✅ localhost:9100 (node) — UP — scraped 5s ago
# ❌ 192.168.1.10:9100 (web-server-1) — DOWN — last seen 5m ago
```

## Configuration

### Prometheus Config (`/etc/prometheus/prometheus.yml`)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance_name: 'local'
```

### Alert Rules (`/etc/prometheus/rules/alerts.yml`)

```yaml
groups:
  - name: system-alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} down"

      - alert: HighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU on {{ $labels.instance }}: {{ $value | printf \"%.1f\" }}%"

      - alert: HighMemory
        expr: 100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory on {{ $labels.instance }}: {{ $value | printf \"%.1f\" }}%"

      - alert: DiskAlmostFull
        expr: 100 * (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk almost full on {{ $labels.instance }}: {{ $value | printf \"%.1f\" }}%"
```

## Environment Variables

```bash
# For Telegram alerting (optional)
export TELEGRAM_BOT_TOKEN="<bot-token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Custom data directory (default: /var/lib/prometheus)
export PROMETHEUS_DATA_DIR="/var/lib/prometheus"

# Retention period (default: 15d)
export PROMETHEUS_RETENTION="30d"
```

## Uninstall

```bash
sudo bash scripts/uninstall.sh
# Stops services, removes binaries, optionally removes data
```

## Troubleshooting

### Issue: "prometheus: command not found"

The binary is at `/usr/local/bin/prometheus`. Check PATH or run directly:
```bash
/usr/local/bin/prometheus --version
```

### Issue: Port 9090 already in use

```bash
# Check what's using it
sudo lsof -i :9090
# Change port in /etc/prometheus/prometheus.yml web.listen-address
```

### Issue: Node Exporter not showing all metrics

Some metrics need kernel features. Check:
```bash
curl -s http://localhost:9100/metrics | grep -c "^node_"
# Should show 500+ metrics on most Linux systems
```

### Issue: Alerts not firing

1. Check rules loaded: `curl http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | .name'`
2. Check Alertmanager running: `systemctl status alertmanager`
3. Test webhook: `bash scripts/test-alert.sh`

## Dependencies

- `bash` (4.0+)
- `curl` — downloading binaries, API queries
- `tar` — extracting archives
- `systemd` — service management (Linux only)
- `jq` — JSON parsing (optional, for status script)
- Root/sudo access for installation
