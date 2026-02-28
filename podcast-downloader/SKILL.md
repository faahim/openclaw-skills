---
name: podcast-downloader
description: >-
  Download, organize, and auto-sync podcast episodes from RSS feeds using yt-dlp.
categories: [media, automation]
dependencies: [yt-dlp, curl, jq, xmlstarlet]
---

# Podcast Downloader

## What This Does

Automatically downloads podcast episodes from any RSS feed, organizes them into folders by show, and can run on a schedule to keep your library synced. No app subscriptions, no cloud — your episodes, your storage.

**Example:** "Subscribe to 3 podcasts, auto-download new episodes daily, keep only last 20 per show."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install yt-dlp (downloads media from URLs)
pip3 install --user yt-dlp || sudo pip3 install yt-dlp

# Install xmlstarlet (parses RSS XML)
# Ubuntu/Debian:
sudo apt-get install -y xmlstarlet jq curl
# macOS:
brew install xmlstarlet jq curl

# Verify
which yt-dlp xmlstarlet jq curl && echo "✅ All dependencies installed"
```

### 2. Download Your First Episode

```bash
# Download the latest episode from any podcast RSS feed
bash scripts/podcast-dl.sh --feed "https://feeds.simplecast.com/54nAGcIl" --limit 1

# Output:
# 🎙️ Podcast: The Daily
# 📥 Downloading: Episode Title (2026-02-28)
# ✅ Saved: ~/Podcasts/The-Daily/2026-02-28_Episode-Title.mp3
```

### 3. Subscribe to Multiple Podcasts

```bash
# Create a subscriptions file
cp scripts/subscriptions-template.yaml subscriptions.yaml

# Edit subscriptions.yaml with your feeds, then:
bash scripts/podcast-dl.sh --subs subscriptions.yaml

# Downloads latest episodes from all subscribed podcasts
```

## Core Workflows

### Workflow 1: Download from a Single Feed

```bash
bash scripts/podcast-dl.sh \
  --feed "https://example.com/podcast/rss" \
  --limit 5 \
  --output ~/Podcasts
```

Downloads the 5 most recent episodes into `~/Podcasts/<Show-Name>/`.

### Workflow 2: Subscribe & Auto-Sync

```bash
# Subscribe to feeds
bash scripts/podcast-dl.sh --subscribe "https://feeds.simplecast.com/54nAGcIl"
bash scripts/podcast-dl.sh --subscribe "https://lexfridman.com/feed/podcast/"

# Sync all subscriptions (download new episodes only)
bash scripts/podcast-dl.sh --sync
```

### Workflow 3: Scheduled Auto-Download

```bash
# Add to crontab — sync every 6 hours
bash scripts/podcast-dl.sh --install-cron --interval 6h

# Or manually:
# 0 */6 * * * cd /path/to/skill && bash scripts/podcast-dl.sh --sync >> logs/sync.log 2>&1
```

### Workflow 4: List Episodes Without Downloading

```bash
bash scripts/podcast-dl.sh --feed "https://example.com/rss" --list

# Output:
# 1. [2026-02-28] Episode Title One (45 min)
# 2. [2026-02-25] Episode Title Two (62 min)
# 3. [2026-02-20] Episode Title Three (38 min)
```

### Workflow 5: Download Audio Only (Strip Video)

```bash
bash scripts/podcast-dl.sh \
  --feed "https://example.com/rss" \
  --audio-only \
  --format mp3 \
  --quality 128k
```

### Workflow 6: Search Episodes by Keyword

```bash
bash scripts/podcast-dl.sh \
  --feed "https://example.com/rss" \
  --search "artificial intelligence" \
  --download
```

## Configuration

### Subscriptions File (YAML)

```yaml
# subscriptions.yaml
output_dir: ~/Podcasts
max_episodes: 20        # Keep last N episodes per show
audio_format: mp3       # mp3, opus, m4a
audio_quality: 192k     # Bitrate

feeds:
  - url: https://feeds.simplecast.com/54nAGcIl
    name: The Daily        # Optional override
    max_episodes: 10       # Per-feed override

  - url: https://lexfridman.com/feed/podcast/
    name: Lex Fridman

  - url: https://changelog.com/podcast/feed
    name: The Changelog
    audio_format: opus     # Per-feed override
```

### Environment Variables

```bash
# Override default output directory
export PODCAST_DIR="$HOME/Podcasts"

# Override default max episodes
export PODCAST_MAX_EPISODES=20

# Proxy support (for restricted feeds)
export PODCAST_PROXY="socks5://localhost:1080"
```

## Advanced Usage

### Export OPML (Import from Podcast Apps)

```bash
# Import subscriptions from an OPML file (exported from Apple Podcasts, Pocket Casts, etc.)
bash scripts/podcast-dl.sh --import-opml ~/exported-podcasts.opml
```

### Cleanup Old Episodes

```bash
# Keep only the last 10 episodes per show, delete older ones
bash scripts/podcast-dl.sh --cleanup --keep 10
```

### Generate Episode Index

```bash
# Create a markdown index of all downloaded episodes
bash scripts/podcast-dl.sh --index > ~/Podcasts/INDEX.md
```

### Download Specific Episode by Number

```bash
bash scripts/podcast-dl.sh --feed "https://example.com/rss" --episode 42
```

## Troubleshooting

### Issue: "command not found: xmlstarlet"

```bash
# Ubuntu/Debian
sudo apt-get install -y xmlstarlet
# macOS
brew install xmlstarlet
# Arch
sudo pacman -S xmlstarlet
```

### Issue: "command not found: yt-dlp"

```bash
pip3 install --user yt-dlp
# Or download binary:
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o ~/.local/bin/yt-dlp
chmod +x ~/.local/bin/yt-dlp
```

### Issue: Feed returns 403 Forbidden

Some feeds require a user-agent header:
```bash
bash scripts/podcast-dl.sh --feed "https://example.com/rss" --user-agent "Mozilla/5.0"
```

### Issue: Episodes downloading as video instead of audio

```bash
bash scripts/podcast-dl.sh --feed "https://example.com/rss" --audio-only --format mp3
```

## Dependencies

- `yt-dlp` — Media downloader (handles audio extraction, format conversion)
- `curl` — HTTP requests (fetching RSS feeds)
- `xmlstarlet` — XML/RSS parsing
- `jq` — JSON processing (for state tracking)
- Optional: `ffmpeg` — Audio format conversion (usually bundled with yt-dlp)
- Optional: `cron` — Scheduled syncing
