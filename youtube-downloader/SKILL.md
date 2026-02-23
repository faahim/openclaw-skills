---
name: youtube-downloader
description: >-
  Download videos and audio from YouTube and 1000+ sites using yt-dlp. Extract audio, choose quality, batch download playlists.
categories: [media, fun]
dependencies: [yt-dlp, ffmpeg]
---

# YouTube Downloader

## What This Does

Download videos, audio, and playlists from YouTube and 1000+ supported sites using yt-dlp. Extract MP3 audio from music videos, download in specific quality/format, grab entire playlists, and embed metadata — all from the command line.

**Example:** "Download this playlist as MP3s at 320kbps, embed thumbnails, organize into a folder."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install yt-dlp (recommended: pipx or pip)
which yt-dlp || pip3 install --user yt-dlp

# Install ffmpeg (required for audio extraction & format conversion)
which ffmpeg || sudo apt-get install -y ffmpeg

# Verify installation
yt-dlp --version
ffmpeg -version 2>&1 | head -1
```

### 2. Download a Video

```bash
# Download best quality video
bash scripts/download.sh --url "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Output:
# [youtube-dl] Downloading: Rick Astley - Never Gonna Give You Up
# [download] 100% of 45.2MiB
# ✅ Saved: downloads/Rick Astley - Never Gonna Give You Up.mp4
```

### 3. Extract Audio Only

```bash
# Download as MP3 (320kbps)
bash scripts/download.sh --url "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --audio-only

# Output:
# ✅ Saved: downloads/Rick Astley - Never Gonna Give You Up.mp3
```

## Core Workflows

### Workflow 1: Download Single Video (Best Quality)

```bash
bash scripts/download.sh \
  --url "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Workflow 2: Download Audio Only (MP3)

**Use case:** Extract music from YouTube videos

```bash
bash scripts/download.sh \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --audio-only \
  --audio-format mp3 \
  --audio-quality 320
```

### Workflow 3: Download Playlist

**Use case:** Grab an entire playlist as audio or video

```bash
bash scripts/download.sh \
  --url "https://www.youtube.com/playlist?list=PLAYLIST_ID" \
  --playlist \
  --audio-only
```

Files saved to: `downloads/<Playlist Name>/001 - Title.mp3`

### Workflow 4: Download Specific Quality

```bash
# 1080p max
bash scripts/download.sh \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --quality 1080

# 720p max (smaller files)
bash scripts/download.sh \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --quality 720

# Best available (default)
bash scripts/download.sh \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --quality best
```

### Workflow 5: Download with Subtitles

```bash
bash scripts/download.sh \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --subs \
  --subs-lang en
```

### Workflow 6: Download from Other Sites

yt-dlp supports 1000+ sites: Vimeo, Twitter/X, Reddit, Twitch, SoundCloud, Bandcamp, etc.

```bash
# Twitter video
bash scripts/download.sh --url "https://twitter.com/user/status/123456"

# Reddit video
bash scripts/download.sh --url "https://www.reddit.com/r/sub/comments/..."

# SoundCloud audio
bash scripts/download.sh --url "https://soundcloud.com/artist/track" --audio-only
```

### Workflow 7: Batch Download from File

```bash
# Create a file with URLs (one per line)
cat > urls.txt << 'EOF'
https://www.youtube.com/watch?v=VIDEO1
https://www.youtube.com/watch?v=VIDEO2
https://www.youtube.com/watch?v=VIDEO3
EOF

bash scripts/download.sh --batch urls.txt
```

### Workflow 8: Get Video Info (No Download)

```bash
bash scripts/download.sh \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --info-only

# Output:
# Title: Video Title
# Duration: 4:32
# Resolution: 1920x1080
# Formats: mp4 (1080p), webm (1440p), mp4 (720p)...
# Filesize: ~45MB (best)
```

## Configuration

### Environment Variables

```bash
# Custom download directory (default: ./downloads)
export YTD_OUTPUT_DIR="$HOME/Videos/youtube"

# Default audio format (mp3, opus, m4a, flac, wav)
export YTD_AUDIO_FORMAT="mp3"

# Default audio quality (0=best, 5=good, 9=worst for VBR; or kbps: 128, 192, 256, 320)
export YTD_AUDIO_QUALITY="320"

# Default video quality (best, 2160, 1440, 1080, 720, 480)
export YTD_VIDEO_QUALITY="best"

# Embed thumbnail in audio files (true/false)
export YTD_EMBED_THUMBNAIL="true"

# Rate limit downloads (e.g., 5M for 5MB/s)
export YTD_RATE_LIMIT=""

# Cookie file for age-restricted/private videos
export YTD_COOKIES=""
```

### Config File

```bash
# Save defaults to config
cat > ~/.ytd-config << 'EOF'
YTD_OUTPUT_DIR="$HOME/Videos/youtube"
YTD_AUDIO_FORMAT="mp3"
YTD_AUDIO_QUALITY="320"
YTD_VIDEO_QUALITY="best"
YTD_EMBED_THUMBNAIL="true"
EOF
```

## Advanced Usage

### Age-Restricted Videos

```bash
# Export cookies from browser (use browser extension like "Get cookies.txt")
bash scripts/download.sh \
  --url "https://www.youtube.com/watch?v=RESTRICTED" \
  --cookies ~/cookies.txt
```

### Download Specific Format

```bash
# List available formats
bash scripts/download.sh --url "URL" --list-formats

# Download specific format by ID
bash scripts/download.sh --url "URL" --format "137+140"
```

### Rate Limiting

```bash
# Limit to 5MB/s
bash scripts/download.sh --url "URL" --rate-limit 5M
```

### Download Chapter Markers

```bash
# Split video by chapters
bash scripts/download.sh \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --split-chapters
```

### Archive Mode (Skip Already Downloaded)

```bash
# Maintain an archive file to skip re-downloads
bash scripts/download.sh \
  --url "https://www.youtube.com/playlist?list=PLAYLIST_ID" \
  --playlist \
  --archive downloads/archive.txt
```

## Troubleshooting

### Issue: "yt-dlp: command not found"

```bash
# Install via pip
pip3 install --user yt-dlp

# Or download binary directly
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
```

### Issue: "ffmpeg not found" (audio extraction fails)

```bash
# Ubuntu/Debian
sudo apt-get install -y ffmpeg

# Mac
brew install ffmpeg

# Arch
sudo pacman -S ffmpeg
```

### Issue: HTTP 403 / Age-restricted

Export browser cookies and pass with `--cookies` flag.

### Issue: "Video unavailable"

Video may be region-locked, private, or deleted. Try with `--geo-bypass`.

### Issue: Slow downloads

Use `--rate-limit` to avoid throttling, or try at different times.

### Issue: yt-dlp outdated

```bash
# Update to latest
pip3 install --upgrade yt-dlp
# Or: yt-dlp -U
```

## Supported Sites

yt-dlp supports **1000+ sites** including:
YouTube, Vimeo, Twitter/X, Reddit, Twitch, TikTok, Instagram, Facebook, SoundCloud, Bandcamp, Dailymotion, Bilibili, Niconico, and many more.

Full list: `yt-dlp --list-extractors`

## Dependencies

- `yt-dlp` (latest — the maintained fork of youtube-dl)
- `ffmpeg` (4.0+ — for audio extraction, format conversion, thumbnails)
- `bash` (4.0+)
- Optional: `atomicparsley` (for embedding thumbnails in M4A)
