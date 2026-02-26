---
name: aria2-download-manager
description: >-
  High-speed download manager with multi-connection downloads, BitTorrent/Magnet support, batch downloading, and RPC control.
categories: [automation, productivity]
dependencies: [aria2, jq, curl]
---

# Aria2 Download Manager

## What This Does

Aria2 is a lightweight multi-protocol download utility that supports HTTP/HTTPS, FTP, BitTorrent, and Magnet links. This skill installs, configures, and manages aria2 — enabling blazing-fast downloads with multi-connection splitting, batch downloading from file lists, pause/resume, bandwidth throttling, and RPC-based remote control.

**Example:** "Download 20 files simultaneously, split each across 16 connections, throttle to 5MB/s, resume if interrupted."

## Quick Start (5 minutes)

### 1. Install aria2

```bash
bash scripts/install.sh
```

### 2. Download a File (Multi-Connection)

```bash
bash scripts/run.sh --url "https://example.com/largefile.zip" --split 16

# Output:
# [2026-02-26 19:00:00] ⬇️  Downloading: largefile.zip
# [2026-02-26 19:00:00] 📊 Connections: 16 | Speed: 45.2 MB/s
# [2026-02-26 19:00:15] ✅ Complete: largefile.zip (678 MB in 15s)
```

### 3. Download a Magnet/Torrent

```bash
bash scripts/run.sh --torrent "magnet:?xt=urn:btih:HASH..."
bash scripts/run.sh --torrent "/path/to/file.torrent"
```

## Core Workflows

### Workflow 1: Single Fast Download

**Use case:** Download a large file with maximum speed using connection splitting.

```bash
bash scripts/run.sh \
  --url "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso" \
  --split 16 \
  --dir ~/Downloads
```

### Workflow 2: Batch Download from File List

**Use case:** Download many files listed in a text file.

```bash
# Create a list of URLs (one per line)
cat > downloads.txt << 'EOF'
https://example.com/file1.zip
https://example.com/file2.zip
https://example.com/file3.zip
EOF

bash scripts/run.sh --batch downloads.txt --max-concurrent 5 --split 8
```

### Workflow 3: Resume Interrupted Download

**Use case:** Continue a download that was interrupted.

```bash
# aria2 auto-resumes by default — just re-run the same command
bash scripts/run.sh --url "https://example.com/largefile.zip" --split 16
# Automatically picks up where it left off
```

### Workflow 4: Bandwidth Throttle

**Use case:** Limit download speed so other network traffic isn't affected.

```bash
bash scripts/run.sh \
  --url "https://example.com/hugefile.tar.gz" \
  --max-speed 5M \
  --split 8
```

### Workflow 5: BitTorrent Download with Seeding

```bash
bash scripts/run.sh \
  --torrent "magnet:?xt=urn:btih:HASH&dn=filename" \
  --seed-ratio 1.0 \
  --dir ~/Downloads/torrents
```

### Workflow 6: RPC Daemon Mode

**Use case:** Run aria2 as a background service, control via API.

```bash
# Start daemon
bash scripts/daemon.sh start

# Add download via RPC
bash scripts/rpc.sh add "https://example.com/file.zip"

# List active downloads
bash scripts/rpc.sh status

# Pause a download
bash scripts/rpc.sh pause <GID>

# Resume
bash scripts/rpc.sh resume <GID>

# Stop daemon
bash scripts/daemon.sh stop
```

### Workflow 7: Download with Custom Headers

**Use case:** Download from authenticated endpoints.

```bash
bash scripts/run.sh \
  --url "https://api.example.com/file.zip" \
  --header "Authorization: Bearer TOKEN" \
  --header "User-Agent: MyApp/1.0"
```

### Workflow 8: Mirror Download (Multiple Sources)

**Use case:** Download same file from multiple mirrors for maximum speed.

```bash
bash scripts/run.sh \
  --url "https://mirror1.example.com/file.iso" \
  --url "https://mirror2.example.com/file.iso" \
  --url "https://mirror3.example.com/file.iso" \
  --split 16
```

## Configuration

### Config File

```bash
# Copy template
cp scripts/aria2.conf.template ~/.aria2/aria2.conf

# Edit as needed — key settings:
# max-concurrent-downloads=5
# split=16
# max-connection-per-server=16
# min-split-size=1M
# max-overall-download-limit=0
# dir=/home/user/Downloads
# continue=true
# enable-rpc=false
```

### Environment Variables

```bash
# Override download directory
export ARIA2_DIR="$HOME/Downloads"

# RPC secret (for daemon mode)
export ARIA2_RPC_SECRET="mysecrettoken"

# Default max connections per server
export ARIA2_SPLIT=16
```

## Advanced Usage

### Run as Cron Job (Scheduled Downloads)

```bash
# Download during off-peak hours
0 2 * * * bash /path/to/scripts/run.sh --batch /path/to/nightly-downloads.txt --max-speed 0
```

### Integration with OpenClaw Cron

```bash
# Schedule via OpenClaw cron to download large files overnight
# The agent can add URLs to a batch file, then the cron triggers the download
```

### Download Monitoring

```bash
# Watch download progress (daemon mode)
watch -n 1 'bash scripts/rpc.sh status'
```

## Troubleshooting

### Issue: "aria2c: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: sudo apt-get install -y aria2
# Mac: brew install aria2
# Alpine: apk add aria2
```

### Issue: Download speed is slow

**Check:**
1. Increase split: `--split 16` (max connections per file)
2. Remove speed limit: `--max-speed 0`
3. Try more connections: `--max-connection-per-server 16`

### Issue: Torrent not connecting to peers

**Check:**
1. Ensure DHT is enabled (default)
2. Check if port 6881-6999 is open
3. Try adding trackers: `--bt-tracker=udp://tracker.opentrackr.org:1337`

### Issue: RPC not responding

**Check:**
1. Is daemon running? `bash scripts/daemon.sh status`
2. Correct secret token? Check `$ARIA2_RPC_SECRET`
3. Port available? `ss -tlnp | grep 6800`

## Dependencies

- `aria2` (1.36+) — the download engine
- `jq` — JSON parsing for RPC responses
- `curl` — RPC communication
- Optional: `cron` — scheduled downloads
