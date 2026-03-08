# Listing Copy: Transmission Torrent Manager

## Metadata
- **Type:** Skill
- **Name:** transmission-torrent
- **Display Name:** Transmission Torrent Manager
- **Categories:** [media, automation]
- **Icon:** 🌊
- **Dependencies:** [transmission-daemon, transmission-cli, curl, jq]

## Tagline

Manage Transmission torrent daemon — add, monitor, organize downloads from the CLI

## Description

Managing torrents on headless servers and remote machines shouldn't require a web UI or constant SSH sessions. Whether you're downloading Linux ISOs, open-source datasets, or Creative Commons media, you need a fast way to add torrents, check progress, and keep things organized.

Transmission Torrent Manager installs and configures the Transmission BitTorrent daemon, then wraps it with a clean CLI. Add torrents by magnet link, URL, or file. Monitor download progress in real-time. Set speed limits, schedule turtle mode for work hours, auto-organize completed downloads, and clean up old seeds — all from your OpenClaw agent.

**What it does:**
- 📥 Add torrents via magnet links, URLs, or .torrent files
- 📊 Real-time download progress monitoring with live watch mode
- ⚡ Speed limit controls (global, per-direction, scheduled turtle mode)
- 📁 Auto-organize: move completed downloads to designated folders
- 🧹 Auto-clean old completed torrents on a schedule
- 🛡️ IP blocklist support for privacy
- 🔧 Full daemon configuration from CLI (ports, peers, encryption, DHT)
- 🌐 Remote management — connect to any Transmission daemon on your network

Perfect for developers, homelabbers, and anyone running headless Linux servers who wants torrent management without leaving the terminal.

## Quick Start Preview

```bash
# Install & start daemon
bash scripts/install.sh

# Add a torrent
bash scripts/run.sh add "magnet:?xt=urn:btih:..."

# Check status
bash scripts/run.sh status
# ID  Done  ETA   Status       Name
#  1  45%   12m   Downloading  ubuntu-24.04-desktop-amd64.iso
```

## Core Capabilities

1. Torrent management — Add, pause, resume, remove torrents via CLI
2. Live monitoring — Watch download progress with real-time updates
3. Speed controls — Set global download/upload limits in KB/s
4. Turtle mode — Schedule slow speeds during work hours automatically
5. Auto-organize — Move completed downloads to designated folders
6. Auto-cleanup — Remove old seeded torrents on a cron schedule
7. IP blocklist — Auto-update blocklists for privacy protection
8. Remote management — Connect to any Transmission daemon on your network
9. Multi-OS support — Ubuntu, Debian, Fedora, Arch, Alpine, macOS
10. Daemon control — Install, start, stop, restart the Transmission service

## Installation Time
**5 minutes** — One command installs, configures, and starts the daemon.
