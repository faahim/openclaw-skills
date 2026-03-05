---
name: navidrome-server
description: >-
  Install and manage Navidrome, a self-hosted music streaming server with web UI and Subsonic API compatibility.
categories: [media, home]
dependencies: [bash, curl, systemd]
---

# Navidrome Music Server Manager

## What This Does

Install, configure, and manage [Navidrome](https://www.navidrome.org/) — a lightweight, self-hosted music streaming server. Stream your music collection from anywhere via web browser or Subsonic-compatible apps (DSub, Substreamer, play:Sub, Symphonium). Supports MP3, FLAC, OGG, AAC, and more.

**Example:** "Install Navidrome, point it at my music folder, access from any device via browser or mobile app."

## Quick Start (5 minutes)

### 1. Install Navidrome

```bash
bash scripts/install.sh
```

This will:
- Download the latest Navidrome binary
- Create a dedicated `navidrome` user
- Set up directories (`/var/lib/navidrome`, `/opt/navidrome`)
- Install and enable a systemd service
- Start Navidrome on port 4533

### 2. Set Your Music Folder

```bash
bash scripts/configure.sh --music-folder /path/to/your/music
```

Default music folder: `~/Music`

### 3. Access the Web UI

Open `http://your-server-ip:4533` in a browser. Create your admin account on first visit.

## Core Workflows

### Workflow 1: Install Navidrome

```bash
# Install latest version
bash scripts/install.sh

# Install specific version
bash scripts/install.sh --version 0.53.3

# Check installation
bash scripts/manage.sh status
```

**Output:**
```
✅ Navidrome v0.53.3 installed
   URL: http://localhost:4533
   Music: /home/user/Music
   Data:  /var/lib/navidrome
   Service: active (running)
```

### Workflow 2: Configure Settings

```bash
# Set music folder
bash scripts/configure.sh --music-folder /mnt/nas/music

# Set port
bash scripts/configure.sh --port 8080

# Enable transcoding (requires ffmpeg)
bash scripts/configure.sh --transcode true

# Set scan interval (how often to check for new music)
bash scripts/configure.sh --scan-interval 5m

# Show current config
bash scripts/configure.sh --show
```

### Workflow 3: Manage the Service

```bash
# Start/stop/restart
bash scripts/manage.sh start
bash scripts/manage.sh stop
bash scripts/manage.sh restart

# Check status
bash scripts/manage.sh status

# View logs (last 50 lines)
bash scripts/manage.sh logs

# Follow logs in real-time
bash scripts/manage.sh logs -f

# Trigger music library scan
bash scripts/manage.sh scan
```

### Workflow 4: Update Navidrome

```bash
# Update to latest version
bash scripts/manage.sh update

# Update to specific version
bash scripts/manage.sh update --version 0.53.3
```

### Workflow 5: Backup & Restore

```bash
# Backup database and config
bash scripts/manage.sh backup /path/to/backup/

# Restore from backup
bash scripts/manage.sh restore /path/to/backup/navidrome-backup-2026-03-05.tar.gz
```

### Workflow 6: Set Up Reverse Proxy (Nginx)

```bash
# Generate Nginx config for domain
bash scripts/configure.sh --nginx-config music.example.com

# Output: Nginx config written to /etc/nginx/sites-available/navidrome
# Then: sudo ln -s /etc/nginx/sites-available/navidrome /etc/nginx/sites-enabled/
# Then: sudo nginx -t && sudo systemctl reload nginx
```

### Workflow 7: Connect Mobile Apps

After Navidrome is running, connect from Subsonic-compatible apps:

| App | Platform | Setting |
|-----|----------|---------|
| DSub | Android | Server: `http://your-ip:4533`, Username/Password from web UI |
| Substreamer | iOS/Android | Same as above |
| play:Sub | iOS | Same as above |
| Symphonium | Android | Same as above |
| Sonixd | Desktop | Same as above |

## Configuration

### Config File (`/var/lib/navidrome/navidrome.toml`)

```toml
# Music library path
MusicFolder = "/home/user/Music"

# Server settings
Address = "0.0.0.0"
Port = 4533

# Scanning
ScanSchedule = "@every 5m"
AutoImportPlaylists = true

# Transcoding (requires ffmpeg)
EnableTranscodingConfig = true
DefaultTranscodingFormat = "opus"

# UI
UIWelcomeMessage = "Welcome to my music server!"
EnableStarRating = true
EnableFavourites = true

# Security
SessionTimeout = "24h"
EnableGravatar = false
```

### Environment Variables

```bash
# Override config via environment
export ND_MUSICFOLDER="/mnt/music"
export ND_PORT="4533"
export ND_DATAFOLDER="/var/lib/navidrome"
export ND_LOGLEVEL="info"
export ND_SCANSCHEDULE="@every 5m"
```

## Advanced Usage

### Run with Docker (Alternative)

```bash
# Docker run
docker run -d \
  --name navidrome \
  -p 4533:4533 \
  -v /path/to/music:/music:ro \
  -v /path/to/data:/data \
  -e ND_SCANSCHEDULE="@every 5m" \
  deluan/navidrome:latest

# Docker Compose
bash scripts/configure.sh --docker-compose /path/to/music
```

### Enable HTTPS with Let's Encrypt

```bash
# Use with reverse proxy (recommended)
bash scripts/configure.sh --nginx-config music.example.com --ssl
```

### Multiple Music Libraries

Navidrome supports one music folder. For multiple sources, use symlinks:

```bash
mkdir -p /mnt/all-music
ln -s /mnt/nas/rock /mnt/all-music/rock
ln -s /mnt/nas/jazz /mnt/all-music/jazz
ln -s /home/user/downloads/music /mnt/all-music/downloads
bash scripts/configure.sh --music-folder /mnt/all-music
```

### Smart Playlists

Create `.nsp` files in your music folder:

```json
{
  "all": [
    {"contains": {"genre": "Rock"}},
    {"inTheLast": {"playedAt": 30}}
  ],
  "sort": "random",
  "limit": 50
}
```

## Troubleshooting

### Issue: "permission denied" on music folder

**Fix:**
```bash
sudo chown -R navidrome:navidrome /path/to/music
# OR add navidrome user to your group
sudo usermod -aG $(whoami) navidrome
```

### Issue: No transcoding available

**Fix:**
```bash
# Install ffmpeg
sudo apt-get install -y ffmpeg  # Debian/Ubuntu
sudo dnf install -y ffmpeg      # Fedora
brew install ffmpeg              # macOS

# Enable in config
bash scripts/configure.sh --transcode true
```

### Issue: Port already in use

**Fix:**
```bash
bash scripts/configure.sh --port 8080
bash scripts/manage.sh restart
```

### Issue: Music not showing up

**Fix:**
```bash
# Trigger manual scan
bash scripts/manage.sh scan

# Check logs for errors
bash scripts/manage.sh logs | grep -i error

# Verify music folder path
bash scripts/configure.sh --show
```

### Issue: High memory usage with large libraries

**Fix:** Add to config:
```toml
SearchFullString = false
EnableMediaFileCoverArt = false
```

## Uninstall

```bash
bash scripts/manage.sh uninstall
```

This removes the binary, systemd service, and user. Your music files and database are preserved (delete `/var/lib/navidrome` manually if wanted).

## Dependencies

- `bash` (4.0+)
- `curl` (downloading binary)
- `systemd` (service management) — or Docker as alternative
- `ffmpeg` (optional, for transcoding)
- `tar` (extracting release)
