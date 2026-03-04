# Listing Copy: NFS Server Manager

## Metadata
- **Type:** Skill
- **Name:** nfs-server
- **Display Name:** NFS Server Manager
- **Categories:** [home, automation]
- **Icon:** 📂
- **Price:** $8
- **Dependencies:** [nfs-kernel-server, exportfs, showmount]

## Tagline

Set up and manage NFS file shares — export directories, control access, monitor connections

## Description

Sharing files between machines on your network shouldn't require memorizing `/etc/exports` syntax or debugging firewall rules. Every time you edit that file, you wonder if you got the parentheses right.

NFS Server Manager handles the entire lifecycle: install the NFS server, create exports with proper permissions, manage client access rules, and monitor who's connected. One command to add a share, one command to check status. It works on Debian, Ubuntu, RHEL, Fedora, and Arch.

**What it does:**
- 📂 Add/remove NFS exports with proper syntax
- 🔒 IP-based client access control (subnets, individual IPs, wildcards)
- 🔥 Auto-configure UFW or firewalld rules
- 📊 Monitor connected clients and NFS statistics
- 💾 Backup and restore exports configuration
- 🔧 Generate mount commands for client machines
- 🏥 Diagnose firewall and connectivity issues

**Who it's for:** Homelab enthusiasts, sysadmins, anyone sharing files between Linux machines on a local network.

## Quick Start Preview

```bash
# Install NFS server
bash scripts/install.sh

# Share a directory
bash scripts/nfs-manage.sh add --path /srv/media --clients "192.168.1.0/24" --options "rw,sync,no_subtree_check"

# Check status
bash scripts/nfs-manage.sh status
```

## Core Capabilities

1. One-command NFS server installation (Debian/Ubuntu/RHEL/Fedora/Arch)
2. Add exports with proper syntax — no manual /etc/exports editing
3. Remove shares by path, client, or all at once
4. IP/subnet-based access control with common option presets
5. Automatic firewall configuration (UFW + firewalld)
6. Connected client monitoring via showmount
7. NFS performance statistics from /proc
8. Backup and restore exports configuration
9. Generate client-side mount commands and fstab entries
10. Firewall diagnostics — verify ports are open

## Dependencies
- `nfs-kernel-server` (Debian/Ubuntu) or `nfs-utils` (RHEL/Fedora/Arch)
- `bash` (4.0+)
- Root/sudo access

## Installation Time
**5 minutes** — run install script, create first share
