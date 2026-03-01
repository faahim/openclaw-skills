---
name: loki-log-aggregator
description: >-
  Install and manage Grafana Loki + Promtail for centralized log aggregation, querying, and alerting.
categories: [analytics, automation]
dependencies: [bash, curl, unzip, systemctl]
---

# Loki Log Aggregator

## What This Does

Installs and configures Grafana Loki (log database) and Promtail (log shipper) for centralized log aggregation on your server. Collect logs from systemd journals, application log files, Docker containers, and more — then query them with LogQL.

**Example:** "Ship all nginx, systemd, and app logs to Loki. Query last hour's errors with `{job="nginx"} |= "error"`."

## Quick Start (10 minutes)

### 1. Install Loki + Promtail

```bash
# Install both Loki and Promtail (auto-detects architecture)
bash scripts/install.sh

# Verify installation
loki --version
promtail --version
```

### 2. Start Services

```bash
# Start Loki (listens on :3100)
bash scripts/manage.sh start loki

# Start Promtail (ships logs to Loki)
bash scripts/manage.sh start promtail

# Check status
bash scripts/manage.sh status
```

### 3. Query Logs

```bash
# Query recent logs
bash scripts/query.sh '{job="systemd"}' --limit 50

# Search for errors in last hour
bash scripts/query.sh '{job="systemd"} |= "error"' --since 1h

# Tail logs in real-time
bash scripts/query.sh '{job="systemd"}' --tail
```

## Core Workflows

### Workflow 1: System Log Aggregation

**Use case:** Collect all systemd journal logs

The default Promtail config already ships systemd journal entries. After install:

```bash
# Query systemd logs
bash scripts/query.sh '{job="systemd"}'

# Filter by unit
bash scripts/query.sh '{job="systemd", unit="nginx.service"}'

# Search for failures
bash scripts/query.sh '{job="systemd"} |= "Failed"' --since 24h
```

### Workflow 2: Application Log Files

**Use case:** Ship custom application logs to Loki

```bash
# Add a log file source
bash scripts/add-source.sh \
  --job myapp \
  --path "/var/log/myapp/*.log" \
  --labels 'env="production"'

# Restart Promtail to pick up changes
bash scripts/manage.sh restart promtail

# Query app logs
bash scripts/query.sh '{job="myapp", env="production"}'
```

### Workflow 3: Docker Container Logs

**Use case:** Aggregate Docker container logs

```bash
# Add Docker log source (reads from /var/lib/docker/containers)
bash scripts/add-source.sh \
  --job docker \
  --path "/var/lib/docker/containers/**/*-json.log" \
  --docker

# Query Docker logs
bash scripts/query.sh '{job="docker"}'
```

### Workflow 4: Log Analysis & Metrics

**Use case:** Extract metrics from logs using LogQL

```bash
# Count errors per hour
bash scripts/query.sh 'rate({job="systemd"} |= "error" [1h])'

# Top 10 log-producing services
bash scripts/query.sh 'topk(10, sum by (unit) (rate({job="systemd"}[5m])))'

# Response time percentiles (from structured logs)
bash scripts/query.sh 'quantile_over_time(0.99, {job="nginx"} | json | unwrap response_time [1h])'
```

### Workflow 5: Alerting on Log Patterns

**Use case:** Get notified when error rate spikes

```bash
# Add alert rule: fire when >10 errors/min
bash scripts/add-alert.sh \
  --name "high-error-rate" \
  --query '{job="systemd"} |= "error"' \
  --threshold 10 \
  --window 1m \
  --webhook "https://hooks.slack.com/your-webhook"

# List active alerts
bash scripts/manage.sh alerts
```

## Configuration

### Loki Config (`/etc/loki/config.yaml`)

```yaml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory
  replication_factor: 1
  path_prefix: /var/lib/loki

schema_config:
  configs:
    - from: "2024-01-01"
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  filesystem:
    directory: /var/lib/loki/chunks

limits_config:
  retention_period: 720h  # 30 days
  max_query_length: 721h

compactor:
  working_directory: /var/lib/loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  delete_request_cancel_period: 10m
  retention_delete_delay: 2h
```

### Promtail Config (`/etc/promtail/config.yaml`)

```yaml
server:
  http_listen_port: 9080

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: systemd
    journal:
      max_age: 12h
      labels:
        job: systemd
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: unit
```

### Environment Variables

```bash
# Loki listen address (default: 0.0.0.0:3100)
export LOKI_LISTEN_ADDR="0.0.0.0:3100"

# Retention period (default: 720h / 30 days)
export LOKI_RETENTION="720h"

# Data directory
export LOKI_DATA_DIR="/var/lib/loki"

# Promtail port
export PROMTAIL_PORT="9080"
```

## Advanced Usage

### Multi-Server Setup

On additional servers, install only Promtail and point to central Loki:

```bash
# Install Promtail only on remote server
bash scripts/install.sh --promtail-only --loki-url http://loki-server:3100
```

### Log Retention Management

```bash
# Change retention to 7 days
bash scripts/manage.sh set-retention 168h

# Check current storage usage
bash scripts/manage.sh storage-info

# Force compaction
bash scripts/manage.sh compact
```

### Backup & Restore

```bash
# Backup Loki data
bash scripts/manage.sh backup /path/to/backup/

# Restore from backup
bash scripts/manage.sh restore /path/to/backup/
```

### Integration with Grafana

```bash
# Add Loki as Grafana datasource
bash scripts/grafana-setup.sh --grafana-url http://localhost:3000

# This configures Loki as a datasource in Grafana for visual log exploration
```

## Troubleshooting

### Issue: Loki won't start — "port 3100 already in use"

**Fix:**
```bash
# Find what's using the port
sudo lsof -i :3100
# Kill it or change LOKI_LISTEN_ADDR
export LOKI_LISTEN_ADDR="0.0.0.0:3101"
bash scripts/manage.sh restart loki
```

### Issue: Promtail can't read journal

**Fix:**
```bash
# Add promtail user to systemd-journal group
sudo usermod -aG systemd-journal promtail
bash scripts/manage.sh restart promtail
```

### Issue: High memory usage

**Fix:** Reduce ingestion rate or add limits to Loki config:
```yaml
limits_config:
  ingestion_rate_mb: 4
  ingestion_burst_size_mb: 6
  per_stream_rate_limit: 3MB
```

### Issue: No logs showing up

**Check:**
1. Promtail is running: `bash scripts/manage.sh status`
2. Promtail can reach Loki: `curl -s http://localhost:3100/ready`
3. Log paths are correct: `cat /etc/promtail/config.yaml`
4. Positions file is writable: `ls -la /var/lib/promtail/positions.yaml`

## Key Principles

1. **Lightweight** — Loki indexes labels only, not full text (much less storage than ELK)
2. **LogQL** — Powerful query language similar to PromQL
3. **Retention** — Auto-delete old logs after configurable period
4. **Multi-tenant** — Optional tenant isolation for shared deployments
5. **Prometheus-compatible** — Same label model, works with Grafana natively

## Dependencies

- `bash` (4.0+)
- `curl` (downloading binaries)
- `unzip` (extracting releases)
- `systemctl` (managing services)
- Optional: `grafana` (visual log exploration)
- Optional: `jq` (JSON output formatting)
