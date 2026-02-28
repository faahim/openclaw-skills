---
name: glances-dashboard
description: >-
  Install and run Glances as a real-time system monitoring web dashboard with alerts, Docker monitoring, and export capabilities.
categories: [automation, analytics]
dependencies: [python3, pip]
---

# Glances System Dashboard

## What This Does

Installs and configures [Glances](https://github.com/nicolargo/glances) — a cross-platform system monitoring tool with a real-time web dashboard. Monitor CPU, RAM, disk, network, Docker containers, processes, and more from your browser or terminal. Set up alerts for resource thresholds and export metrics to InfluxDB, Prometheus, or CSV.

**Example:** "Install Glances, start the web dashboard on port 61208, alert me when CPU > 90% or disk > 85%."

## Quick Start (5 minutes)

### 1. Install Glances

```bash
bash scripts/install.sh
```

This installs Glances via pip with all optional dependencies (Docker, web UI, export plugins).

### 2. Start Web Dashboard

```bash
bash scripts/run.sh --web
```

Open `http://localhost:61208` in your browser. You'll see real-time metrics for CPU, memory, disk, network, and processes.

### 3. Start with Alerts

```bash
bash scripts/run.sh --web --config config.yaml
```

Edit `config.yaml` to set CPU/memory/disk thresholds and get notified.

## Core Workflows

### Workflow 1: Terminal Dashboard

**Use case:** Quick system overview in the terminal

```bash
glances
```

**Output:** Full-screen terminal UI showing all system metrics in real-time.

### Workflow 2: Web Dashboard

**Use case:** Monitor from browser, share with team

```bash
bash scripts/run.sh --web --port 61208 --bind 0.0.0.0
```

Access at `http://<server-ip>:61208`. Password-protect with `--password`.

### Workflow 3: Docker Container Monitoring

**Use case:** Monitor all Docker containers alongside system metrics

```bash
bash scripts/run.sh --web --docker
```

Shows per-container CPU, memory, network I/O, and block I/O.

### Workflow 4: Alert on Thresholds

**Use case:** Get notified when resources are critical

```bash
bash scripts/run.sh --web --config config.yaml
```

Config sets thresholds:
- CPU > 90% → critical alert
- Memory > 85% → warning
- Disk > 90% → critical alert

### Workflow 5: Export Metrics

**Use case:** Send metrics to monitoring stack

```bash
# Export to CSV
bash scripts/run.sh --export csv --export-csv-file /var/log/glances/metrics.csv

# Export to Prometheus (exposes /metrics endpoint)
bash scripts/run.sh --web --export prometheus

# Export to InfluxDB
bash scripts/run.sh --export influxdb2 --config config.yaml
```

### Workflow 6: Run as Systemd Service

**Use case:** Auto-start on boot, always-on monitoring

```bash
sudo bash scripts/install-service.sh
```

Creates a systemd service that starts Glances web dashboard on boot.

### Workflow 7: Client-Server Mode

**Use case:** Monitor multiple servers from one dashboard

```bash
# On each remote server:
bash scripts/run.sh --server --bind 0.0.0.0

# On your machine, connect:
glances --client <server-ip>
```

### Workflow 8: Quick System Snapshot

**Use case:** Get a one-time JSON snapshot of system stats

```bash
bash scripts/snapshot.sh
```

Outputs JSON with CPU, memory, disk, network, load, and top processes.

## Configuration

### Config File (config.yaml)

```yaml
# Glances configuration
# Copy to ~/.config/glances/glances.conf or pass with --config

[global]
refresh=2

[cpu]
careful=50
warning=70
critical=90

[mem]
careful=50
warning=70
critical=90

[memswap]
careful=50
warning=70
critical=90

[fs]
careful=50
warning=70
critical=90

[docker]
disable=False

[network]
hide=lo,docker.*

[diskio]
hide=loop.*

[processlist]
sort_key=cpu_percent

[influxdb2]
host=localhost
port=8086
protocol=http
org=my-org
bucket=glances
token=my-token
```

### Environment Variables

```bash
# Web dashboard auth
export GLANCES_PASSWORD="your-password"

# InfluxDB export
export INFLUXDB_TOKEN="your-token"
export INFLUXDB_ORG="your-org"
export INFLUXDB_BUCKET="glances"
```

## Advanced Usage

### RESTful API

Glances web mode exposes a full REST API:

```bash
# Get all stats
curl http://localhost:61208/api/4/all

# Get CPU stats
curl http://localhost:61208/api/4/cpu

# Get memory stats
curl http://localhost:61208/api/4/mem

# Get disk usage
curl http://localhost:61208/api/4/fs

# Get Docker stats
curl http://localhost:61208/api/4/containers

# Get top processes
curl http://localhost:61208/api/4/processlist
```

### Integrate with OpenClaw Cron

```bash
# Check every 5 minutes, alert if critical
*/5 * * * * bash /path/to/scripts/snapshot.sh | python3 -c "
import json, sys
d = json.load(sys.stdin)
cpu = d.get('cpu', {}).get('total', 0)
mem = d.get('mem', {}).get('percent', 0)
if cpu > 90 or mem > 90:
    print(f'ALERT: CPU={cpu}% MEM={mem}%')
    sys.exit(1)
" && echo "OK" || echo "CRITICAL"
```

### Custom Theme / Disable Sections

```bash
# Disable specific plugins
glances --web --disable-plugin sensors --disable-plugin raid

# Minimal view
glances --web --disable-plugin alert --disable-plugin amps --disable-plugin cloud
```

## Troubleshooting

### Issue: "pip: command not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install python3-pip

# Mac
brew install python3
```

### Issue: Docker stats not showing

**Fix:**
```bash
# Ensure Docker is running
sudo systemctl status docker

# Ensure user has Docker access
sudo usermod -aG docker $USER
# Then logout/login

# Install Docker plugin
pip3 install glances[docker]
```

### Issue: Web dashboard not accessible remotely

**Fix:**
```bash
# Bind to all interfaces (not just localhost)
bash scripts/run.sh --web --bind 0.0.0.0

# Check firewall
sudo ufw allow 61208/tcp
```

### Issue: "Permission denied" for sensors

**Fix:**
```bash
# Install lm-sensors
sudo apt-get install lm-sensors
sudo sensors-detect --auto

# Run Glances with sensor support
pip3 install glances[sensors]
```

### Issue: High CPU usage from Glances itself

**Fix:** Increase refresh interval
```bash
glances --web --time 5  # Refresh every 5 seconds instead of 2
```

## Dependencies

- `python3` (3.8+)
- `pip3` (Python package manager)
- Optional: `docker` (for container monitoring)
- Optional: `lm-sensors` (for hardware temperature)
- Optional: `hddtemp` (for disk temperature)
