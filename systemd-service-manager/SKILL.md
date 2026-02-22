---
name: systemd-service-manager
description: >-
  Create, manage, and monitor systemd services — turn any script or process into a reliable, auto-restarting background service.
categories: [automation, dev-tools]
dependencies: [bash, systemctl]
---

# Systemd Service Manager

## What This Does

Turn any script, app, or process into a production-grade systemd service that starts on boot, auto-restarts on crash, and logs to journald. Create, enable, disable, restart, and monitor services without memorizing systemd syntax.

**Example:** "Make my Node.js app a systemd service that auto-restarts on failure, runs as www-data, and starts on boot."

## Quick Start (2 minutes)

### Create a Service

```bash
# Make any command a systemd service
sudo bash scripts/create-service.sh \
  --name my-app \
  --exec "/usr/bin/node /opt/my-app/server.js" \
  --user www-data \
  --restart on-failure \
  --env "NODE_ENV=production" \
  --env "PORT=3000" \
  --enable
```

Output:
```
✅ Service 'my-app' created at /etc/systemd/system/my-app.service
✅ Service enabled (starts on boot)
✅ Service started
● my-app.service - my-app managed service
   Active: active (running) since Sun 2026-02-22 11:50:00 UTC
```

## Core Workflows

### Workflow 1: Create a Service from a Script

```bash
sudo bash scripts/create-service.sh \
  --name backup-job \
  --exec "/home/user/scripts/backup.sh" \
  --type oneshot \
  --timer "daily" \
  --description "Daily backup job"
```

Creates both a service AND a timer (systemd cron equivalent).

### Workflow 2: Monitor All Services

```bash
bash scripts/status.sh
```

Output:
```
SERVICE              STATUS      CPU    MEM     UPTIME         RESTARTS
my-app               ● running   2.3%   148MB   3d 14h 22m     0
backup-job           ● idle      -      -       timer: daily   -
worker               ● running   8.1%   256MB   1d 2h 15m      2
redis-cache          ● running   0.5%   64MB    7d 0h 3m       0
```

### Workflow 3: View Logs

```bash
# Last 100 lines
bash scripts/logs.sh my-app --lines 100

# Follow live
bash scripts/logs.sh my-app --follow

# Since last hour
bash scripts/logs.sh my-app --since "1 hour ago"

# Errors only
bash scripts/logs.sh my-app --priority err
```

### Workflow 4: Manage a Service

```bash
# Stop
sudo bash scripts/manage.sh my-app stop

# Restart
sudo bash scripts/manage.sh my-app restart

# Disable (won't start on boot)
sudo bash scripts/manage.sh my-app disable

# Remove entirely
sudo bash scripts/manage.sh my-app remove

# Edit environment
sudo bash scripts/manage.sh my-app set-env "PORT=4000" "DEBUG=true"

# Reload after manual edits
sudo bash scripts/manage.sh my-app reload
```

### Workflow 5: Service Health Check

```bash
bash scripts/health.sh my-app
```

Output:
```
Service: my-app
Status:  ● active (running)
PID:     12345
Memory:  148.2 MB (limit: 512MB)
CPU:     2.3%
Uptime:  3 days, 14 hours
Restarts: 0 (last 24h)
Logs (last 5 errors): none
Port:    3000 (listening)
```

## Configuration

### Service Options (create-service.sh)

| Flag | Description | Default |
|------|-------------|---------|
| `--name` | Service name (required) | - |
| `--exec` | Command to run (required) | - |
| `--user` | Run as user | root |
| `--group` | Run as group | same as user |
| `--workdir` | Working directory | / |
| `--restart` | Restart policy: `no`, `on-failure`, `always` | on-failure |
| `--restart-sec` | Seconds between restarts | 5 |
| `--env` | Environment variable (repeatable) | - |
| `--env-file` | Path to env file | - |
| `--type` | Service type: `simple`, `forking`, `oneshot`, `notify` | simple |
| `--after` | Start after (e.g., `network.target`) | network.target |
| `--limit-mem` | Memory limit (e.g., `512M`) | - |
| `--limit-cpu` | CPU quota (e.g., `50%`) | - |
| `--timer` | Create timer: `daily`, `hourly`, `weekly`, or cron expr | - |
| `--enable` | Enable and start immediately | false |
| `--description` | Service description | auto-generated |

### Environment File Format

```bash
# /opt/my-app/.env
NODE_ENV=production
PORT=3000
DATABASE_URL=postgres://localhost/mydb
SECRET_KEY=your-secret-here
```

## Advanced Usage

### Resource Limits

```bash
sudo bash scripts/create-service.sh \
  --name worker \
  --exec "/opt/worker/run.sh" \
  --limit-mem 512M \
  --limit-cpu 50% \
  --restart always \
  --restart-sec 10
```

### Dependency Ordering

```bash
# Start after postgres
sudo bash scripts/create-service.sh \
  --name api-server \
  --exec "/opt/api/server" \
  --after "postgresql.service" \
  --enable
```

### Scheduled Tasks (Timers)

```bash
# Run every 6 hours
sudo bash scripts/create-service.sh \
  --name cleanup \
  --exec "/opt/scripts/cleanup.sh" \
  --type oneshot \
  --timer "*-*-* 0/6:00:00"

# Run at 3am daily
sudo bash scripts/create-service.sh \
  --name nightly-report \
  --exec "/opt/scripts/report.sh" \
  --type oneshot \
  --timer "03:00"
```

### Batch Service Status

```bash
# Check all custom services
bash scripts/status.sh --all

# Check specific services
bash scripts/status.sh my-app worker api-server

# JSON output (for scripting)
bash scripts/status.sh --json
```

## Troubleshooting

### Issue: "Failed to enable unit: Unit file not found"

**Fix:** Check the service file was created:
```bash
ls -la /etc/systemd/system/my-app.service
sudo systemctl daemon-reload
```

### Issue: Service keeps restarting

**Check logs:**
```bash
bash scripts/logs.sh my-app --lines 50 --priority err
```

**Common causes:**
- Wrong `--exec` path (check with `which` or use absolute paths)
- Missing permissions (check `--user`)
- Port already in use

### Issue: "Permission denied"

Service management requires sudo. Use `sudo bash scripts/...` for create/manage/remove operations. Status and logs work without sudo.

## Dependencies

- `bash` (4.0+)
- `systemctl` (systemd — standard on Ubuntu, Debian, CentOS, Fedora, Arch)
- `journalctl` (for logs — part of systemd)
- Optional: `ss` or `netstat` (for port checking in health command)
