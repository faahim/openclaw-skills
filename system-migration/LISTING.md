# Listing Copy: System Migration Tool

## Metadata
- **Type:** Skill
- **Name:** system-migration
- **Display Name:** System Migration Tool
- **Categories:** [automation, dev-tools]
- **Price:** $15
- **Dependencies:** [bash, tar, systemctl]
- **Icon:** 📦

## Tagline

"Export & import full system config — migrate servers in minutes, not hours"

## Description

Setting up a new server means hours of remembering what packages you installed, which services you enabled, what cron jobs you set up, and where your config files live. Miss one thing and you're debugging at 2am.

System Migration Tool captures your entire server configuration — packages, services, crontabs, users, network settings, firewall rules, dotfiles, and sysctl tunables — into a single portable bundle. Transfer it to a new machine and restore everything with one command.

**What it does:**
- 📦 Export full system state to a compressed bundle
- 🔄 Import on a new machine with dry-run preview
- 📊 Diff two systems to see what's different
- 🎯 Selective export/import (only packages, only services, etc.)
- 🐳 Optional Docker container & compose file capture
- 🔒 SSH keys and firewall rules included

**Who it's for:** Developers, sysadmins, and anyone who's ever had to rebuild a server from scratch.

## Quick Start Preview

```bash
# Export your system
sudo bash scripts/export.sh --output /tmp/migration

# Preview what would change on new server
sudo bash scripts/import.sh --bundle /tmp/migration.tar.gz --dry-run

# Apply
sudo bash scripts/import.sh --bundle /tmp/migration.tar.gz
```

## Core Capabilities

1. Package list export — apt, yum, dnf, pacman (manual vs auto-installed)
2. Service state capture — enabled systemd services + timers
3. Crontab backup — per-user + system crontabs + cron.d
4. Network config — netplan, interfaces, DNS, hosts
5. User accounts — UID-preserving, groups, SSH authorized_keys
6. Dotfiles — .bashrc, .gitconfig, .ssh/config, .vimrc, and more
7. Sysctl tunables — kernel parameters + sysctl.d configs
8. Firewall rules — UFW, iptables, nftables
9. Docker state — containers, images, compose file locations
10. Dry-run mode — preview all changes before applying
11. System diff — compare current state against any bundle
12. Selective components — include/exclude specific parts
