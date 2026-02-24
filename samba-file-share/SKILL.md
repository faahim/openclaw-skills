---
name: samba-file-share
description: >-
  Install, configure, and manage Samba/SMB file shares on Linux for local network file sharing.
categories: [home, automation]
dependencies: [samba, bash]
---

# Samba File Share Manager

## What This Does

Set up and manage SMB/CIFS file shares on your Linux machine so any device on your network (Windows, Mac, phones) can access shared folders. Handles installation, share creation, user management, and permissions — all from the command line.

**Example:** "Create a shared folder at /srv/shared accessible to all devices on my LAN, plus a private share for my user only."

## Quick Start (5 minutes)

### 1. Install Samba

```bash
bash scripts/samba-manager.sh install
```

This installs Samba, enables the service, and creates a default config backup.

### 2. Create a Public Share

```bash
bash scripts/samba-manager.sh create-share \
  --name "shared" \
  --path "/srv/shared" \
  --public yes \
  --writable yes
```

Access from any device: `\\<your-ip>\shared` (Windows) or `smb://<your-ip>/shared` (Mac/Linux).

### 3. Create a Private Share

```bash
# First, add a Samba user
bash scripts/samba-manager.sh add-user --username myuser

# Then create a private share
bash scripts/samba-manager.sh create-share \
  --name "private" \
  --path "/home/myuser/samba-private" \
  --public no \
  --writable yes \
  --valid-users "myuser"
```

## Core Workflows

### Workflow 1: List All Shares

```bash
bash scripts/samba-manager.sh list-shares
```

**Output:**
```
Active Samba Shares:
  [shared]
    path = /srv/shared
    public = yes
    writable = yes
  [private]
    path = /home/myuser/samba-private
    public = no
    valid users = myuser
```

### Workflow 2: Manage Users

```bash
# Add a Samba user (must already be a Linux user)
bash scripts/samba-manager.sh add-user --username alice

# Remove a Samba user
bash scripts/samba-manager.sh remove-user --username alice

# List Samba users
bash scripts/samba-manager.sh list-users
```

### Workflow 3: Remove a Share

```bash
bash scripts/samba-manager.sh remove-share --name "shared"
```

### Workflow 4: Check Status

```bash
bash scripts/samba-manager.sh status
```

**Output:**
```
Samba Service: active (running)
Active connections: 2
Shares configured: 3
Firewall: ports 139,445 open
```

### Workflow 5: Test Configuration

```bash
bash scripts/samba-manager.sh test-config
```

Runs `testparm` to validate smb.conf syntax.

### Workflow 6: Restart Samba

```bash
bash scripts/samba-manager.sh restart
```

## Configuration

### Default Config Location

Samba config: `/etc/samba/smb.conf`
Backup before changes: `/etc/samba/smb.conf.bak.<timestamp>`

### Firewall

The install command automatically opens ports 139 and 445 via `ufw` (if available). For manual firewall config:

```bash
sudo ufw allow 139/tcp
sudo ufw allow 445/tcp
sudo ufw allow 137/udp
sudo ufw allow 138/udp
```

### Share Options

| Option | Values | Description |
|--------|--------|-------------|
| `--public` | yes/no | Allow anonymous access |
| `--writable` | yes/no | Allow write access |
| `--valid-users` | "user1 user2" | Restrict to specific users |
| `--read-only` | yes/no | Force read-only |
| `--browseable` | yes/no | Show in network discovery |
| `--create-mask` | 0664 | Default file permissions |
| `--directory-mask` | 0775 | Default directory permissions |

## Advanced Usage

### Time Machine Backup Share (macOS)

```bash
bash scripts/samba-manager.sh create-share \
  --name "timemachine" \
  --path "/srv/timemachine" \
  --public no \
  --valid-users "macuser" \
  --vfs-objects "catia fruit streams_xattr" \
  --fruit-time-machine yes
```

### Guest-Only Media Share

```bash
bash scripts/samba-manager.sh create-share \
  --name "media" \
  --path "/srv/media" \
  --public yes \
  --writable no \
  --browseable yes
```

### Multi-User Department Share

```bash
bash scripts/samba-manager.sh create-share \
  --name "projects" \
  --path "/srv/projects" \
  --public no \
  --writable yes \
  --valid-users "@staff" \
  --create-mask "0664" \
  --directory-mask "0775"
```

## Troubleshooting

### Issue: "Access denied" when connecting

**Fix:**
1. Ensure the user has a Samba password: `bash scripts/samba-manager.sh add-user --username <user>`
2. Check share permissions: `ls -la /path/to/share`
3. Verify config: `bash scripts/samba-manager.sh test-config`

### Issue: Share not visible on network

**Fix:**
1. Check Samba is running: `bash scripts/samba-manager.sh status`
2. Check firewall: `sudo ufw status`
3. Ensure `browseable = yes` in share config
4. Try direct access: `\\<ip>\<sharename>`

### Issue: Can't write to share

**Fix:**
1. Check Linux permissions: `chmod -R 775 /path/to/share`
2. Check `writable = yes` in share config
3. Check SELinux (if enabled): `sudo setsebool -P samba_export_all_rw on`

### Issue: Slow transfers

**Fix:** Add to `[global]` section of smb.conf:
```ini
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
min receivefile size = 16384
use sendfile = true
aio read size = 16384
aio write size = 16384
```

## Dependencies

- `samba` (installed by the skill)
- `bash` (4.0+)
- Root/sudo access (for installation and config)
- Optional: `ufw` (firewall management)
