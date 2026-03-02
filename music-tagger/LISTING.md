# Listing Copy: Music Metadata Tagger

## Metadata
- **Type:** Skill
- **Name:** music-tagger
- **Display Name:** Music Metadata Tagger
- **Categories:** [media, automation]
- **Price:** $10
- **Icon:** 🎵
- **Dependencies:** [python3, mutagen]

## Tagline

"Read, write & batch-edit music file metadata — Rename and organize your library in seconds"

## Description

Managing music file metadata is tedious. Files downloaded from various sources have inconsistent tags, missing album art, and messy filenames. Manually editing tags one by one in a GUI app wastes hours.

Music Metadata Tagger gives your OpenClaw agent full control over music file metadata. Read tags from any format (MP3, FLAC, OGG, M4A, Opus), batch-write tags to entire albums, rename files using tag patterns, organize into Artist/Album folders, extract and embed album art — all from simple commands.

**What it does:**
- 🎵 Read & write ID3/Vorbis/MP4 tags on all major audio formats
- 📝 Batch-tag entire directories with one command
- 📁 Rename files by pattern (e.g., "01 - Title.mp3")
- 🗂️ Organize into Artist/Album folder structures
- 🖼️ Extract & embed album art (JPEG/PNG)
- 🔄 Auto-tag from filename patterns
- 🧹 Strip all metadata for clean files

Perfect for music collectors, DJs, podcast producers, and anyone with a messy music library who wants it organized in minutes, not hours.

## Core Capabilities

1. Multi-format support — MP3, FLAC, OGG, M4A, WAV, AIFF, Opus, WMA
2. Batch tagging — Set artist/album/year/genre on entire directories
3. Smart renaming — Rename files using tag-based patterns with zero-padding
4. Library organizer — Auto-sort into Artist/Album folder hierarchy
5. Album art management — Extract, embed, and replace cover images
6. Auto-tagging — Parse metadata from filename patterns
7. Tag stripping — Clean all metadata from files
8. Directory scanning — Quick overview of all tags in a folder
9. Safe operations — Skips existing files, validates before writing
10. Lightweight — Pure Python (mutagen), no heavy dependencies

## Dependencies
- `python3` (3.8+)
- `mutagen` (pip install)

## Installation Time
**3 minutes** — pip install mutagen, run script
