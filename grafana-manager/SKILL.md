---
name: grafana-manager
description: >-
  Install, configure, and manage Grafana dashboards and data sources from the command line.
categories: [analytics, dev-tools]
dependencies: [bash, curl, jq]
---

# Grafana Dashboard Manager

## What This Does

Install Grafana OSS, manage data sources (Prometheus, InfluxDB, PostgreSQL, MySQL, etc.), and create/import/export dashboards — all from your terminal. No clicking through web UIs. Perfect for automating observability setups across multiple servers.

**Example:** "Install Grafana, connect Prometheus, import the Node Exporter dashboard, and set up alerts — in 3 commands."

## Quick Start (5 minutes)

### 1. Install Grafana

```bash
bash scripts/install.sh
# Installs Grafana OSS, starts the service, prints the URL
# Default: http://localhost:3000 (admin/admin)
```

### 2. Add a Data Source

```bash
bash scripts/datasource.sh add \
  --name "prometheus" \
  --type prometheus \
  --url http://localhost:9090

# Output:
# ✅ Data source 'prometheus' added (id: 1)
```

### 3. Import a Dashboard

```bash
bash scripts/dashboard.sh import \
  --id 1860 \
  --datasource prometheus

# Output:
# ✅ Dashboard 'Node Exporter Full' imported (uid: rYdddlPWk)
# 🔗 http://localhost:3000/d/rYdddlPWk
```

## Core Workflows

### Workflow 1: Install Grafana

```bash
# Install on Ubuntu/Debian
bash scripts/install.sh --os debian

# Install on RHEL/CentOS/Fedora
bash scripts/install.sh --os rhel

# Install via Docker
bash scripts/install.sh --docker --port 3000 --data /opt/grafana-data
```

### Workflow 2: Manage Data Sources

```bash
# Add Prometheus
bash scripts/datasource.sh add --name prom --type prometheus --url http://localhost:9090

# Add PostgreSQL
bash scripts/datasource.sh add --name pgdb --type postgres \
  --url localhost:5432 --database mydb --user grafana --password secret

# Add InfluxDB
bash scripts/datasource.sh add --name influx --type influxdb \
  --url http://localhost:8086 --database telegraf

# List all data sources
bash scripts/datasource.sh list

# Delete a data source
bash scripts/datasource.sh delete --name prom
```

### Workflow 3: Manage Dashboards

```bash
# Import from Grafana.com by ID
bash scripts/dashboard.sh import --id 1860 --datasource prom

# Import from JSON file
bash scripts/dashboard.sh import --file my-dashboard.json

# Export a dashboard
bash scripts/dashboard.sh export --uid rYdddlPWk > backup.json

# List all dashboards
bash scripts/dashboard.sh list

# Delete a dashboard
bash scripts/dashboard.sh delete --uid rYdddlPWk

# Search dashboards
bash scripts/dashboard.sh search --query "node exporter"
```

### Workflow 4: Create Alert Rules

```bash
bash scripts/alert.sh create \
  --name "High CPU" \
  --datasource prom \
  --query 'avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) < 0.2' \
  --channel telegram \
  --message "CPU usage above 80%!"
```

### Workflow 5: Bulk Setup (New Server)

```bash
# Full observability stack in one command
bash scripts/install.sh
bash scripts/datasource.sh add --name prom --type prometheus --url http://localhost:9090
bash scripts/dashboard.sh import --id 1860 --datasource prom   # Node Exporter
bash scripts/dashboard.sh import --id 11074 --datasource prom  # Node Exporter for Prometheus
bash scripts/dashboard.sh import --id 3662 --datasource prom   # Prometheus 2.0 Stats
echo "✅ Observability stack ready at http://localhost:3000"
```

### Workflow 6: Backup & Restore

```bash
# Backup all dashboards
bash scripts/dashboard.sh backup --dir ./grafana-backups

# Restore from backup
bash scripts/dashboard.sh restore --dir ./grafana-backups
```

## Configuration

### Environment Variables

```bash
# Grafana connection (default: localhost:3000)
export GRAFANA_URL="http://localhost:3000"
export GRAFANA_API_KEY="your-api-key"

# Or use basic auth (default admin/admin)
export GRAFANA_USER="admin"
export GRAFANA_PASS="admin"

# Docker settings (for --docker install)
export GRAFANA_DOCKER_PORT=3000
export GRAFANA_DOCKER_DATA="/opt/grafana-data"
```

### API Key Setup

```bash
# Create an API key (recommended over user/pass)
bash scripts/apikey.sh create --name "openclaw" --role Admin
# Output: GRAFANA_API_KEY=eyJr...
# Add to ~/.bashrc or ~/.openclaw/env
```

## Popular Dashboard IDs

| ID | Name | Data Source | Use Case |
|----|------|-------------|----------|
| 1860 | Node Exporter Full | Prometheus | System metrics (CPU, RAM, disk, network) |
| 11074 | Node Exporter for Prometheus | Prometheus | Lightweight system overview |
| 3662 | Prometheus 2.0 Stats | Prometheus | Prometheus self-monitoring |
| 7362 | MySQL Overview | Prometheus + mysqld_exporter | MySQL monitoring |
| 9628 | PostgreSQL Database | Prometheus + postgres_exporter | PostgreSQL monitoring |
| 12485 | Docker Monitoring | Prometheus + cAdvisor | Container metrics |
| 13946 | NGINX Monitoring | Prometheus + nginx_exporter | Nginx metrics |

## Troubleshooting

### Issue: "Connection refused" on port 3000

**Fix:**
```bash
# Check if Grafana is running
sudo systemctl status grafana-server

# Start it
sudo systemctl start grafana-server

# Check logs
sudo journalctl -u grafana-server -f
```

### Issue: "Unauthorized" API errors

**Fix:**
```bash
# Verify credentials
curl -s -u admin:admin http://localhost:3000/api/org

# Or create a fresh API key
bash scripts/apikey.sh create --name "test" --role Admin
```

### Issue: Dashboard import fails with "datasource not found"

**Fix:** Ensure the data source name matches exactly:
```bash
bash scripts/datasource.sh list
# Use the exact name shown when importing
bash scripts/dashboard.sh import --id 1860 --datasource "exact-name-here"
```

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to Grafana API)
- `jq` (JSON parsing)
- Grafana OSS (installed by `scripts/install.sh`)
- Optional: Docker (for containerized install)
