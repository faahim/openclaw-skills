# Listing Copy: Music Metadata Manager

## Metadata
- **Type:** Skill
- **Name:** music-metadata
- **Display Name:** Music Metadata Manager
- **Categories:** [media, productivity]
- **Price:** $10
- **Dependencies:** [python3, mutagen, ffprobe]

## Tagline

"Read, write, and batch-edit audio tags — Organize your music library automatically"

## Description

Your music library is a mess. Files named `track01.mp3` with no artist, no album, no genre. Hundreds of songs scattered across random folders. Finding anything means guessing or searching by hand.

Music Metadata Manager reads, writes, and batch-edits ID3/Vorbis/MP4 tags across your entire library. It supports MP3, FLAC, OGG, M4A, WAV, and WMA. One command scans your collection and shows what's missing. Another renames files based on their tags. A third organizes everything into clean `Artist/Album/` folder structures automatically.

**What it does:**
- 📖 Read tags from any audio format (MP3, FLAC, OGG, M4A, WMA, WAV)
- ✏️ Write/edit tags individually or batch-tag entire directories
- 📝 Rename files using tag patterns (`{track:02d} - {title}`)
- 📁 Auto-organize into `Artist/Album/` folder structures
- 🔍 Audit library for missing or incomplete tags
- 💾 Export/import tags as JSON for backup
- 📊 Scan and summarize entire collections
- 🧹 Strip all tags for clean re-tagging

Perfect for music collectors, DJs, podcast producers, and anyone tired of messy audio libraries.

## Quick Start Preview

```bash
# Read tags
python3 scripts/music-meta.py read /path/to/song.mp3

# Batch tag an album
python3 scripts/music-meta.py batch-tag /path/to/album/ --artist "Queen" --album "Greatest Hits"

# Organize into folders
python3 scripts/music-meta.py organize /messy-music/ --dest /organized/ --structure "{artist}/{album}"
```

## Core Capabilities

1. Multi-format support — MP3, FLAC, OGG, M4A, WAV, WMA, Opus
2. Batch tagging — Set artist/album/genre on hundreds of files at once
3. Smart rename — Pattern-based renaming using tag data
4. Auto-organize — Sort files into Artist/Album folder trees
5. Tag audit — Find files with missing or incomplete metadata
6. JSON export/import — Backup and restore your entire tag database
7. CSV import — Bulk-tag from spreadsheets
8. Dry-run mode — Preview all changes before committing
9. Tag stripping — Clean wipe for fresh re-tagging
10. Recursive scanning — Process nested directory trees

## Dependencies
- `python3` (3.8+)
- `mutagen` (pip install mutagen)
- `ffprobe` (optional, for WAV and enhanced info)

## Installation Time
**2 minutes** — pip install mutagen, run script
