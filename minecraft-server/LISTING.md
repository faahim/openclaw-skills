# Listing Copy: Minecraft Server Manager

## Metadata
- **Type:** Skill
- **Name:** minecraft-server
- **Display Name:** Minecraft Server Manager
- **Categories:** [fun, automation]
- **Price:** $12
- **Dependencies:** [java, screen, curl, jq]
- **Icon:** 🎮

## Tagline
Minecraft Server Manager — Install, run, backup, and manage a Minecraft server from your agent

## Description

Running a Minecraft server means juggling JAR downloads, JVM tuning, world backups, player management, and crash recovery. That's a lot of terminal commands to remember.

Minecraft Server Manager handles the entire server lifecycle through simple scripts. Download the latest version (or Paper/Fabric for mods), start with optimized Aikar's JVM flags, auto-backup worlds on a schedule, manage whitelists and ops, and monitor CPU/RAM/world size — all without memorizing Minecraft server admin commands.

**What it does:**
- 🎮 One-command install (Vanilla, Paper, Fabric)
- ⚡ Optimized JVM flags (Aikar's G1GC tuning)
- 💾 Scheduled backups with rotation and restore
- 👥 Player management (whitelist, op, ban)
- 📊 Resource monitoring (CPU, RAM, world size)
- 🔄 Watchdog auto-restart on crash
- 🖥️ Systemd service for auto-start on boot
- 🎯 Multi-server support (different ports/gamemodes)

Perfect for developers and gamers who want to spin up a Minecraft server for friends without the DevOps headache.

## Core Capabilities

1. Server installation — Download Vanilla, Paper, or Fabric server JARs automatically
2. Version management — Install any Minecraft version, auto-detect latest
3. Optimized startup — Aikar's JVM flags for best garbage collection performance
4. World backups — Scheduled tar.gz backups with configurable retention
5. Backup restore — One-command restore from any backup or latest
6. Player whitelist — Add/remove players without touching JSON files
7. Operator management — Op/deop players via script
8. Server commands — Send any command to the running server console
9. Resource monitoring — CPU, RAM, disk usage, world size at a glance
10. Crash recovery — Watchdog mode auto-restarts server on crash
11. Systemd integration — Auto-start on boot, managed via systemctl
12. Multi-server — Run survival + creative on different ports simultaneously

## Dependencies
- `java` (17+ or 21+ depending on MC version)
- `screen`
- `curl`
- `jq`
- `tar` + `gzip`

## Installation Time
**10 minutes** — Install Java, run install script, connect
