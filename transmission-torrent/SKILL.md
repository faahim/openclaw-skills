---
name: transmission-torrent
description: >-
  Install, configure, and manage Transmission torrent daemon — add/remove torrents, monitor progress, set speed limits, organize downloads.
categories: [media, automation]
dependencies: [transmission-daemon, transmission-cli, curl, jq]
---

# Transmission Torrent Manager

## What This Does

Installs and configures Transmission BitTorrent daemon, then provides full CLI management: add torrents (URL or magnet), monitor download progress, set speed limits, pause/resume, and auto-organize completed downloads into folders. Runs headless — perfect for servers and remote machines.

**Example:** "Add a Linux ISO torrent, limit to 5MB/s download, auto-move completed files to ~/Downloads/completed."

## Quick Start (5 minutes)

### 1. Install Transmission

```bash
bash scripts/install.sh
```

This installs `transmission-daemon` and `transmission-cli`, creates a config at `~/.config/transmission-daemon/settings.json`, and starts the daemon.

### 2. Add Your First Torrent

```bash
# Add by magnet link
bash scripts/run.sh add "magnet:?xt=urn:btih:..."

# Add by .torrent URL
bash scripts/run.sh add "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso.torrent"

# Add a local .torrent file
bash scripts/run.sh add /path/to/file.torrent
```

### 3. Check Status

```bash
bash scripts/run.sh status

# Output:
# ID  Done  ETA   Status       Name
#  1  45%   12m   Downloading  ubuntu-24.04-desktop-amd64.iso
#  2  100%  Done  Seeding      archlinux-2024.03.01-x86_64.iso
```

## Core Workflows

### Workflow 1: Add & Monitor Torrent

```bash
# Add torrent
bash scripts/run.sh add "magnet:?xt=urn:btih:EXAMPLE"

# Watch progress (updates every 5s)
bash scripts/run.sh watch 1

# Output:
# [12:00:05] ubuntu-24.04.iso — 45.2% ↓ 4.8MB/s ↑ 1.2MB/s ETA: 12m
# [12:00:10] ubuntu-24.04.iso — 46.1% ↓ 5.1MB/s ↑ 1.3MB/s ETA: 11m
```

### Workflow 2: Set Speed Limits

```bash
# Set global download limit (KB/s)
bash scripts/run.sh speed-limit down 5000

# Set global upload limit
bash scripts/run.sh speed-limit up 2000

# Enable alt-speed (turtle mode) — e.g., for daytime
bash scripts/run.sh alt-speed on

# Disable alt-speed
bash scripts/run.sh alt-speed off

# Show current limits
bash scripts/run.sh speed-limit show
```

### Workflow 3: Manage Downloads

```bash
# Pause a torrent
bash scripts/run.sh pause 1

# Resume a torrent
bash scripts/run.sh resume 1

# Pause all
bash scripts/run.sh pause-all

# Resume all
bash scripts/run.sh resume-all

# Remove torrent (keep files)
bash scripts/run.sh remove 1

# Remove torrent AND files
bash scripts/run.sh remove 1 --delete
```

### Workflow 4: Auto-Organize Completed Downloads

```bash
# Set completion directory
bash scripts/run.sh config set done-dir ~/Downloads/completed

# Enable auto-move on completion
bash scripts/run.sh config set move-completed true

# Set incomplete directory
bash scripts/run.sh config set incomplete-dir ~/Downloads/incomplete
```

### Workflow 5: Bulk Operations

```bash
# List all torrents
bash scripts/run.sh list

# List only downloading
bash scripts/run.sh list --filter downloading

# List only seeding
bash scripts/run.sh list --filter seeding

# List only paused
bash scripts/run.sh list --filter paused

# Remove all completed+seeding torrents (keep files)
bash scripts/run.sh clean
```

## Configuration

### Key Settings

```bash
# View current config
bash scripts/run.sh config show

# RPC port (default 9091)
bash scripts/run.sh config set rpc-port 9091

# RPC authentication
bash scripts/run.sh config set rpc-username admin
bash scripts/run.sh config set rpc-password secretpass

# Peer port (default 51413)
bash scripts/run.sh config set peer-port 51413

# Max connected peers
bash scripts/run.sh config set peer-limit-global 200
bash scripts/run.sh config set peer-limit-per-torrent 50

# Encryption (required/preferred/tolerated)
bash scripts/run.sh config set encryption required

# DHT and PEX
bash scripts/run.sh config set dht true
bash scripts/run.sh config set pex true
```

### Environment Variables

```bash
# Override RPC connection (defaults to localhost:9091)
export TRANSMISSION_HOST="localhost"
export TRANSMISSION_PORT="9091"
export TRANSMISSION_USER="admin"
export TRANSMISSION_PASS="secretpass"
```

## Advanced Usage

### Remote Management

```bash
# Connect to remote Transmission daemon
TRANSMISSION_HOST=192.168.1.100 bash scripts/run.sh status

# Or set in config
bash scripts/run.sh config set rpc-host 192.168.1.100
```

### Scheduled Speed Limits

```bash
# Enable alt-speed schedule (slow during work hours)
bash scripts/run.sh config set alt-speed-time-enabled true
bash scripts/run.sh config set alt-speed-time-begin 540   # 9:00 AM (minutes from midnight)
bash scripts/run.sh config set alt-speed-time-end 1020    # 5:00 PM
bash scripts/run.sh config set alt-speed-down 1000        # 1MB/s during schedule
bash scripts/run.sh config set alt-speed-up 500           # 0.5MB/s during schedule
```

### Blocklist

```bash
# Enable IP blocklist
bash scripts/run.sh config set blocklist-enabled true
bash scripts/run.sh config set blocklist-url "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz"

# Update blocklist
bash scripts/run.sh blocklist-update
```

### Run as Cron (Cleanup Old Torrents)

```bash
# Remove torrents that finished seeding 7+ days ago
# Add to crontab: daily at midnight
0 0 * * * bash /path/to/scripts/run.sh auto-clean --days 7 >> /var/log/transmission-cleanup.log 2>&1
```

## Troubleshooting

### Issue: "Couldn't connect to daemon"

**Fix:**
```bash
# Check if daemon is running
systemctl status transmission-daemon 2>/dev/null || ps aux | grep transmission

# Start daemon
bash scripts/install.sh start

# Or manually
transmission-daemon --foreground --log-level=info
```

### Issue: "Permission denied on download directory"

**Fix:**
```bash
# Ensure download dir exists and is writable
mkdir -p ~/Downloads/torrents
chmod 755 ~/Downloads/torrents

# If running as service, check user
sudo chown -R $USER:$USER ~/Downloads/torrents
```

### Issue: Slow speeds / No peers

**Fix:**
```bash
# Check port forwarding
bash scripts/run.sh config show | grep peer-port

# Test port (should be open)
bash scripts/run.sh port-test

# Enable DHT and PEX for better peer discovery
bash scripts/run.sh config set dht true
bash scripts/run.sh config set pex true
```

### Issue: "RPC authentication failed"

**Fix:**
```bash
# Stop daemon first (it overwrites config on exit)
bash scripts/install.sh stop

# Edit config
nano ~/.config/transmission-daemon/settings.json
# Set "rpc-authentication-required": false  (or fix credentials)

# Restart
bash scripts/install.sh start
```

## Dependencies

- `transmission-daemon` (BitTorrent daemon)
- `transmission-cli` or `transmission-remote` (CLI client)
- `curl` (for RPC API calls)
- `jq` (for JSON parsing)
- Optional: `systemd` (for service management)
