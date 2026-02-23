---
name: auto-update-manager
description: >-
  Configure and manage automatic security updates, unattended upgrades, and scheduled maintenance reboots on Linux servers.
categories: [security, automation]
dependencies: [bash, apt, systemd]
---

# Auto-Update Manager

## What This Does

Configures automatic security updates on Debian/Ubuntu servers so your system stays patched without manual intervention. Sets up unattended-upgrades, configures email notifications, schedules maintenance windows for reboots, and monitors update status.

**Example:** "Enable auto security updates, email me on failures, auto-reboot at 4am Sunday if needed, and show me what's pending."

## Quick Start (5 minutes)

### 1. Check Current State

```bash
bash scripts/auto-update.sh status
```

**Output:**
```
[auto-update] System: Ubuntu 22.04 LTS (jammy)
[auto-update] Unattended-upgrades: NOT installed
[auto-update] Pending security updates: 3
[auto-update] Last update: never
[auto-update] Auto-reboot: disabled
```

### 2. Install & Enable Auto-Updates

```bash
sudo bash scripts/auto-update.sh setup
```

This will:
- Install `unattended-upgrades` if missing
- Enable security-only auto-updates
- Configure daily update check
- Enable update logging to `/var/log/unattended-upgrades/`

### 3. Configure Notifications (Optional)

```bash
sudo bash scripts/auto-update.sh configure --email admin@example.com
```

## Core Workflows

### Workflow 1: Full Setup with Auto-Reboot

**Use case:** Production server that can reboot during maintenance window

```bash
sudo bash scripts/auto-update.sh setup \
  --auto-reboot \
  --reboot-time "04:00" \
  --email admin@example.com \
  --blacklist "linux-image-* docker-ce"
```

**What it configures:**
- Security updates applied daily at 2am
- Auto-reboot at 4am if kernel update requires it
- Email notification on every update
- Blacklists kernel and Docker packages from auto-update

### Workflow 2: Security-Only, No Reboot

**Use case:** App server where uptime is critical

```bash
sudo bash scripts/auto-update.sh setup \
  --no-reboot \
  --security-only \
  --email ops@example.com
```

### Workflow 3: Check Pending Updates

**Use case:** See what needs updating without applying

```bash
bash scripts/auto-update.sh pending
```

**Output:**
```
[auto-update] Pending security updates:
  - libssl3 3.0.2-0ubuntu1.15 -> 3.0.2-0ubuntu1.16 (security)
  - openssh-server 1:8.9p1-3ubuntu0.6 -> 1:8.9p1-3ubuntu0.7 (security)
  - curl 7.81.0-1ubuntu1.15 -> 7.81.0-1ubuntu1.16 (security)

[auto-update] Pending regular updates: 12 packages
[auto-update] Reboot required: NO
```

### Workflow 4: Force Update Now

**Use case:** Apply all pending security updates immediately

```bash
sudo bash scripts/auto-update.sh apply-now
```

### Workflow 5: View Update History

**Use case:** Audit what was auto-updated

```bash
bash scripts/auto-update.sh history --days 30
```

**Output:**
```
[auto-update] Updates in last 30 days:

2026-02-22 02:15:00 — 3 packages updated (security)
  - openssl 3.0.2-0ubuntu1.15 -> 3.0.2-0ubuntu1.16
  - libssl3 3.0.2-0ubuntu1.15 -> 3.0.2-0ubuntu1.16
  - curl 7.81.0-1ubuntu1.15 -> 7.81.0-1ubuntu1.16

2026-02-15 02:22:00 — 1 package updated (security)
  - openssh-server 1:8.9p1-3ubuntu0.5 -> 1:8.9p1-3ubuntu0.6

Total: 4 packages updated, 0 failures
```

### Workflow 6: Disable Auto-Updates

```bash
sudo bash scripts/auto-update.sh disable
```

## Configuration

### Config File

After setup, config lives at `/etc/apt/apt.conf.d/50unattended-upgrades` and `/etc/apt/apt.conf.d/20auto-upgrades`.

The setup script configures these automatically, but you can also edit directly:

```bash
# View current config
bash scripts/auto-update.sh show-config

# Reset to defaults
sudo bash scripts/auto-update.sh reset
```

### Blacklisting Packages

Prevent specific packages from being auto-updated:

```bash
# Add to blacklist
sudo bash scripts/auto-update.sh blacklist add "nginx docker-ce mysql-server"

# Remove from blacklist
sudo bash scripts/auto-update.sh blacklist remove "nginx"

# Show blacklist
bash scripts/auto-update.sh blacklist list
```

### Reboot Schedule

```bash
# Enable auto-reboot at specific time
sudo bash scripts/auto-update.sh reboot --enable --time "04:00"

# Disable auto-reboot
sudo bash scripts/auto-update.sh reboot --disable

# Check if reboot is needed
bash scripts/auto-update.sh reboot-needed
```

## Advanced Usage

### Monitor with OpenClaw Cron

Set up a daily status check:

```bash
# In your OpenClaw cron, run:
bash scripts/auto-update.sh status --json
```

Returns JSON for easy parsing:
```json
{
  "unattended_upgrades": true,
  "pending_security": 2,
  "pending_regular": 8,
  "reboot_required": false,
  "last_update": "2026-02-22T02:15:00Z",
  "last_update_packages": 3,
  "blacklisted": ["linux-image-*", "docker-ce"]
}
```

### Multi-Server Setup

```bash
# Generate config for remote servers
bash scripts/auto-update.sh generate-config \
  --auto-reboot --reboot-time "04:00" \
  --email ops@example.com \
  > /tmp/auto-update-config.sh

# Apply to remote server
ssh user@server 'bash -s' < /tmp/auto-update-config.sh
```

## Troubleshooting

### Issue: "unattended-upgrades not running"

**Check:**
```bash
systemctl status unattended-upgrades
journalctl -u unattended-upgrades --since "1 day ago"
```

**Fix:**
```bash
sudo systemctl enable --now unattended-upgrades
```

### Issue: Updates not being applied

**Check logs:**
```bash
cat /var/log/unattended-upgrades/unattended-upgrades.log
```

**Common causes:**
- dpkg lock held by another process
- Package conflicts requiring manual resolution
- Network issues reaching repositories

### Issue: Unwanted reboot

**Fix:** Disable auto-reboot:
```bash
sudo bash scripts/auto-update.sh reboot --disable
```

### Issue: Email notifications not working

**Check:** Ensure `mailutils` or `bsd-mailx` is installed:
```bash
sudo apt install -y mailutils
echo "Test" | mail -s "Test" admin@example.com
```

## Supported Distributions

- Ubuntu 18.04+ (Bionic, Focal, Jammy, Noble)
- Debian 10+ (Buster, Bullseye, Bookworm)
- Linux Mint 20+

**Not supported:** RHEL/CentOS/Fedora (use `dnf-automatic` instead — future version)

## Dependencies

- `bash` (4.0+)
- `apt` (Debian/Ubuntu package manager)
- `systemd` (for service management)
- `unattended-upgrades` (auto-installed by setup)
- Optional: `mailutils` (for email notifications)
