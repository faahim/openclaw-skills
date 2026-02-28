# Listing Copy: SSHFS Remote Mount Manager

## Metadata
- **Type:** Skill
- **Name:** sshfs-mount-manager
- **Display Name:** SSHFS Remote Mount Manager
- **Categories:** [automation, data]
- **Price:** $10
- **Dependencies:** [sshfs, fuse, ssh, bash]

## Tagline

Mount remote servers as local folders — edit remote files instantly over SSH

## Description

Manually copying files between servers is tedious. SCP works but breaks your workflow. FTP is insecure and clunky. You need remote files accessible as if they were local.

SSHFS Remote Mount Manager lets your OpenClaw agent mount any remote directory as a local folder over SSH. Browse remote files in your editor, make changes that sync instantly, and manage multiple server connections with saved profiles.

**What it does:**
- 🔗 Mount remote directories as local folders over SSH
- 📁 Save named profiles for quick reconnection
- 🔄 Auto-reconnect on connection drops
- 🏥 Health checks with automatic remounting
- 🚀 Auto-mount on boot via systemd
- 📊 Status dashboard showing all active mounts with latency
- 🔒 SSH key authentication support
- ⚡ Compression mode for slow networks

Perfect for developers who work with remote servers, sysadmins managing multiple boxes, or anyone who needs seamless access to remote files without complex sync setups.

## Quick Start Preview

```bash
# Install sshfs
bash scripts/install.sh

# Mount remote directory
bash scripts/sshfs-manager.sh mount --host user@server --remote /var/www --local ~/remote/web

# Check health
bash scripts/sshfs-manager.sh health
# ✅ user@server: /var/www → ~/remote/web (healthy, 23ms)
```

## Core Capabilities

1. Quick mount — Mount any remote directory with a single command
2. Profile management — Save, list, and reuse mount configurations
3. Auto-reconnect — SSHFS reconnects automatically on network drops
4. Health monitoring — Check mount status and latency, auto-fix broken mounts
5. Boot persistence — Auto-mount profiles on system startup via systemd
6. Multi-server — Manage mounts across multiple servers simultaneously
7. SSH key auth — Use identity files for passwordless mounting
8. Compression — Enable compression for slow/metered connections
9. Cron-ready — Schedule health checks to keep mounts alive
10. Cross-platform — Works on Ubuntu, Debian, Fedora, Arch, Alpine, macOS

## Dependencies
- `sshfs` (installed by included script)
- `fuse` / `fuse3`
- `ssh` (OpenSSH client)
- `bash` (4.0+)

## Installation Time
**5 minutes** — Run install script, start mounting

## Pricing Justification

**Why $10:**
- Replaces manual SCP/SFTP workflows
- Saves 10+ min/day for remote development
- Similar tools (Mountain Duck, ExpanDrive) cost $39-49 one-time
- Self-hosted, no subscription, no external services
