---
name: music-metadata
description: >-
  Read, write, and batch-edit audio file metadata (ID3 tags). Rename and organize music files by artist/album/title.
categories: [media, productivity]
dependencies: [python3, pip, ffprobe]
---

# Music Metadata Manager

## What This Does

Read, write, and batch-edit metadata (ID3/Vorbis/FLAC tags) on audio files. Rename and organize music files into `Artist/Album/Title` folder structures automatically. Supports MP3, FLAC, OGG, M4A, WAV, and more.

**Example:** "Tag 200 MP3s with correct artist/album info, then organize them into folders by artist and album."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install mutagen (Python audio metadata library)
pip3 install mutagen

# Verify ffprobe is available (usually comes with ffmpeg)
which ffprobe || echo "Install ffmpeg: sudo apt install ffmpeg (or brew install ffmpeg)"
```

### 2. Read Tags from a File

```bash
python3 scripts/music-meta.py read /path/to/song.mp3
```

**Output:**
```
📄 song.mp3
  Title:   Bohemian Rhapsody
  Artist:  Queen
  Album:   A Night at the Opera
  Year:    1975
  Track:   11
  Genre:   Rock
  Duration: 5:55
  Bitrate: 320 kbps
  Format:  MP3
```

### 3. Write Tags

```bash
python3 scripts/music-meta.py write /path/to/song.mp3 \
  --title "Bohemian Rhapsody" \
  --artist "Queen" \
  --album "A Night at the Opera" \
  --year 1975 \
  --track 11 \
  --genre "Rock"
```

## Core Workflows

### Workflow 1: Read All Tags in a Directory

**Use case:** Audit your music library

```bash
python3 scripts/music-meta.py scan /path/to/music/

# Output: CSV-style summary
# File | Title | Artist | Album | Year | Genre | Duration
```

### Workflow 2: Batch Tag Files

**Use case:** Tag all files in an album folder at once

```bash
python3 scripts/music-meta.py batch-tag /path/to/album/ \
  --artist "Pink Floyd" \
  --album "The Dark Side of the Moon" \
  --year 1973 \
  --genre "Progressive Rock"
```

This sets the shared fields on ALL audio files in the directory. Individual track titles are preserved.

### Workflow 3: Auto-Rename by Tags

**Use case:** Rename files from `track01.mp3` to `01 - Speak to Me.mp3`

```bash
python3 scripts/music-meta.py rename /path/to/album/ \
  --pattern "{track:02d} - {title}"
```

**Patterns available:**
- `{title}` — Track title
- `{artist}` — Artist name
- `{album}` — Album name
- `{year}` — Year
- `{track}` — Track number
- `{track:02d}` — Zero-padded track number
- `{genre}` — Genre

### Workflow 4: Organize into Folders

**Use case:** Sort a messy downloads folder into `Artist/Album/` structure

```bash
python3 scripts/music-meta.py organize /path/to/messy-music/ \
  --dest /path/to/organized/ \
  --structure "{artist}/{album}"
```

**Before:**
```
downloads/
  random_song1.mp3
  another_track.flac
  cool_music.ogg
```

**After:**
```
organized/
  Queen/A Night at the Opera/11 - Bohemian Rhapsody.mp3
  Pink Floyd/The Dark Side of the Moon/01 - Speak to Me.flac
  Radiohead/OK Computer/01 - Airbag.ogg
```

### Workflow 5: Find Missing Tags

**Use case:** Find files with incomplete metadata

```bash
python3 scripts/music-meta.py audit /path/to/music/ \
  --require title,artist,album,year
```

**Output:**
```
⚠️  3 files with missing tags:

  track05.mp3 — missing: title, year
  unknown.flac — missing: artist, album, year
  demo.ogg — missing: title, artist, album, year
```

### Workflow 6: Strip All Tags

**Use case:** Clean files before re-tagging

```bash
python3 scripts/music-meta.py strip /path/to/file.mp3
# Or entire directory:
python3 scripts/music-meta.py strip /path/to/album/ --recursive
```

### Workflow 7: Export Tags to JSON

**Use case:** Backup metadata before editing

```bash
python3 scripts/music-meta.py export /path/to/music/ > metadata-backup.json
```

**Restore later:**
```bash
python3 scripts/music-meta.py import metadata-backup.json
```

## Configuration

### Supported Formats

| Format | Read | Write | Library |
|--------|------|-------|---------|
| MP3    | ✅   | ✅    | mutagen (ID3) |
| FLAC   | ✅   | ✅    | mutagen (VorbisComment) |
| OGG    | ✅   | ✅    | mutagen (VorbisComment) |
| M4A/AAC| ✅   | ✅    | mutagen (MP4) |
| WAV    | ✅   | ❌    | ffprobe (read-only) |
| WMA    | ✅   | ✅    | mutagen (ASF) |

### Environment Variables

```bash
# Optional: default output directory for organize command
export MUSIC_META_OUTPUT="/home/user/Music/Organized"

# Optional: dry-run mode (show what would happen, don't modify files)
export MUSIC_META_DRY_RUN=1
```

## Advanced Usage

### Dry Run Mode

Preview changes without modifying anything:

```bash
python3 scripts/music-meta.py rename /path/to/album/ \
  --pattern "{track:02d} - {title}" \
  --dry-run
```

### Recursive Processing

Process all subdirectories:

```bash
python3 scripts/music-meta.py scan /path/to/music/ --recursive
python3 scripts/music-meta.py audit /path/to/music/ --recursive --require title,artist
```

### Batch Tag from CSV

```bash
# CSV format: filename,title,artist,album,year,track,genre
python3 scripts/music-meta.py csv-import tags.csv
```

## Troubleshooting

### Issue: "ModuleNotFoundError: No module named 'mutagen'"

**Fix:**
```bash
pip3 install mutagen
```

### Issue: "ffprobe not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt install ffmpeg

# Mac
brew install ffmpeg

# Only needed for WAV read and duration/bitrate info
```

### Issue: "Permission denied" on file write

**Fix:** Check file permissions:
```bash
chmod 644 /path/to/song.mp3
```

### Issue: Encoding errors in filenames

**Fix:** Use `--safe-rename` to transliterate unicode:
```bash
python3 scripts/music-meta.py rename /path/ --pattern "{artist} - {title}" --safe-rename
```

## Dependencies

- `python3` (3.8+)
- `mutagen` (pip install)
- `ffprobe` (optional, for WAV and enhanced format info)
