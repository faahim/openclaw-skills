# Listing Copy: Podcast Downloader

## Metadata
- **Type:** Skill
- **Name:** podcast-downloader
- **Display Name:** Podcast Downloader
- **Categories:** [media, automation]
- **Price:** $8
- **Dependencies:** [yt-dlp, curl, xmlstarlet, jq]
- **Icon:** 🎙️

## Tagline

Download, organize, and auto-sync podcast episodes from any RSS feed

## Description

Tired of podcast apps tracking your listening, pushing ads, and locking your episodes behind accounts? Podcast Downloader gives you full control — download episodes from any RSS feed, organize them by show, and auto-sync on a schedule.

Point it at any podcast RSS feed and it downloads episodes as MP3 files into organized folders. Subscribe to multiple shows, import your existing library from OPML exports, and set up cron jobs to automatically pull new episodes. Search episodes by keyword, keep only the latest N per show, and generate a markdown index of your entire library.

**What it does:**
- 📥 Download episodes from any RSS feed URL
- 🔄 Auto-sync subscriptions on a schedule (cron)
- 📂 Organize by show in clean folder structure
- 🔍 Search episodes by keyword before downloading
- 📋 Import existing subscriptions from OPML files
- 🧹 Auto-cleanup — keep only last N episodes per show
- 🎵 Audio extraction with format conversion (mp3, opus, m4a)
- 📊 Generate markdown index of your podcast library

Perfect for developers, self-hosters, and anyone who wants their podcast library on their own terms — no app subscriptions, no cloud, no tracking.

## Quick Start Preview

```bash
# Download latest 3 episodes from any podcast
bash scripts/podcast-dl.sh --feed "https://feeds.simplecast.com/54nAGcIl" --limit 3

# Subscribe and auto-sync
bash scripts/podcast-dl.sh --subscribe "https://lexfridman.com/feed/podcast/"
bash scripts/podcast-dl.sh --sync
```

## Core Capabilities

1. RSS feed parsing — Extract episodes from any standard podcast RSS feed
2. Smart downloading — Skip already-downloaded episodes, resume interrupted downloads
3. Multi-show management — Subscribe to unlimited feeds, sync all at once
4. OPML import — Migrate from Apple Podcasts, Pocket Casts, Overcast, etc.
5. Audio extraction — Convert video podcasts to audio-only (mp3, opus, m4a)
6. Cron scheduling — Auto-download new episodes every 1/6/12/24 hours
7. Episode search — Find episodes by keyword across any feed
8. Library cleanup — Automatically prune old episodes, keep latest N
9. Markdown index — Generate browsable index of your entire library
10. Proxy support — Download through SOCKS5/HTTP proxies
