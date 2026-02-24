# Listing Copy: Samba File Share Manager

## Metadata
- **Type:** Skill
- **Name:** samba-file-share
- **Display Name:** Samba File Share Manager
- **Categories:** [home, automation]
- **Icon:** 📂
- **Dependencies:** [samba, bash]

## Tagline

"Set up and manage Samba file shares — share folders across your entire network"

## Description

Sharing files between devices on your local network shouldn't require cloud services or USB drives. But setting up Samba manually means editing obscure config files, managing permissions, and debugging "access denied" errors for hours.

Samba File Share Manager handles the entire lifecycle: install Samba, create public or private shares, manage users and passwords, configure macOS Time Machine backups, and troubleshoot common issues — all through simple commands your OpenClaw agent can execute.

**What it does:**
- 📂 Create public and private SMB shares with one command
- 👤 Manage Samba users and passwords
- 🍎 Configure macOS Time Machine backup shares
- 🔒 Set granular permissions (user-level, group-level)
- 🔥 Auto-configure firewall rules
- 🔍 Test and validate Samba configuration
- 📊 Monitor active connections and share status
- 💾 Auto-backup config before changes

Perfect for homelabbers, small office setups, and anyone who wants their devices to share files seamlessly without cloud dependencies.

## Quick Start Preview

```bash
# Install Samba
bash scripts/samba-manager.sh install

# Create a shared folder accessible to all devices
bash scripts/samba-manager.sh create-share --name "shared" --path "/srv/shared" --public yes

# Access from any device: \\192.168.1.x\shared
```

## Core Capabilities

1. One-command Samba installation — handles apt, dnf, yum, pacman, apk
2. Public shares — anonymous access for media, downloads, etc.
3. Private shares — user-authenticated access with Samba passwords
4. Time Machine support — macOS backup to network share via VFS
5. User management — add, remove, list Samba users
6. Firewall integration — auto-opens ports 139, 445 via ufw
7. Config validation — testparm integration catches syntax errors
8. Connection monitoring — see who's connected to your shares
9. Auto-backup — saves smb.conf before every change
10. Multi-distro — works on Ubuntu, Debian, Fedora, Arch, Alpine
