---
name: logrotate-manager
description: >-
  Configure, test, and manage log rotation on Linux servers. Prevent disk-full disasters.
categories: [automation, dev-tools]
dependencies: [bash, logrotate]
---

# Logrotate Manager

## What This Does

Manages log rotation on Linux servers — creates configs, tests them, audits existing rules, and monitors for unrotated logs eating disk space. Prevents the classic "server died because /var/log filled the disk" scenario.

**Example:** "Set up rotation for my app logs: keep 7 days, compress, max 100MB per file, alert if any log exceeds 500MB."

## Quick Start (2 minutes)

### 1. Check logrotate is installed

```bash
which logrotate || sudo apt-get install -y logrotate  # Debian/Ubuntu
# or: sudo yum install -y logrotate                    # RHEL/CentOS
```

### 2. Audit current rotation configs

```bash
bash scripts/logrotate-manager.sh audit
```

Output:
```
=== Logrotate Audit ===
Config files found: 14
  /etc/logrotate.d/apt
  /etc/logrotate.d/dpkg
  /etc/logrotate.d/nginx
  ...
Unrotated large logs (>100MB):
  ⚠️  /var/log/syslog — 245MB
  ⚠️  /var/log/app/output.log — 1.2GB
Logs without rotation config:
  ❌ /var/log/myapp/*.log
```

### 3. Create a rotation config

```bash
bash scripts/logrotate-manager.sh create \
  --path "/var/log/myapp/*.log" \
  --rotate 7 \
  --frequency daily \
  --compress \
  --maxsize 100M \
  --name myapp
```

Creates `/etc/logrotate.d/myapp`:
```
/var/log/myapp/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    maxsize 100M
    create 0640 root adm
    sharedscripts
    postrotate
        # Reload app if needed
    endscript
}
```

### 4. Test the config (dry run)

```bash
bash scripts/logrotate-manager.sh test --name myapp
# or test all:
bash scripts/logrotate-manager.sh test --all
```

## Core Workflows

### Workflow 1: Audit All Log Rotation

**Use case:** Find logs that aren't being rotated or are growing too large.

```bash
bash scripts/logrotate-manager.sh audit
```

Checks:
- All configs in `/etc/logrotate.d/` are valid
- Finds large log files (>100MB default, configurable with `--threshold`)
- Identifies log paths without any rotation config
- Reports last rotation timestamps

### Workflow 2: Create Rotation Config

**Use case:** Add rotation for a new application's logs.

```bash
bash scripts/logrotate-manager.sh create \
  --path "/var/log/myapp/*.log" \
  --rotate 14 \
  --frequency weekly \
  --compress \
  --maxsize 200M \
  --name myapp \
  --postrotate "systemctl reload myapp"
```

Options:
- `--path` — Log file path or glob pattern (required)
- `--rotate N` — Keep N rotated files (default: 7)
- `--frequency` — daily, weekly, monthly (default: daily)
- `--compress` — Enable gzip compression
- `--maxsize SIZE` — Rotate when file exceeds SIZE (e.g., 100M, 1G)
- `--name` — Config name in /etc/logrotate.d/ (required)
- `--postrotate` — Command to run after rotation
- `--owner USER:GROUP` — File ownership (default: root:adm)
- `--mode PERMS` — File permissions (default: 0640)

### Workflow 3: Monitor Log Sizes

**Use case:** Set up monitoring for log directory growth.

```bash
bash scripts/logrotate-manager.sh monitor \
  --dirs "/var/log,/opt/app/logs" \
  --threshold 500M \
  --alert-cmd 'echo "ALERT: $FILE is $SIZE" | mail -s "Log Alert" admin@example.com'
```

### Workflow 4: Force Rotation

**Use case:** Immediately rotate logs (e.g., before a deployment).

```bash
# Force rotate specific config
bash scripts/logrotate-manager.sh force --name myapp

# Force rotate all
bash scripts/logrotate-manager.sh force --all
```

### Workflow 5: List All Configs

```bash
bash scripts/logrotate-manager.sh list
```

Output:
```
Config              Path                        Frequency  Rotate  Compress  MaxSize
────────────────────────────────────────────────────────────────────────────────────
apt                 /var/log/apt/*.log           monthly    12      yes       -
dpkg                /var/log/dpkg.log            monthly    12      yes       -
nginx               /var/log/nginx/*.log         daily      14      yes       -
myapp               /var/log/myapp/*.log         daily      7       yes       100M
```

### Workflow 6: Remove a Config

```bash
bash scripts/logrotate-manager.sh remove --name myapp
```

## Configuration

### Environment Variables

```bash
# Default threshold for "large log" warnings (audit/monitor)
export LOGROTATE_THRESHOLD="100M"

# Default rotation count
export LOGROTATE_DEFAULT_ROTATE=7

# Alert command template ($FILE and $SIZE are substituted)
export LOGROTATE_ALERT_CMD='echo "⚠️ $FILE is $SIZE"'
```

## Troubleshooting

### Issue: "error: skipping ... because parent directory has insecure permissions"

**Fix:** logrotate requires strict permissions on config dirs:
```bash
sudo chmod 755 /etc/logrotate.d
sudo chown root:root /etc/logrotate.d
```

### Issue: Logs not rotating

**Check:**
1. Run dry test: `sudo logrotate -d /etc/logrotate.d/myapp`
2. Check state file: `cat /var/lib/logrotate/status`
3. Verify cron is running: `systemctl status cron`

### Issue: "error: myapp:1 duplicate log entry"

**Fix:** Two configs target the same log path. Run `bash scripts/logrotate-manager.sh audit` to find duplicates.

## Key Principles

1. **Always test first** — Use `--dry-run` before applying configs
2. **Use delaycompress** — Keeps last rotated file uncompressed for debugging
3. **Set maxsize** — Time-based rotation alone won't save you from log floods
4. **missingok + notifempty** — Don't error on missing files, don't rotate empty logs
5. **postrotate wisely** — Signal your app to reopen log handles (HUP, USR1, etc.)
