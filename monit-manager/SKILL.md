---
name: monit-manager
description: >-
  Install, configure, and manage Monit for automatic process supervision, service monitoring, and self-healing restarts.
categories: [automation, dev-tools]
dependencies: [monit, bash, curl]
---

# Monit Manager

## What This Does

Monit is a lightweight process supervision daemon that monitors services, files, directories, and filesystems — and can **automatically restart crashed services**. This skill installs Monit, configures monitoring rules, and manages service definitions.

**Example:** "Monitor nginx, PostgreSQL, and Redis. Auto-restart if any crash. Alert via email or webhook if a service fails 3 times in a row."

## Quick Start (5 minutes)

### 1. Install Monit

```bash
bash scripts/install.sh
```

This installs Monit and enables it as a system service.

### 2. Add Your First Service Monitor

```bash
# Monitor nginx — auto-restart on crash
bash scripts/add-service.sh \
  --name nginx \
  --pidfile /var/run/nginx.pid \
  --start "/usr/sbin/nginx" \
  --stop "/usr/sbin/nginx -s stop" \
  --check-url "http://localhost:80"
```

### 3. Check Status

```bash
sudo monit status
# Or use the script:
bash scripts/status.sh
```

**Output:**
```
Process 'nginx'
  status                       OK
  monitoring status            Monitored
  monitoring mode              active
  on reboot                    start
  pid                          1234
  uptime                       2d 4h 15m
  memory                       12.5 MB
  cpu                          0.2%
```

## Core Workflows

### Workflow 1: Monitor a Process by PID File

**Use case:** Monitor any service that writes a PID file

```bash
bash scripts/add-service.sh \
  --name postgresql \
  --pidfile /var/run/postgresql/14-main.pid \
  --start "systemctl start postgresql" \
  --stop "systemctl stop postgresql"
```

**What happens:** Monit checks every 30 seconds. If the process dies, it auto-restarts it.

### Workflow 2: Monitor a Process by Matching Name

**Use case:** Monitor processes without PID files

```bash
bash scripts/add-service.sh \
  --name "node-app" \
  --match "node /home/app/server.js" \
  --start "cd /home/app && node server.js &" \
  --stop "pkill -f 'node /home/app/server.js'"
```

### Workflow 3: Monitor with HTTP Health Check

**Use case:** Check if a web service is actually responding, not just running

```bash
bash scripts/add-service.sh \
  --name myapp \
  --pidfile /var/run/myapp.pid \
  --start "systemctl start myapp" \
  --stop "systemctl stop myapp" \
  --check-url "http://localhost:3000/health" \
  --check-status 200 \
  --check-timeout 10
```

**On failure:** Monit restarts the service and logs the event.

### Workflow 4: Monitor System Resources

**Use case:** Alert when CPU, memory, or disk usage is too high

```bash
bash scripts/add-system-check.sh \
  --cpu-warn 80 \
  --cpu-critical 95 \
  --mem-warn 80 \
  --mem-critical 95 \
  --disk "/" --disk-warn 85 --disk-critical 95
```

### Workflow 5: Monitor a File for Changes

**Use case:** Detect unauthorized config changes

```bash
bash scripts/add-file-check.sh \
  --path /etc/nginx/nginx.conf \
  --checksum sha256 \
  --on-change "systemctl reload nginx"
```

### Workflow 6: Set Up Alerts

**Use case:** Get notified when services fail

```bash
# Email alerts
bash scripts/configure-alerts.sh \
  --email admin@example.com \
  --smtp smtp.gmail.com \
  --smtp-port 587 \
  --smtp-user user@gmail.com \
  --smtp-pass "app-password"

# Webhook alerts (Slack, Discord, etc.)
bash scripts/configure-alerts.sh \
  --webhook "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

## Configuration

### Monit Config Location

```
/etc/monit/monitrc           # Main config
/etc/monit/conf.d/           # Service definitions (one file per service)
/etc/monit/conf-enabled/     # Enabled service links
```

### Example Service Definition

```
# /etc/monit/conf.d/nginx.conf
check process nginx with pidfile /var/run/nginx.pid
  start program = "/usr/sbin/nginx"
  stop program  = "/usr/sbin/nginx -s stop"
  if failed host localhost port 80 protocol http
    with timeout 10 seconds
    then restart
  if 3 restarts within 5 cycles then alert
  if cpu > 80% for 5 cycles then alert
  if memory > 200 MB then alert
```

### Environment Variables

```bash
# Email alerts (optional)
export MONIT_ALERT_EMAIL="admin@example.com"
export MONIT_SMTP_HOST="smtp.gmail.com"
export MONIT_SMTP_PORT="587"
export MONIT_SMTP_USER="user@gmail.com"
export MONIT_SMTP_PASS="app-password"

# Webhook alerts (optional)
export MONIT_WEBHOOK_URL="https://hooks.slack.com/..."

# Web UI (optional)
export MONIT_WEB_PORT="2812"
export MONIT_WEB_USER="admin"
export MONIT_WEB_PASS="monit"
```

## Advanced Usage

### Enable Monit Web UI

```bash
bash scripts/configure-webui.sh \
  --port 2812 \
  --user admin \
  --password "your-secure-password" \
  --allow localhost \
  --allow 192.168.1.0/24
```

Access at `http://your-server:2812`

### List All Monitored Services

```bash
bash scripts/status.sh --all
```

### Remove a Service Monitor

```bash
bash scripts/remove-service.sh --name nginx
```

### Test Configuration

```bash
sudo monit -t
# Output: Control file syntax OK
```

### View Monit Log

```bash
bash scripts/logs.sh --tail 50
# Or: tail -50 /var/log/monit.log
```

## Troubleshooting

### Issue: "monit: command not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install monit

# CentOS/RHEL
sudo yum install monit

# Alpine
sudo apk add monit
```

### Issue: Service keeps restarting in a loop

**Cause:** Start command fails silently.

**Fix:** Check the start command works manually:
```bash
# Test the start command directly
sudo /usr/sbin/nginx
# Check monit log
tail -20 /var/log/monit.log
```

### Issue: "Cannot connect to monit daemon"

**Fix:**
```bash
sudo systemctl start monit
sudo systemctl enable monit
```

### Issue: Email alerts not working

**Check:**
1. SMTP credentials are correct
2. Test: `bash scripts/test-alert.sh --email admin@example.com`
3. Check monit log: `grep -i mail /var/log/monit.log`

## Key Principles

1. **Auto-heal** — Crashed services restart automatically within 30 seconds
2. **Escalation** — After 3 failed restarts, stop trying and alert
3. **Lightweight** — Monit uses <2MB RAM, negligible CPU
4. **Self-monitoring** — Monit monitors itself via its init system
5. **Secure** — Web UI restricted by IP and credentials

## Dependencies

- `monit` (5.25+)
- `bash` (4.0+)
- `curl` (for webhook alerts)
- Optional: SMTP server for email alerts
