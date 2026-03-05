---
name: nfs-manager
description: >-
  Set up, manage, and monitor NFS shares on Linux. Create exports, mount remote shares, manage permissions, and monitor NFS health.
categories: [home, automation]
dependencies: [nfs-kernel-server, nfs-common, bash]
---

# NFS Manager

## What This Does

Automates NFS (Network File System) server and client setup on Linux. Create shared directories accessible across your network, mount remote NFS shares, manage export permissions, and monitor NFS service health.

**Example:** "Share /data/media across your homelab, mount it on 3 machines, monitor NFS health — all from your agent."

## Quick Start (5 minutes)

### 1. Install NFS

```bash
# Server (the machine sharing files)
bash scripts/nfs-manager.sh install-server

# Client (machines accessing shared files)
bash scripts/nfs-manager.sh install-client
```

### 2. Create Your First Share

```bash
# Share a directory with your local network
bash scripts/nfs-manager.sh export /data/shared 192.168.1.0/24

# Output:
# ✅ Created export: /data/shared → 192.168.1.0/24 (rw,sync,no_subtree_check)
# ✅ NFS exports reloaded
```

### 3. Mount a Remote Share

```bash
# On a client machine, mount the remote share
bash scripts/nfs-manager.sh mount 192.168.1.10:/data/shared /mnt/shared

# Output:
# ✅ Mounted 192.168.1.10:/data/shared → /mnt/shared
# ✅ Added to /etc/fstab for persistence
```

## Core Workflows

### Workflow 1: Set Up NFS Server

**Use case:** Share directories from a central server

```bash
# Install NFS server
bash scripts/nfs-manager.sh install-server

# Create multiple exports
bash scripts/nfs-manager.sh export /data/media 192.168.1.0/24
bash scripts/nfs-manager.sh export /data/backups 192.168.1.0/24 ro
bash scripts/nfs-manager.sh export /data/projects 192.168.1.50

# List current exports
bash scripts/nfs-manager.sh list-exports
```

**Output:**
```
NFS Exports:
  /data/media      → 192.168.1.0/24 (rw,sync,no_subtree_check)
  /data/backups    → 192.168.1.0/24 (ro,sync,no_subtree_check)
  /data/projects   → 192.168.1.50   (rw,sync,no_subtree_check)
```

### Workflow 2: Mount Remote Shares on Client

**Use case:** Access shared directories from another machine

```bash
# Mount with persistence (survives reboot)
bash scripts/nfs-manager.sh mount 192.168.1.10:/data/media /mnt/media
bash scripts/nfs-manager.sh mount 192.168.1.10:/data/backups /mnt/backups

# List mounted NFS shares
bash scripts/nfs-manager.sh list-mounts

# Unmount
bash scripts/nfs-manager.sh unmount /mnt/media
```

### Workflow 3: Monitor NFS Health

**Use case:** Check if NFS server/exports are healthy

```bash
# Full health check
bash scripts/nfs-manager.sh health

# Output:
# NFS Health Report
# ─────────────────
# Service:    ✅ nfs-server active
# RPC:        ✅ rpcbind active
# Exports:    3 active exports
# Clients:    2 connected clients
# Uptime:     14d 3h 22m
```

### Workflow 4: Remove Export or Unmount

```bash
# Remove an export from the server
bash scripts/nfs-manager.sh unexport /data/projects

# Unmount on client (also removes from fstab)
bash scripts/nfs-manager.sh unmount /mnt/media --permanent
```

### Workflow 5: NFS Performance Stats

```bash
# Show NFS I/O statistics
bash scripts/nfs-manager.sh stats

# Output:
# NFS Server Statistics
# ─────────────────────
# Read:   1.2 GB (12,453 ops)
# Write:  890 MB (8,921 ops)
# Active: 2 clients
```

## Configuration

### Export Options

```bash
# Read-write (default)
bash scripts/nfs-manager.sh export /path 192.168.1.0/24

# Read-only
bash scripts/nfs-manager.sh export /path 192.168.1.0/24 ro

# Custom options
bash scripts/nfs-manager.sh export /path 192.168.1.0/24 "rw,sync,no_root_squash"
```

### Firewall Setup

```bash
# Auto-configure UFW firewall rules for NFS
bash scripts/nfs-manager.sh firewall-setup 192.168.1.0/24

# Output:
# ✅ Allowed NFS (2049/tcp) from 192.168.1.0/24
# ✅ Allowed mountd (20048/tcp) from 192.168.1.0/24
# ✅ Allowed rpcbind (111/tcp) from 192.168.1.0/24
```

### Mount Options

```bash
# Mount with custom options
bash scripts/nfs-manager.sh mount 192.168.1.10:/data/media /mnt/media "rw,hard,timeo=600,retrans=2"

# Mount without fstab persistence
bash scripts/nfs-manager.sh mount 192.168.1.10:/data/media /mnt/media --no-persist
```

## Troubleshooting

### Issue: "mount.nfs: Connection timed out"

**Fix:**
```bash
# Check if NFS server is reachable
bash scripts/nfs-manager.sh diagnose 192.168.1.10

# Common causes:
# 1. Firewall blocking NFS ports → run firewall-setup
# 2. NFS server not running → run install-server
# 3. Wrong network in exports → check list-exports
```

### Issue: "Permission denied" on mounted share

**Fix:**
```bash
# Check export permissions
bash scripts/nfs-manager.sh list-exports

# If root access needed, re-export with no_root_squash:
bash scripts/nfs-manager.sh unexport /data/shared
bash scripts/nfs-manager.sh export /data/shared 192.168.1.0/24 "rw,sync,no_root_squash"
```

### Issue: NFS mount not surviving reboot

**Fix:**
```bash
# Verify fstab entry
grep nfs /etc/fstab

# Re-mount with persistence
bash scripts/nfs-manager.sh unmount /mnt/media
bash scripts/nfs-manager.sh mount 192.168.1.10:/data/media /mnt/media
```

## Dependencies

- `nfs-kernel-server` (server) or `nfs-common` (client)
- `bash` (4.0+)
- `rpcbind`
- Optional: `ufw` (firewall management)
- Optional: `nfsstat` (performance stats, included with nfs-common)
