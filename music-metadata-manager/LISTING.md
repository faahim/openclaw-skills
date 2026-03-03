# Listing Copy: Music Metadata Manager

## Metadata
- **Type:** Skill
- **Name:** music-metadata-manager
- **Display Name:** Music Metadata Manager
- **Categories:** [media, productivity]
- **Price:** $10
- **Dependencies:** [eyeD3, mutagen, ffprobe, python3, bash]

## Tagline
Tag, organize, and rename audio files — Clean up messy music libraries in minutes

## Description

Messy music libraries with unnamed files, missing tags, and no album art are a pain to manage manually. File-by-file editing in a GUI tagger takes forever, especially with hundreds of tracks.

Music Metadata Manager lets your OpenClaw agent handle it. View, edit, and batch-update ID3 tags on MP3, FLAC, OGG, and M4A files. Embed album art, rename files by metadata patterns like `{artist} - {title}`, export tags to CSV, find duplicates, and scan for missing metadata — all from the command line.

**What it does:**
- 🎵 View and edit metadata tags (title, artist, album, year, genre, track)
- 🖼️ Embed, extract, or remove album art
- 📁 Batch rename files by metadata pattern (`{artist}/{album}/{track}. {title}`)
- 📊 Export all tags to CSV for analysis
- 🔍 Scan for missing tags and find duplicate tracks
- 🏷️ Auto-tag files by extracting metadata from filenames
- 🧹 Strip all metadata for a clean slate

Perfect for music collectors, podcast producers, DJs, and anyone with a disorganized audio library.

## Quick Start Preview

```bash
# View tags
bash scripts/run.sh info song.mp3

# Batch rename by metadata
bash scripts/run.sh rename ~/Music/ --pattern "{artist} - {title}" --dry-run

# Embed album art
bash scripts/run.sh art ~/Music/album/ --set cover.jpg
```

## Core Capabilities

1. Tag viewing — Display all metadata fields for any audio file
2. Tag editing — Set title, artist, album, year, genre, track on single or batch files
3. Album art management — Embed, extract, or remove cover images
4. Pattern-based renaming — Rename files using `{artist}`, `{title}`, `{album}`, `{track}` variables
5. Directory organization — Create folder structures from metadata (`{artist}/{album}/`)
6. CSV export — Export entire library's tags for spreadsheet analysis
7. Missing tag scanner — Find files with incomplete metadata
8. Duplicate finder — Detect duplicate tracks by artist + title match
9. Auto-tagger — Extract tags from structured filenames
10. Multi-format — Supports MP3, FLAC, OGG, M4A, WMA, AAC

## Dependencies
- `python3` (3.6+)
- `mutagen` (Python library)
- `eyeD3` (Python library)
- `ffprobe` (optional, from ffmpeg)
- `bash` (4.0+)

## Installation Time
**5 minutes** — Run install script, start tagging
