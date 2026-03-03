---
name: music-metadata-manager
description: >-
  Tag, organize, and rename audio files using metadata. Batch edit ID3 tags, embed album art, rename by pattern, and clean up music libraries.
categories: [media, productivity]
dependencies: [ffprobe, eyeD3, bash]
---

# Music Metadata Manager

## What This Does

Manage ID3/metadata tags on MP3, FLAC, OGG, and M4A files from the command line. Batch rename files by metadata pattern, embed album art, extract tags to CSV, and clean up messy music libraries. Uses `eyeD3` and `ffprobe` — no GUI needed.

**Example:** "Rename 500 MP3s to `Artist - Title.mp3`, embed cover art, fix missing tags — all in one command."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. View Tags on a File

```bash
bash scripts/run.sh info /path/to/song.mp3
```

**Output:**
```
File:     song.mp3
Title:    Midnight City
Artist:   M83
Album:    Hurry Up, We're Dreaming
Year:     2011
Track:    07/16
Genre:    Electronic
Duration: 4:03
Bitrate:  320 kbps
Cover:    embedded (300x300)
```

### 3. Batch Rename by Metadata

```bash
bash scripts/run.sh rename /path/to/music/ --pattern "{artist} - {title}"
```

**Output:**
```
Renamed: track07.mp3 → M83 - Midnight City.mp3
Renamed: 01_intro.mp3 → M83 - Intro.mp3
Renamed: song.mp3 → M83 - Wait.mp3
Processed: 3 files, 0 errors
```

## Core Workflows

### Workflow 1: View & Edit Tags

```bash
# View tags
bash scripts/run.sh info song.mp3

# Set tags
bash scripts/run.sh tag song.mp3 \
  --title "Midnight City" \
  --artist "M83" \
  --album "Hurry Up, We're Dreaming" \
  --year 2011 \
  --track 7 \
  --genre "Electronic"

# Batch tag entire album
bash scripts/run.sh tag /path/to/album/ \
  --artist "M83" \
  --album "Hurry Up, We're Dreaming" \
  --year 2011
```

### Workflow 2: Embed Album Art

```bash
# Embed cover image
bash scripts/run.sh art song.mp3 --set cover.jpg

# Embed art for entire directory
bash scripts/run.sh art /path/to/album/ --set cover.jpg

# Extract existing art
bash scripts/run.sh art song.mp3 --extract cover-output.jpg

# Remove embedded art
bash scripts/run.sh art song.mp3 --remove
```

### Workflow 3: Batch Rename Files

```bash
# Rename by pattern
bash scripts/run.sh rename /path/to/music/ --pattern "{artist} - {title}"

# Include track number
bash scripts/run.sh rename /path/to/music/ --pattern "{track:02d}. {title}"

# Organize into folders
bash scripts/run.sh rename /path/to/music/ \
  --pattern "{artist}/{album}/{track:02d}. {title}" \
  --create-dirs

# Dry run (preview changes)
bash scripts/run.sh rename /path/to/music/ --pattern "{artist} - {title}" --dry-run
```

**Available pattern variables:** `{artist}`, `{title}`, `{album}`, `{year}`, `{track}`, `{genre}`, `{disc}`

### Workflow 4: Export Tags to CSV

```bash
# Export all tags
bash scripts/run.sh export /path/to/music/ --output tags.csv

# Output:
# file,title,artist,album,year,track,genre,duration,bitrate
# song1.mp3,Midnight City,M83,Hurry Up...,2011,7,Electronic,4:03,320
```

### Workflow 5: Find Files with Missing Tags

```bash
# Scan for missing metadata
bash scripts/run.sh scan /path/to/music/

# Output:
# ⚠️  track03.mp3 — missing: title, artist
# ⚠️  unknown.mp3 — missing: title, artist, album, year
# ✅ 48/50 files have complete tags
# ❌ 2 files need attention
```

### Workflow 6: Strip All Tags

```bash
# Remove all metadata (clean slate)
bash scripts/run.sh strip song.mp3

# Strip entire directory
bash scripts/run.sh strip /path/to/music/ --confirm
```

## Configuration

### Environment Variables

```bash
# Default rename pattern
export MUSIC_RENAME_PATTERN="{artist} - {title}"

# Default music directory
export MUSIC_DIR="$HOME/Music"

# Supported extensions (comma-separated)
export MUSIC_EXTENSIONS="mp3,flac,ogg,m4a,wma,aac"
```

## Advanced Usage

### Auto-Tag from Filename

```bash
# If files are named "Artist - Title.mp3", extract tags from name
bash scripts/run.sh autotag /path/to/music/ --from-filename "{artist} - {title}"
```

### Normalize Tag Encoding

```bash
# Fix mojibake/encoding issues in tags
bash scripts/run.sh fix-encoding /path/to/music/
```

### Duplicate Finder

```bash
# Find duplicate tracks by metadata (artist + title)
bash scripts/run.sh dupes /path/to/music/

# Output:
# Duplicate: M83 - Midnight City
#   → /music/album1/track07.mp3 (320kbps)
#   → /music/downloads/midnight_city.mp3 (192kbps)
```

## Troubleshooting

### Issue: "eyeD3 not found"

```bash
pip3 install eyeD3
```

### Issue: "ffprobe not found"

```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg

# Mac
brew install ffmpeg
```

### Issue: Unicode characters in filenames

The tool handles Unicode by default. If you see issues on older systems:

```bash
export LANG=en_US.UTF-8
```

### Issue: Permission denied on rename

```bash
# Check file permissions
ls -la /path/to/music/
# Fix if needed
chmod 644 /path/to/music/*.mp3
```

## Dependencies

- `bash` (4.0+)
- `eyeD3` (Python, for MP3 ID3 tags)
- `ffprobe` (from ffmpeg, for format detection & non-MP3 metadata)
- `python3` (3.6+)
- Optional: `mutagen` (Python, for FLAC/OGG/M4A support)
