---
name: nfs-server
description: >-
  Set up and manage NFS file shares on Linux — export directories, manage client access, monitor connections.
categories: [home, automation]
dependencies: [nfs-kernel-server, exportfs, showmount]
---

# NFS Server Manager

## What This Does

Set up and manage Network File System (NFS) shares on Linux servers. Export directories to other machines on your network, control client access with IP-based rules, and monitor active connections. No more manually editing `/etc/exports` and forgetting to reload.

**Example:** "Share `/data/media` with my homelab network, read-only for most clients, read-write for my NAS."

## Quick Start (5 minutes)

### 1. Install NFS Server

```bash
bash scripts/install.sh
```

This installs `nfs-kernel-server` (Debian/Ubuntu) or `nfs-utils` (RHEL/Fedora/Arch), enables the service, and opens firewall ports.

### 2. Create Your First Share

```bash
bash scripts/nfs-manage.sh add \
  --path /srv/shared \
  --clients "192.168.1.0/24" \
  --options "rw,sync,no_subtree_check"
```

Output:
```
✅ Created directory /srv/shared
✅ Added export: /srv/shared 192.168.1.0/24(rw,sync,no_subtree_check)
✅ Exports reloaded
```

### 3. Verify It Works

```bash
bash scripts/nfs-manage.sh status
```

Output:
```
NFS Server Status
═════════════════
Service: ● active (running)
Exports: 1 active

/srv/shared
  → 192.168.1.0/24 (rw,sync,no_subtree_check)

Connected Clients: 0
```

## Core Workflows

### Workflow 1: Add a Share

```bash
# Read-write share for specific subnet
bash scripts/nfs-manage.sh add \
  --path /data/projects \
  --clients "192.168.1.0/24" \
  --options "rw,sync,no_subtree_check,no_root_squash"

# Read-only share for everyone
bash scripts/nfs-manage.sh add \
  --path /data/public \
  --clients "*" \
  --options "ro,sync,no_subtree_check"

# Multiple client rules for one path
bash scripts/nfs-manage.sh add \
  --path /data/media \
  --clients "192.168.1.10" \
  --options "rw,sync,no_subtree_check"

bash scripts/nfs-manage.sh add \
  --path /data/media \
  --clients "192.168.1.0/24" \
  --options "ro,sync,no_subtree_check"
```

### Workflow 2: List All Shares

```bash
bash scripts/nfs-manage.sh list
```

Output:
```
Active NFS Exports
══════════════════
/data/projects   → 192.168.1.0/24 (rw,sync,no_subtree_check,no_root_squash)
/data/public     → * (ro,sync,no_subtree_check)
/data/media      → 192.168.1.10 (rw,sync,no_subtree_check)
                   192.168.1.0/24 (ro,sync,no_subtree_check)
```

### Workflow 3: Remove a Share

```bash
# Remove specific client rule
bash scripts/nfs-manage.sh remove --path /data/projects --clients "192.168.1.0/24"

# Remove all rules for a path
bash scripts/nfs-manage.sh remove --path /data/projects --all
```

### Workflow 4: Check Connected Clients

```bash
bash scripts/nfs-manage.sh clients
```

Output:
```
Connected NFS Clients
═════════════════════
192.168.1.10  → /data/media (mounted)
192.168.1.15  → /data/public (mounted)
```

### Workflow 5: Full Status Report

```bash
bash scripts/nfs-manage.sh status
```

Shows service health, all exports, connected clients, and any errors.

### Workflow 6: Generate Client Mount Command

```bash
bash scripts/nfs-manage.sh mount-cmd --path /data/media --client-ip 192.168.1.50
```

Output:
```
Mount command for client 192.168.1.50:

  sudo mount -t nfs <server-ip>:/data/media /mnt/media

To persist across reboots, add to /etc/fstab:

  <server-ip>:/data/media /mnt/media nfs defaults,_netdev 0 0
```

## Configuration

### Common Export Options

| Option | Description |
|--------|-------------|
| `rw` | Read-write access |
| `ro` | Read-only access |
| `sync` | Write data to disk before replying (safer) |
| `async` | Reply before data is written (faster, risk of corruption) |
| `no_subtree_check` | Disable subtree checking (recommended) |
| `no_root_squash` | Allow root access from clients (use carefully) |
| `root_squash` | Map client root to `nobody` (default, safer) |
| `all_squash` | Map all users to `nobody` |
| `anonuid=N` | Set anonymous user ID |
| `anongid=N` | Set anonymous group ID |

### Security Notes

- **Default:** `root_squash` is on — client root becomes `nobody` on server
- **`no_root_squash`:** Only use for trusted clients (e.g., your NAS doing backups)
- **IP restrictions:** Always use subnet masks (e.g., `192.168.1.0/24`) instead of `*`
- **Firewall:** Script auto-configures UFW/firewalld, but verify with `bash scripts/nfs-manage.sh firewall-check`

## Advanced Usage

### Backup Exports Config

```bash
bash scripts/nfs-manage.sh backup
# → Saved to /etc/exports.backup.2026-03-04
```

### Restore Exports Config

```bash
bash scripts/nfs-manage.sh restore --file /etc/exports.backup.2026-03-04
```

### Monitor NFS Performance

```bash
bash scripts/nfs-manage.sh stats
```

Output:
```
NFS Server Statistics
═════════════════════
Total RPCs: 15,432
  Read:     8,201 (53%)
  Write:    4,890 (32%)
  Other:    2,341 (15%)

Cache hits: 89%
Average response: 1.2ms
```

## Troubleshooting

### Issue: "mount.nfs: access denied by server"

**Fix:**
1. Check exports match client IP: `bash scripts/nfs-manage.sh list`
2. Verify firewall: `bash scripts/nfs-manage.sh firewall-check`
3. Reload exports: `sudo exportfs -ra`

### Issue: "mount.nfs: Connection timed out"

**Fix:**
1. Check NFS service: `systemctl status nfs-server`
2. Check firewall ports (2049/tcp, 111/tcp): `bash scripts/nfs-manage.sh firewall-check`
3. Test connectivity: `showmount -e <server-ip>`

### Issue: Permission denied on mounted share

**Fix:**
1. Check directory permissions on server: `ls -la /path/to/share`
2. Check if `root_squash` is mapping your user to `nobody`
3. Set `all_squash,anonuid=1000,anongid=1000` to map to specific user

### Issue: NFS server not starting

**Fix:**
```bash
# Check for config errors
sudo exportfs -ra 2>&1

# Check logs
journalctl -u nfs-server --no-pager -n 20
```

## Dependencies

- `nfs-kernel-server` (Debian/Ubuntu) or `nfs-utils` (RHEL/Fedora/Arch)
- `exportfs` (included with NFS packages)
- `showmount` (included with NFS packages)
- `ufw` or `firewalld` (for firewall management, optional)
- Root/sudo access required
