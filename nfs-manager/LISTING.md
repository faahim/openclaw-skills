# Listing Copy: NFS Manager

## Metadata
- **Type:** Skill
- **Name:** nfs-manager
- **Display Name:** NFS Manager
- **Categories:** [home, automation]
- **Icon:** 📁
- **Price:** $8
- **Dependencies:** [nfs-kernel-server, nfs-common, bash]

## Tagline

Set up and manage NFS file shares — Share directories across your network in minutes

## Description

Sharing files across machines on your local network shouldn't require reading 10 wiki pages and debugging cryptic mount errors. NFS (Network File System) is the gold standard for Linux file sharing, but setting it up correctly — exports, permissions, firewall rules, fstab entries — is tedious and error-prone.

NFS Manager handles the entire lifecycle: install the server or client, create exports with proper permissions, mount remote shares with persistence across reboots, configure firewall rules, and monitor NFS health. One script, all the commands you need.

**What it does:**
- 🖥️ Install NFS server or client (apt, dnf, yum, pacman)
- 📂 Create and manage exports with custom permissions
- 🔗 Mount remote shares with automatic fstab persistence
- 🔥 Configure UFW/firewalld/iptables firewall rules
- 🩺 Health checks — service status, ports, active exports
- 🔍 Diagnose connectivity issues (ping, RPC, port checks, showmount)
- 📊 View NFS I/O statistics

Perfect for homelab enthusiasts, sysadmins, and anyone sharing files across Linux machines on a local network.

## Quick Start Preview

```bash
# Install NFS server
sudo bash scripts/nfs-manager.sh install-server

# Share a directory
sudo bash scripts/nfs-manager.sh export /data/shared 192.168.1.0/24

# On client: mount it
sudo bash scripts/nfs-manager.sh mount 192.168.1.10:/data/shared /mnt/shared
```

## Core Capabilities

1. Server installation — One-command install across major Linux distros
2. Export management — Create, update, remove NFS exports with custom options
3. Client mounting — Mount remote shares with fstab persistence
4. Firewall configuration — Auto-configure UFW, firewalld, or iptables
5. Health monitoring — Check NFS service, RPC, ports, active exports
6. Connectivity diagnosis — Full diagnostic for troubleshooting mount failures
7. I/O statistics — View NFS read/write operations and performance
8. Multi-distro — Works on Ubuntu, Debian, Fedora, CentOS, Arch
9. Persistent mounts — Automatic fstab management for reboot survival
10. Clean removal — Unexport and unmount with full cleanup
