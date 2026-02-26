# Listing Copy: Aria2 Download Manager

## Metadata
- **Type:** Skill
- **Name:** aria2-download-manager
- **Display Name:** Aria2 Download Manager
- **Categories:** [automation, productivity]
- **Price:** $10
- **Dependencies:** [aria2, jq, curl]

## Tagline

"High-speed multi-connection downloads — HTTP, FTP, BitTorrent, and Magnet links from your terminal"

## Description

Downloading large files over slow single connections is painful. ISOs, datasets, backups — one connection means you're using a fraction of your bandwidth. Resuming broken downloads means starting over.

Aria2 Download Manager installs and configures aria2 — the Swiss Army knife of download utilities. Split files across 16 connections for maximum speed, download from multiple mirrors simultaneously, resume interrupted transfers automatically, and manage everything via RPC. Supports HTTP/HTTPS, FTP, BitTorrent, and Magnet links.

**What it does:**
- ⚡ Multi-connection downloads — Split files across up to 16 connections
- 🧲 BitTorrent/Magnet support — Download torrents with DHT and peer exchange
- 📦 Batch downloads — Feed a URL list, download everything in parallel
- ⏸️ Pause/Resume — Interrupt anytime, pick up where you left off
- 🎛️ Bandwidth throttle — Limit speed so your network stays usable
- 🖥️ RPC daemon mode — Run as background service, control via API
- 🔗 Mirror support — Download from multiple sources simultaneously
- 🔒 Custom headers — Auth tokens, user agents, cookies

Perfect for developers, sysadmins, and power users who download ISOs, datasets, backups, or any large files regularly.

## Core Capabilities

1. Multi-connection downloading — Split files across 16 parallel connections
2. HTTP/HTTPS/FTP support — Standard protocol downloads with resume
3. BitTorrent & Magnet links — Full torrent client with DHT and peer exchange
4. Batch downloading — Process URL lists with configurable concurrency
5. Auto-resume — Interrupted downloads continue from where they stopped
6. Mirror downloading — Same file from multiple sources for max speed
7. Bandwidth throttling — Set download/upload speed limits
8. RPC daemon mode — Background service with JSON-RPC API control
9. Custom HTTP headers — Bearer tokens, cookies, user agents
10. YAML config — Persistent settings for connections, paths, limits

## Dependencies
- `aria2` (auto-installed)
- `jq`
- `curl`

## Installation Time
**5 minutes** — Run install script, start downloading
