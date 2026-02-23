# Listing Copy: YouTube Downloader

## Metadata
- **Type:** Skill
- **Name:** youtube-downloader
- **Display Name:** YouTube Downloader
- **Categories:** [media, fun]
- **Price:** $8
- **Dependencies:** [yt-dlp, ffmpeg]

## Tagline

Download videos & audio from YouTube and 1000+ sites — extract MP3s, grab playlists, choose quality

## Description

Downloading videos and extracting audio from YouTube shouldn't require a sketchy website full of ads. You need a reliable, fast, scriptable tool that works from your terminal.

YouTube Downloader wraps yt-dlp with sensible defaults and an easy CLI. Download videos in any quality, extract MP3/FLAC audio from music videos, grab entire playlists organized into folders, embed metadata and thumbnails — all with one command. Works with YouTube, Vimeo, Twitter/X, Reddit, SoundCloud, and 1000+ other sites.

**What it does:**
- 🎬 Download videos in any quality (4K, 1080p, 720p, or best available)
- 🎵 Extract audio as MP3, FLAC, M4A, Opus, or WAV
- 📋 Download entire playlists with auto-numbering
- 📝 Embed subtitles, metadata, and thumbnails
- 🌐 Support for 1000+ sites (YouTube, Vimeo, Twitter, Reddit, SoundCloud...)
- 📦 Batch download from URL lists
- ✂️ Split videos by chapters
- 🔧 Auto-install script for all dependencies

Perfect for developers, content creators, and anyone who wants reliable media downloads without browser extensions or shady websites.

## Quick Start Preview

```bash
# Install dependencies
bash scripts/install.sh

# Download video
bash scripts/download.sh --url "https://youtube.com/watch?v=..." 

# Extract audio as MP3
bash scripts/download.sh --url "https://youtube.com/watch?v=..." --audio-only
```

## Core Capabilities

1. Video download — Best quality MP4 by default, configurable resolution
2. Audio extraction — MP3, FLAC, Opus, M4A, WAV with quality control
3. Playlist support — Download full playlists, auto-organized into folders
4. Multi-site — YouTube, Vimeo, Twitter/X, Reddit, SoundCloud, 1000+ more
5. Subtitle embedding — Auto/manual subs in any language
6. Batch download — Feed a list of URLs, download all at once
7. Chapter splitting — Split long videos by chapter markers
8. Format selection — List and pick specific video+audio format combos
9. Archive mode — Skip already-downloaded files (great for playlists)
10. Metadata embedding — Title, artist, thumbnail baked into files
11. Rate limiting — Control bandwidth usage
12. Cookie support — Access age-restricted or private content

## Dependencies
- `yt-dlp` (latest)
- `ffmpeg` (4.0+)
- `bash` (4.0+)
- Optional: `atomicparsley`

## Installation Time
**5 minutes** — run install.sh, start downloading

## Pricing Justification

**Why $8:**
- LarryBrain median: $8-15
- Comparable tools: browser extensions (free but ad-ridden), 4K Video Downloader ($15-45)
- Our advantage: scriptable, no GUI needed, agent-integrated, 1000+ sites
- Complexity: Low-Medium (wrapper with smart defaults)
