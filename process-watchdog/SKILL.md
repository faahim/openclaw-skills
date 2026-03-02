---
name: process-watchdog
description: >-
  Monitor processes and auto-restart them on crash with alerting and logging.
categories: [automation, dev-tools]
dependencies: [bash, ps, systemctl]
---

# Process Watchdog

## What This Does

Monitors one or more processes (by name, PID, or systemd service). If a process dies, it auto-restarts it and sends an alert (Telegram, email, or webhook). Logs all events with timestamps for post-incident review.

**Example:** "Watch nginx, postgres, and my-app. If any crash, restart and alert me on Telegram within 30 seconds."

## Quick Start (5 minutes)

### 1. Install

```bash
# No external dependencies — uses standard Linux tools
# Copy scripts to a permanent location
mkdir -p ~/.local/share/process-watchdog
cp scripts/* ~/.local/share/process-watchdog/
chmod +x ~/.local/share/process-watchdog/*.sh
```

### 2. Watch a Single Process

```bash
# Monitor nginx — restart if it dies
bash scripts/watchdog.sh --name nginx --restart "systemctl start nginx" --interval 10

# Output:
# [2026-03-02 07:00:00] 👁️ Watching: nginx (interval: 10s)
# [2026-03-02 07:00:10] ✅ nginx — running (PID: 1234)
# [2026-03-02 07:00:20] ✅ nginx — running (PID: 1234)
```

### 3. Watch with Telegram Alerts

```bash
export WATCHDOG_TELEGRAM_TOKEN="your-bot-token"
export WATCHDOG_TELEGRAM_CHAT="your-chat-id"

bash scripts/watchdog.sh \
  --name nginx \
  --restart "systemctl start nginx" \
  --alert telegram \
  --interval 15
```

### 4. Use Config File for Multiple Processes

```bash
cp scripts/config-template.yaml watchdog.yaml
# Edit watchdog.yaml with your processes
bash scripts/watchdog.sh --config watchdog.yaml
```

## Core Workflows

### Workflow 1: Monitor a Systemd Service

```bash
bash scripts/watchdog.sh \
  --service nginx \
  --interval 10 \
  --alert telegram
```

Uses `systemctl is-active` to check and `systemctl restart` to recover.

### Workflow 2: Monitor a Process by Name

```bash
bash scripts/watchdog.sh \
  --name "node server.js" \
  --restart "cd /app && node server.js &" \
  --interval 15
```

Uses `pgrep` to detect. Runs custom restart command.

### Workflow 3: Monitor by PID File

```bash
bash scripts/watchdog.sh \
  --pidfile /var/run/myapp.pid \
  --restart "/opt/myapp/start.sh" \
  --interval 10
```

### Workflow 4: Multi-Process Config

```bash
bash scripts/watchdog.sh --config watchdog.yaml
```

Config file:

```yaml
processes:
  - name: nginx
    type: service
    interval: 10
    max_restarts: 5
    cooldown: 60
    alerts: [telegram]

  - name: "node /app/server.js"
    type: process
    restart_cmd: "cd /app && node server.js &"
    interval: 15
    max_restarts: 3
    cooldown: 120
    alerts: [telegram, webhook]

  - name: postgres
    type: service
    interval: 30
    max_restarts: 3
    alerts: [telegram]
```

### Workflow 5: Run as Systemd Service (Persistent)

```bash
bash scripts/install-service.sh --config /path/to/watchdog.yaml
# Creates and enables systemd service: process-watchdog.service
# Starts automatically on boot
```

## Configuration

### Environment Variables

```bash
# Telegram alerts
export WATCHDOG_TELEGRAM_TOKEN="<bot-token>"
export WATCHDOG_TELEGRAM_CHAT="<chat-id>"

# Webhook alerts
export WATCHDOG_WEBHOOK_URL="https://hooks.slack.com/services/..."

# Email alerts (via sendmail/msmtp)
export WATCHDOG_EMAIL_TO="admin@example.com"
export WATCHDOG_EMAIL_FROM="watchdog@server.com"

# Log file location (default: /var/log/process-watchdog.log)
export WATCHDOG_LOG="/var/log/process-watchdog.log"
```

### Config File Format

```yaml
# watchdog.yaml
global:
  interval: 10           # Default check interval (seconds)
  max_restarts: 5        # Max restarts before giving up
  cooldown: 60           # Seconds between restart attempts
  log_file: /var/log/process-watchdog.log
  alerts:
    telegram:
      token: "${WATCHDOG_TELEGRAM_TOKEN}"
      chat_id: "${WATCHDOG_TELEGRAM_CHAT}"
    webhook:
      url: "${WATCHDOG_WEBHOOK_URL}"

processes:
  - name: nginx
    type: service         # systemd service
    interval: 10
    alerts: [telegram]

  - name: "my-app"
    type: process         # pgrep match
    restart_cmd: "/opt/my-app/start.sh"
    interval: 15
    max_restarts: 3
    alerts: [telegram, webhook]
```

### CLI Options

```
--name <process>      Process name (pgrep match)
--service <name>      Systemd service name
--pidfile <path>      PID file to check
--restart <cmd>       Custom restart command
--interval <secs>     Check interval (default: 10)
--max-restarts <n>    Max restarts before stopping (default: 5)
--cooldown <secs>     Cooldown between restarts (default: 60)
--alert <type>        Alert type: telegram, webhook, email
--config <file>       YAML config file
--log <file>          Log file path
--daemon              Run in background
```

## Advanced Usage

### Run as Cron (Alternative to Daemon)

```bash
# Add to crontab — check every minute
* * * * * bash /path/to/scripts/watchdog.sh --name myapp --restart "/opt/myapp/start.sh" --once 2>&1 >> /var/log/watchdog.log
```

### Custom Health Checks

```bash
bash scripts/watchdog.sh \
  --name myapp \
  --health-cmd "curl -sf http://localhost:3000/health" \
  --restart "systemctl restart myapp" \
  --interval 30
```

Not just "is it running?" but "is it healthy?"

### Restart History & Statistics

```bash
bash scripts/watchdog.sh --stats
# Output:
# Process Watchdog Statistics (last 7 days)
# ─────────────────────────────────────────
# nginx:    0 restarts, 100.0% uptime
# my-app:   3 restarts, 99.7% uptime
# postgres: 1 restart,  99.9% uptime
```

### Flap Detection

If a process restarts more than `max_restarts` times within the cooldown window, the watchdog stops trying and sends a critical alert:

```
🚨 CRITICAL: my-app has restarted 5 times in 5 minutes. Watchdog is backing off. Manual intervention required.
```

## Troubleshooting

### Issue: "Process not found" but it's running

**Fix:** Check the exact process name:
```bash
pgrep -la "your-process"
# Use the exact match string from output
```

### Issue: Restart command fails

**Fix:** Test the restart command manually first:
```bash
bash -c "your-restart-command"
```

### Issue: Telegram alerts not sending

**Check:**
```bash
curl -s "https://api.telegram.org/bot${WATCHDOG_TELEGRAM_TOKEN}/sendMessage?chat_id=${WATCHDOG_TELEGRAM_CHAT}&text=Test"
```

### Issue: Permission denied on systemctl

**Fix:** Run watchdog as root or add sudoers rule:
```bash
echo "watchdog ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx" | sudo tee /etc/sudoers.d/watchdog
```

## Key Principles

1. **Fast detection** — Default 10s interval (configurable)
2. **Smart restarts** — Cooldown + max restart limits prevent restart loops
3. **Flap detection** — Backs off if process keeps crashing
4. **Multi-channel alerts** — Telegram, webhook, email
5. **Lightweight** — Pure bash, no dependencies
6. **Persistent** — Can install as systemd service
