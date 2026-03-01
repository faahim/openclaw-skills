---
name: media-organizer
description: >-
  Automatically sort, rename, and organize media files by type, date, and metadata.
categories: [media, automation]
dependencies: [exiftool, ffprobe, imagemagick, bash]
---

# Media Organizer

## What This Does

Watches directories and automatically sorts media files (photos, videos, audio) into organized folder structures based on metadata — date taken, camera model, resolution, file type. Renames files consistently, generates thumbnails for videos, and deduplicates by hash. Runs as a one-shot command or scheduled via cron/systemd timer.

**Example:** Drop 500 unsorted photos and videos into `~/incoming/` → they get sorted into `~/media/photos/2026/03/`, `~/media/videos/2026/03/`, renamed to `2026-03-01_143022_IMG.jpg`, with duplicates skipped.

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y exiftool ffmpeg imagemagick

# macOS
brew install exiftool ffmpeg imagemagick

# Verify
exiftool -ver && ffprobe -version | head -1 && convert -version | head -1
```

### 2. Run First Organization

```bash
# Organize a directory (dry-run first)
bash scripts/organize.sh --source ~/Downloads --dest ~/media --dry-run

# If output looks good, run for real
bash scripts/organize.sh --source ~/Downloads --dest ~/media
```

### 3. Set Up Automatic Monitoring

```bash
# Install systemd timer (runs every 30 min)
bash scripts/install-timer.sh --source ~/incoming --dest ~/media --interval 30

# Or use cron
echo "*/30 * * * * bash $(pwd)/scripts/organize.sh --source ~/incoming --dest ~/media >> /var/log/media-organizer.log 2>&1" | crontab -
```

## Core Workflows

### Workflow 1: Sort by Date

**Use case:** Organize years of unsorted photos/videos by year/month.

```bash
bash scripts/organize.sh \
  --source /mnt/backup/unsorted \
  --dest ~/media \
  --mode date \
  --format "%Y/%m/%d"
```

**Result:**
```
~/media/
├── photos/
│   ├── 2024/01/15/
│   │   ├── 2024-01-15_093045_DSC.jpg
│   │   └── 2024-01-15_093112_DSC.jpg
│   └── 2025/06/22/
│       └── 2025-06-22_184533_IMG.jpg
└── videos/
    └── 2025/06/22/
        └── 2025-06-22_185201_VID.mp4
```

### Workflow 2: Sort by Type + Generate Thumbnails

**Use case:** Separate media types and create video thumbnails for browsing.

```bash
bash scripts/organize.sh \
  --source ~/Downloads \
  --dest ~/media \
  --mode type \
  --thumbnails
```

**Result:**
```
~/media/
├── photos/  (jpg, png, heic, webp, raw)
├── videos/  (mp4, mkv, avi, mov)
│   └── .thumbs/  (auto-generated 320px thumbnails)
├── audio/   (mp3, flac, wav, ogg)
└── documents/ (pdf, doc, txt — optional)
```

### Workflow 3: Deduplicate

**Use case:** Find and remove duplicate files across directories.

```bash
bash scripts/organize.sh \
  --source ~/media \
  --dedup \
  --dedup-action move \
  --dedup-dest ~/media/.duplicates
```

**Output:**
```
[DEDUP] Found 23 duplicate files (1.8 GB)
[DEDUP] Moved duplicates to ~/media/.duplicates/
[DEDUP] Kept originals with earliest creation date
```

### Workflow 4: Bulk Rename

**Use case:** Rename files to a consistent pattern using EXIF data.

```bash
bash scripts/organize.sh \
  --source ~/photos \
  --rename-only \
  --pattern "{date}_{time}_{camera}_{seq}"
```

**Result:**
```
IMG_4521.jpg → 2026-02-14_153022_iPhone15Pro_001.jpg
DSC_0031.NEF → 2026-02-14_153045_NikonZ6III_002.NEF
```

## Configuration

### Config File (YAML)

```yaml
# media-organizer.yaml
source: ~/incoming
dest: ~/media

# Organization mode: date | type | camera | custom
mode: date
date_format: "%Y/%m"

# File handling
rename: true
rename_pattern: "{date}_{time}_{seq}"
move: true  # false = copy instead

# Deduplication
dedup: true
dedup_action: skip  # skip | move | delete
dedup_dest: ~/media/.duplicates

# Thumbnails
thumbnails: true
thumb_size: 320

# File types to process
include:
  photos: [jpg, jpeg, png, heic, webp, tiff, raw, cr2, nef, arw, dng]
  videos: [mp4, mkv, avi, mov, wmv, flv, webm, m4v]
  audio: [mp3, flac, wav, ogg, m4a, aac, wma]

# Exclude patterns
exclude:
  - "*.tmp"
  - ".DS_Store"
  - "Thumbs.db"

# Logging
log_file: /var/log/media-organizer.log
log_level: info  # debug | info | warn | error
```

### Environment Variables

```bash
# Override config path
export MEDIA_ORG_CONFIG="~/.config/media-organizer/config.yaml"

# Override source/dest
export MEDIA_ORG_SOURCE="~/incoming"
export MEDIA_ORG_DEST="~/media"
```

## Advanced Usage

### Run as Systemd Timer

```bash
bash scripts/install-timer.sh \
  --source ~/incoming \
  --dest ~/media \
  --interval 30 \
  --config ~/.config/media-organizer/config.yaml

# Check status
systemctl --user status media-organizer.timer
systemctl --user list-timers | grep media

# View logs
journalctl --user -u media-organizer.service -f
```

### Process Only New Files

```bash
# Track processed files to avoid re-scanning
bash scripts/organize.sh \
  --source ~/incoming \
  --dest ~/media \
  --incremental
```

### HEIC to JPEG Conversion

```bash
# Convert Apple HEIC photos to JPEG during organization
bash scripts/organize.sh \
  --source ~/incoming \
  --dest ~/media \
  --convert-heic
```

### Generate Index/Report

```bash
# Generate a summary report of organized media
bash scripts/organize.sh \
  --source ~/media \
  --report

# Output:
# Media Library Summary
# ─────────────────────
# Photos:  2,847 files (18.3 GB)
# Videos:    156 files (42.1 GB)
# Audio:     892 files (6.7 GB)
# Total:   3,895 files (67.1 GB)
# Duplicates found: 23 (1.8 GB)
# Date range: 2019-03-15 to 2026-03-01
```

## Troubleshooting

### Issue: "exiftool: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install libimage-exiftool-perl

# macOS
brew install exiftool

# Verify
exiftool -ver
```

### Issue: HEIC files not recognized

```bash
# Install HEIC support
sudo apt-get install libheif-examples  # for heif-convert
# Or use ImageMagick with HEIC support
sudo apt-get install libheif-dev
```

### Issue: Permission denied on destination

```bash
# Check ownership
ls -la ~/media/

# Fix permissions
sudo chown -R $USER:$USER ~/media/
chmod -R 755 ~/media/
```

### Issue: Slow processing on large libraries

```bash
# Use parallel processing (requires GNU parallel)
bash scripts/organize.sh --source ~/incoming --dest ~/media --parallel 4
```

## Dependencies

- `exiftool` — Extract photo/video metadata (date, camera, GPS)
- `ffprobe` (part of ffmpeg) — Extract video metadata and duration
- `imagemagick` — Generate thumbnails and convert formats
- `bash` 4.0+ — Script runtime
- `md5sum`/`shasum` — File deduplication hashing
- Optional: `GNU parallel` — Parallel file processing
- Optional: `yq` — YAML config parsing
