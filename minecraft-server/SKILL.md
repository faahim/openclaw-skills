---
name: minecraft-server
description: >-
  Install, configure, and manage a Minecraft Java Edition server with automated backups, whitelist management, and monitoring.
categories: [fun, automation]
dependencies: [java, screen, curl, jq]
---

# Minecraft Server Manager

## What This Does

Automates the full lifecycle of a Minecraft Java Edition server: download, install, configure, run, backup, monitor, and manage players. No manual JAR downloads, no editing config files by hand — just run the scripts.

**Example:** "Set up a Minecraft server on port 25565, auto-backup every 6 hours, whitelist 5 friends, monitor TPS and player count."

## Quick Start (10 minutes)

### 1. Install Dependencies

```bash
# Java 21+ (required for modern Minecraft)
which java || {
  # Ubuntu/Debian
  sudo apt-get update && sudo apt-get install -y openjdk-21-jre-headless screen curl jq
  # OR Amazon Linux / RHEL
  # sudo yum install -y java-21-amazon-corretto-headless screen curl jq
}

java -version  # Should show 21+
```

### 2. Install & Start Server

```bash
# Set server directory
export MC_DIR="$HOME/minecraft-server"

# Run installer — downloads latest server JAR, accepts EULA, configures
bash scripts/install.sh

# Start the server (runs in screen session)
bash scripts/start.sh
```

### 3. Connect

Open Minecraft Java Edition → Multiplayer → Add Server:
- **Address:** `your-server-ip:25565`
- **Name:** Whatever you want

## Core Workflows

### Workflow 1: Install Fresh Server

```bash
# Install latest version (auto-detects latest release)
bash scripts/install.sh

# OR install specific version
bash scripts/install.sh --version 1.21.4

# Output:
# ✅ Downloaded server.jar (1.21.4)
# ✅ EULA accepted
# ✅ server.properties configured
# ✅ Ready to start!
```

### Workflow 2: Start / Stop / Restart

```bash
# Start (runs in detached screen session "minecraft")
bash scripts/start.sh

# Stop gracefully (saves world, warns players)
bash scripts/stop.sh

# Restart (stop + start)
bash scripts/restart.sh

# Check if running
bash scripts/status.sh
# Output:
# ✅ Server RUNNING (PID 12345)
# 📊 Players: 3/20
# 🕐 Uptime: 4h 23m
# 💾 World size: 1.2 GB
```

### Workflow 3: Automated Backups

```bash
# Manual backup
bash scripts/backup.sh
# Output: ✅ Backup saved to backups/2026-02-26_01-53.tar.gz (245 MB)

# List backups
bash scripts/backup.sh --list
# Output:
# 2026-02-26_01-53.tar.gz  245 MB
# 2026-02-25_19-53.tar.gz  243 MB
# 2026-02-25_13-53.tar.gz  241 MB

# Restore from backup
bash scripts/backup.sh --restore 2026-02-25_19-53.tar.gz

# Set up auto-backup (every 6 hours via cron)
bash scripts/backup.sh --schedule 6h
# Output: ✅ Cron job added: backup every 6 hours
```

### Workflow 4: Player Management

```bash
# Add player to whitelist
bash scripts/players.sh --whitelist add PlayerName

# Remove from whitelist
bash scripts/players.sh --whitelist remove PlayerName

# List whitelisted players
bash scripts/players.sh --whitelist list

# Op a player (give admin)
bash scripts/players.sh --op PlayerName

# Ban a player
bash scripts/players.sh --ban PlayerName "Reason for ban"

# List online players
bash scripts/players.sh --online
# Output: Online (3/20): Steve, Alex, Notch
```

### Workflow 5: Server Monitoring

```bash
# Quick status
bash scripts/status.sh

# Detailed monitoring (CPU, RAM, TPS, players)
bash scripts/monitor.sh
# Output:
# 🖥️  CPU: 45% | RAM: 2.1/4.0 GB
# 📊 TPS: 19.8/20.0 (excellent)
# 👥 Players: 5/20
# 💾 World: 1.4 GB | Backups: 3.2 GB
# 🕐 Uptime: 12h 45m

# Watch mode (updates every 30s)
bash scripts/monitor.sh --watch
```

### Workflow 6: Send Commands to Server

```bash
# Send any Minecraft command
bash scripts/cmd.sh "say Server restarting in 5 minutes!"
bash scripts/cmd.sh "time set day"
bash scripts/cmd.sh "weather clear"
bash scripts/cmd.sh "difficulty hard"
bash scripts/cmd.sh "gamerule keepInventory true"
```

## Configuration

### server.properties (Key Settings)

The installer sets sensible defaults. Edit `$MC_DIR/server.properties`:

```properties
# Performance
max-players=20
view-distance=10
simulation-distance=8
max-tick-time=60000

# Gameplay
difficulty=normal
gamemode=survival
pvp=true
spawn-protection=16
allow-nether=true

# Network
server-port=25565
online-mode=true
motd=\u00a7bMy Minecraft Server \u00a77- Welcome!

# Security
white-list=true
enforce-whitelist=true
```

### Environment Variables

```bash
# Server directory (default: ~/minecraft-server)
export MC_DIR="$HOME/minecraft-server"

# JVM memory allocation (default: 2G)
export MC_MIN_RAM="1G"
export MC_MAX_RAM="4G"

# Backup retention (default: 10)
export MC_BACKUP_KEEP=10

# Backup directory (default: $MC_DIR/backups)
export MC_BACKUP_DIR="$MC_DIR/backups"
```

### JVM Flags (Performance Tuning)

The start script uses optimized Aikar's flags by default:

```bash
# Override JVM flags if needed
export MC_JVM_FLAGS="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200"
```

## Advanced Usage

### Run as Systemd Service

```bash
# Install systemd service (auto-start on boot)
bash scripts/install.sh --systemd

# Manage via systemd
sudo systemctl start minecraft
sudo systemctl stop minecraft
sudo systemctl status minecraft
sudo systemctl enable minecraft  # Start on boot
```

### Multiple Servers

```bash
# Server 1: Survival
MC_DIR=~/mc-survival bash scripts/install.sh
MC_DIR=~/mc-survival bash scripts/start.sh

# Server 2: Creative (different port)
MC_DIR=~/mc-creative bash scripts/install.sh
# Edit ~/mc-creative/server.properties → server-port=25566, gamemode=creative
MC_DIR=~/mc-creative bash scripts/start.sh
```

### Modded Server (Fabric/Paper)

```bash
# Install Paper (performance-optimized)
bash scripts/install.sh --type paper

# Install Fabric (mod loader)
bash scripts/install.sh --type fabric

# Install Forge
bash scripts/install.sh --type forge --version 1.20.4
```

### Auto-Restart on Crash

```bash
# Enable watchdog (restarts server if it crashes)
bash scripts/start.sh --watchdog

# Combined with backup schedule
bash scripts/start.sh --watchdog --backup-interval 6h
```

## Troubleshooting

### Issue: "java: command not found"

```bash
# Install Java 21
sudo apt-get update && sudo apt-get install -y openjdk-21-jre-headless
# Verify
java -version
```

### Issue: "Not enough memory"

```bash
# Reduce RAM allocation
export MC_MAX_RAM="2G"
bash scripts/restart.sh
```

### Issue: Can't connect from outside

```bash
# Check firewall
sudo ufw allow 25565/tcp

# Check if server is listening
ss -tlnp | grep 25565

# If behind NAT, set up port forwarding on your router
```

### Issue: Low TPS (lag)

```bash
# Check what's causing lag
bash scripts/cmd.sh "timings on"
# Wait 5 minutes
bash scripts/cmd.sh "timings paste"
# Check the URL it outputs

# Quick fixes:
bash scripts/cmd.sh "gamerule randomTickSpeed 1"  # Reduce random ticks
# Reduce view-distance in server.properties to 8
```

### Issue: World corruption

```bash
# Restore from latest backup
bash scripts/backup.sh --restore latest
```

## Dependencies

- `java` (21+ for Minecraft 1.21+, 17+ for 1.18-1.20)
- `screen` (background server session)
- `curl` (download server JAR)
- `jq` (parse Mojang API)
- `tar` + `gzip` (backups)
- Optional: `systemd` (auto-start service)
