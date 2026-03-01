# Listing Copy: Media Organizer

## Metadata
- **Type:** Skill
- **Name:** media-organizer
- **Display Name:** Media Organizer
- **Categories:** [media, automation]
- **Price:** $12
- **Dependencies:** [exiftool, ffprobe, imagemagick]
- **Icon:** 📂

## Tagline

Automatically sort, rename, and deduplicate photos, videos, and audio by metadata

## Description

Thousands of unsorted photos and videos scattered across Downloads, external drives, and random folders. Sound familiar? Manually organizing media is tedious, error-prone, and never gets done.

Media Organizer scans your files, reads EXIF/metadata (date taken, camera model, GPS), and automatically sorts everything into clean folder structures. Photos go to `photos/2026/03/`, videos get thumbnails, duplicates get caught by hash comparison. Runs as a one-shot command or scheduled via systemd timer for hands-free organization.

**What it does:**
- 📸 Sort photos/videos/audio into date, type, or camera-based folders
- ✏️ Rename files consistently using metadata (`2026-03-01_143022_iPhone15.jpg`)
- 🔄 Detect and handle duplicates via MD5 hash comparison
- 🖼️ Auto-generate video thumbnails for easy browsing
- 📱 Convert Apple HEIC photos to JPEG on the fly
- ⏰ Schedule automatic organization via systemd timer or cron
- 📊 Generate library summary reports (file counts, sizes, date ranges)
- 🚀 Incremental mode — only processes new files

Perfect for photographers, content creators, sysadmins managing media servers, or anyone drowning in unsorted files.

## Quick Start Preview

```bash
# Dry-run first to preview
bash scripts/organize.sh --source ~/Downloads --dest ~/media --dry-run

# Sort by date with auto-rename
bash scripts/organize.sh --source ~/Downloads --dest ~/media --rename --thumbnails

# Schedule automatic runs every 30 min
bash scripts/install-timer.sh --source ~/incoming --dest ~/media --interval 30
```

## Core Capabilities

1. Date-based organization — Sort into year/month/day folders from EXIF data
2. Type-based sorting — Separate photos, videos, and audio automatically
3. Camera-based sorting — Group by camera model (iPhone, Nikon, etc.)
4. Smart renaming — Consistent naming from metadata with conflict handling
5. Duplicate detection — MD5 hash comparison, skip/move/delete dupes
6. Video thumbnails — Auto-extract preview frames using ffmpeg
7. HEIC conversion — Convert Apple photos to JPEG during organization
8. Incremental processing — Track processed files, skip on re-runs
9. Systemd timer — Set-and-forget scheduled organization
10. Library reports — File counts, sizes, and date range summaries
11. Dry-run mode — Preview all changes before applying
12. Parallel processing — Speed up large libraries with GNU parallel

## Dependencies
- `exiftool` — EXIF/metadata extraction
- `ffmpeg`/`ffprobe` — Video metadata and thumbnails
- `imagemagick` — Image conversion and thumbnails
- `bash` 4.0+

## Installation Time
**5 minutes** — Install deps, run first sort
