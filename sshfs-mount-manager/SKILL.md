---
name: sshfs-mount-manager
description: >-
  Mount remote filesystems over SSH — access remote files as local directories with automatic reconnection.
categories: [automation, data]
dependencies: [sshfs, ssh, fuse]
---

# SSHFS Remote Mount Manager

## What This Does

Mount remote server directories as local folders over SSH. Browse, edit, and manage remote files as if they were on your local machine — no FTP, no rsync, no manual copying. Includes automatic mounting on boot, connection health checks, and multi-server profiles.

**Example:** "Mount your VPS `/var/www` to local `~/remote/vps-web`, edit files in your IDE, changes sync instantly."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. Mount a Remote Directory

```bash
bash scripts/sshfs-manager.sh mount \
  --host user@server.com \
  --remote /var/www \
  --local ~/remote/server-web
```

### 3. List Active Mounts

```bash
bash scripts/sshfs-manager.sh list
```

### 4. Unmount

```bash
bash scripts/sshfs-manager.sh unmount --local ~/remote/server-web
```

## Core Workflows

### Workflow 1: Quick Mount

**Use case:** Temporarily mount a remote directory for editing

```bash
bash scripts/sshfs-manager.sh mount \
  --host deploy@prod.example.com \
  --remote /opt/app/config \
  --local ~/remote/prod-config

# Edit files locally
nano ~/remote/prod-config/settings.yaml

# Done — unmount
bash scripts/sshfs-manager.sh unmount --local ~/remote/prod-config
```

### Workflow 2: Persistent Profile

**Use case:** Save a mount profile for repeated use

```bash
# Save profile
bash scripts/sshfs-manager.sh save-profile \
  --name prod-server \
  --host deploy@prod.example.com \
  --remote /var/www/html \
  --local ~/remote/prod-web \
  --port 2222 \
  --identity ~/.ssh/prod_key

# Mount by profile name
bash scripts/sshfs-manager.sh mount --profile prod-server

# Unmount by profile name
bash scripts/sshfs-manager.sh unmount --profile prod-server
```

### Workflow 3: Auto-Mount on Boot

**Use case:** Always have remote directories available

```bash
# Enable auto-mount for a profile
bash scripts/sshfs-manager.sh auto-mount --profile prod-server --enable

# Disable auto-mount
bash scripts/sshfs-manager.sh auto-mount --profile prod-server --disable
```

### Workflow 4: Mount Multiple Servers

```bash
# Mount all saved profiles
bash scripts/sshfs-manager.sh mount-all

# Unmount all
bash scripts/sshfs-manager.sh unmount-all

# Check status of all mounts
bash scripts/sshfs-manager.sh status
```

### Workflow 5: Health Check

**Use case:** Verify mounts are alive, reconnect if dropped

```bash
# Check all mounts
bash scripts/sshfs-manager.sh health

# Output:
# ✅ prod-server: /var/www/html → ~/remote/prod-web (healthy, 23ms)
# ❌ staging: /opt/app → ~/remote/staging (disconnected — reconnecting...)
# ✅ staging: reconnected successfully
```

## Configuration

### Profile Config File

Profiles are stored in `~/.config/sshfs-manager/profiles.yaml`:

```yaml
profiles:
  prod-server:
    host: deploy@prod.example.com
    remote: /var/www/html
    local: ~/remote/prod-web
    port: 22
    identity: ~/.ssh/id_rsa
    options:
      - reconnect
      - ServerAliveInterval=15
      - ServerAliveCountMax=3
      - cache_timeout=115200
    auto_mount: true

  dev-box:
    host: dev@192.168.1.50
    remote: /home/dev/projects
    local: ~/remote/dev-projects
    port: 22
    options:
      - allow_other
      - default_permissions
    auto_mount: false
```

### SSHFS Options Reference

| Option | Description |
|--------|-------------|
| `reconnect` | Auto-reconnect on connection drop |
| `ServerAliveInterval=N` | Send keepalive every N seconds |
| `ServerAliveCountMax=N` | Max failed keepalives before disconnect |
| `cache_timeout=N` | Cache file attributes for N seconds |
| `allow_other` | Allow other users to access mount |
| `default_permissions` | Enable permission checking |
| `compression=yes` | Enable compression (slow network) |
| `IdentityFile=path` | SSH key to use |
| `Port=N` | SSH port |

## Advanced Usage

### Mount with Compression (Slow Networks)

```bash
bash scripts/sshfs-manager.sh mount \
  --host user@remote.com \
  --remote /data \
  --local ~/remote/data \
  --options "compression=yes,cache_timeout=300"
```

### Run as Cron Health Check

```bash
# Check every 5 minutes, reconnect dropped mounts
*/5 * * * * bash /path/to/scripts/sshfs-manager.sh health --auto-reconnect >> /var/log/sshfs-health.log 2>&1
```

### Backup Remote to Local via Mount

```bash
# Mount, then rsync from mount point
bash scripts/sshfs-manager.sh mount --profile prod-server
rsync -av ~/remote/prod-web/ ~/backups/prod-web-$(date +%Y%m%d)/
bash scripts/sshfs-manager.sh unmount --profile prod-server
```

## Troubleshooting

### Issue: "fuse: mount failed: Permission denied"

**Fix:**
```bash
# Add user to fuse group
sudo usermod -aG fuse $USER
# Logout and login again
```

### Issue: "Transport endpoint is not connected"

**Fix:**
```bash
# Force unmount stale mount
fusermount -uz ~/remote/stale-mount
# Remount
bash scripts/sshfs-manager.sh mount --profile <name>
```

### Issue: Mount disappears after reboot

**Fix:** Enable auto-mount:
```bash
bash scripts/sshfs-manager.sh auto-mount --profile <name> --enable
```

### Issue: Permission denied on mounted files

**Fix:** Use `default_permissions` and `allow_other` options:
```bash
bash scripts/sshfs-manager.sh mount \
  --host user@server \
  --remote /path \
  --local ~/mount \
  --options "allow_other,default_permissions"
```

Also add to `/etc/fuse.conf`:
```
user_allow_other
```

### Issue: Slow file access

**Fix:** Enable caching:
```bash
--options "cache_timeout=115200,attr_timeout=115200"
```

## Dependencies

- `sshfs` (FUSE-based SSH filesystem client)
- `fuse` / `fuse3` (Filesystem in Userspace)
- `ssh` (OpenSSH client)
- `bash` (4.0+)
- Optional: `yq` (YAML parsing for profiles)
