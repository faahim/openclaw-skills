---
name: netdata-monitor
description: >-
  Install and configure Netdata for real-time system monitoring with web dashboards, alerting, and health checks.
categories: [automation, analytics]
dependencies: [bash, curl]
---

# Netdata System Monitor

## What This Does

Install, configure, and manage [Netdata](https://www.netdata.cloud/) — a real-time system monitoring platform with a web dashboard. Monitor CPU, memory, disk, network, containers, and 800+ services out of the box. Get alerts via Telegram, Slack, email, or webhook when things go wrong.

**Why an agent needs this:** Installing Netdata, configuring alerts, managing health checks, and tuning dashboards requires system-level setup that agents can't do with text generation alone.

## Quick Start (5 minutes)

### 1. Install Netdata

```bash
bash scripts/install.sh
```

This installs Netdata via the official kickstart script. Works on Ubuntu, Debian, CentOS, Fedora, RHEL, and macOS.

### 2. Verify Installation

```bash
bash scripts/status.sh
```

**Output:**
```
✅ Netdata is running
   Dashboard: http://localhost:19999
   Version: v1.45.0
   Uptime: 2 minutes
   Collectors: 47 active
```

### 3. Open Dashboard

Visit `http://<your-server-ip>:19999` in a browser. You'll see real-time charts for CPU, memory, disk, network, and more.

## Core Workflows

### Workflow 1: Install & Start Monitoring

```bash
# Install Netdata (non-interactive)
bash scripts/install.sh

# Check status
bash scripts/status.sh

# View dashboard URL
echo "Dashboard: http://$(hostname -I | awk '{print $1}'):19999"
```

### Workflow 2: Configure Telegram Alerts

```bash
# Set up Telegram notifications
bash scripts/configure-alerts.sh telegram \
  --bot-token "YOUR_BOT_TOKEN" \
  --chat-id "YOUR_CHAT_ID"
```

**Test it:**
```bash
bash scripts/test-alert.sh telegram
```

**Output:**
```
✅ Telegram alert sent successfully
   Check your Telegram for a test notification
```

### Workflow 3: Configure Slack Alerts

```bash
bash scripts/configure-alerts.sh slack \
  --webhook-url "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

### Workflow 4: Configure Email Alerts

```bash
bash scripts/configure-alerts.sh email \
  --to "admin@example.com" \
  --smtp-host "smtp.gmail.com" \
  --smtp-port 587 \
  --smtp-user "your-email@gmail.com" \
  --smtp-pass "your-app-password"
```

### Workflow 5: Add Custom Health Checks

```bash
# Alert when CPU > 90% for 5 minutes
bash scripts/add-health-check.sh \
  --name "high_cpu" \
  --metric "system.cpu" \
  --chart "system.cpu" \
  --lookup "average -5m percentage of user,system" \
  --warn "> 80" \
  --crit "> 90" \
  --info "CPU usage is critically high"

# Alert when disk space > 85%
bash scripts/add-health-check.sh \
  --name "disk_space_critical" \
  --metric "disk.space" \
  --chart "disk_space._" \
  --lookup "average -1m percentage of avail" \
  --warn "< 20" \
  --crit "< 10" \
  --info "Disk space running low"

# Alert when RAM > 90%
bash scripts/add-health-check.sh \
  --name "high_ram" \
  --metric "system.ram" \
  --chart "system.ram" \
  --lookup "average -5m percentage of used" \
  --warn "> 80" \
  --crit "> 90" \
  --info "RAM usage is critically high"
```

### Workflow 6: Monitor Docker Containers

```bash
# Enable Docker monitoring (auto-detected if Docker is installed)
bash scripts/enable-collector.sh docker

# Restart Netdata to pick up changes
sudo systemctl restart netdata
```

### Workflow 7: Monitor Nginx/Apache

```bash
# Enable Nginx monitoring
bash scripts/enable-collector.sh nginx --url "http://localhost/nginx_status"

# Enable Apache monitoring
bash scripts/enable-collector.sh apache --url "http://localhost/server-status?auto"
```

### Workflow 8: Export Metrics to Prometheus

```bash
# Enable Prometheus exporter (available at :19999/api/v1/allmetrics?format=prometheus)
bash scripts/configure-export.sh prometheus

echo "Prometheus endpoint: http://localhost:19999/api/v1/allmetrics?format=prometheus"
```

### Workflow 9: Query Metrics via CLI

```bash
# Get current CPU usage
bash scripts/query.sh system.cpu

# Get memory usage over last hour
bash scripts/query.sh system.ram --after -3600

# Get disk I/O
bash scripts/query.sh disk.io

# List all available charts
bash scripts/query.sh --list
```

### Workflow 10: Uninstall

```bash
bash scripts/uninstall.sh
```

## Configuration

### Main Config Location

```
/etc/netdata/netdata.conf        # Main config
/etc/netdata/health.d/           # Health check rules
/etc/netdata/health_alarm_notify.conf  # Alert destinations
/etc/netdata/go.d/               # Collector configs
```

### Environment Variables

```bash
# For alert setup scripts
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER="email@example.com"
export SMTP_PASS="app-password"
```

### Tuning Performance

```bash
# Reduce memory usage (default: 1h history in RAM)
bash scripts/tune.sh --history 1800  # 30 min history

# Increase history for long-term monitoring
bash scripts/tune.sh --history 7200  # 2 hours

# Change update frequency (default: 1 second)
bash scripts/tune.sh --update-every 2  # 2 seconds
```

## Troubleshooting

### Issue: "Netdata not running"

```bash
# Check service status
sudo systemctl status netdata

# Start if stopped
sudo systemctl start netdata

# Check logs
sudo journalctl -u netdata -n 50
```

### Issue: "Dashboard not accessible"

```bash
# Check if port 19999 is open
sudo ss -tlnp | grep 19999

# If behind firewall
sudo ufw allow 19999/tcp  # Ubuntu
sudo firewall-cmd --add-port=19999/tcp --permanent && sudo firewall-cmd --reload  # CentOS
```

### Issue: "Alerts not firing"

```bash
# Test alarm notification
sudo /usr/libexec/netdata/plugins.d/alarm-notify.sh test

# Check health config syntax
sudo netdatacli reload-health

# View active alarms
curl -s 'http://localhost:19999/api/v1/alarms?active' | jq .
```

### Issue: "High CPU usage by Netdata itself"

```bash
# Reduce collection frequency
bash scripts/tune.sh --update-every 5  # 5 seconds instead of 1

# Disable unused collectors
bash scripts/disable-collector.sh <collector-name>
```

## Key Principles

1. **Real-time** — 1-second granularity by default (configurable)
2. **Zero config** — Auto-detects 800+ services out of the box
3. **Low overhead** — ~2% CPU, ~100MB RAM typical
4. **Alert once** — Smart deduplication, no spam
5. **Self-hosted** — All data stays on your machine
