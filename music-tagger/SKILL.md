---
name: music-tagger
description: >-
  Read, write, and batch-edit music file metadata (ID3/Vorbis/MP4 tags). Rename and organize files by tags.
categories: [media, automation]
dependencies: [python3, pip, mutagen, eyeD3]
---

# Music Metadata Tagger

## What This Does

Read, write, and batch-edit metadata tags on music files (MP3, FLAC, OGG, M4A, WAV). Rename files based on tags, organize into Artist/Album folder structures, extract embedded album art, and bulk-tag entire directories.

**Example:** "Tag all MP3s in ~/Music/unsorted with artist=Explosions in the Sky, album=The Earth Is Not a Cold Dead Place, then rename them to 'TrackNumber - Title.mp3' and move into Artist/Album folders."

## Quick Start (3 minutes)

### 1. Install Dependencies

```bash
# Install mutagen (Python metadata library — supports MP3, FLAC, OGG, M4A, WAV, AIFF)
pip3 install --user mutagen eyeD3

# Verify
python3 -c "import mutagen; print(f'mutagen {mutagen.version_string}')"
eyeD3 --version
```

### 2. Read Tags from a File

```bash
bash scripts/music-tagger.sh info ~/Music/song.mp3
```

**Output:**
```
File: song.mp3
Format: MP3 (MPEG-1 Layer 3)
Duration: 4:32
Bitrate: 320 kbps
Artist: Explosions in the Sky
Album: The Earth Is Not a Cold Dead Place
Title: First Breath After Coma
Track: 3/5
Year: 2003
Genre: Post-Rock
Album Art: Yes (image/jpeg, 45.2 KB)
```

### 3. Write Tags

```bash
# Set individual tags
bash scripts/music-tagger.sh tag ~/Music/song.mp3 \
  --artist "Explosions in the Sky" \
  --album "The Earth Is Not a Cold Dead Place" \
  --title "First Breath After Coma" \
  --track 3 \
  --year 2003 \
  --genre "Post-Rock"

# Batch-tag all files in a directory
bash scripts/music-tagger.sh tag ~/Music/album/ \
  --artist "Mogwai" \
  --album "Young Team" \
  --year 1997 \
  --genre "Post-Rock"
```

## Core Workflows

### Workflow 1: Read All Tags in a Directory

```bash
bash scripts/music-tagger.sh scan ~/Music/album/

# Output (TSV):
# File                          | Artist              | Album                  | Title                    | Track | Year
# 01-first-breath.mp3           | Explosions in the Sky | The Earth Is Not...   | First Breath After Coma  | 1     | 2003
# 02-the-only-moment.mp3        | Explosions in the Sky | The Earth Is Not...   | The Only Moment We...    | 2     | 2003
```

### Workflow 2: Batch Tag Entire Album

```bash
bash scripts/music-tagger.sh tag ~/Music/album/ \
  --artist "Godspeed You! Black Emperor" \
  --album "Lift Your Skinny Fists Like Antennas to Heaven" \
  --year 2000 \
  --genre "Post-Rock"
```

### Workflow 3: Rename Files by Tags

```bash
# Rename files to "TrackNumber - Title.ext"
bash scripts/music-tagger.sh rename ~/Music/album/ --pattern "{track:02d} - {title}"

# Custom patterns:
# {artist} - {title}
# {year} - {album}/{track:02d} - {title}
# {artist}/{album}/{track:02d} - {title}
```

**Before:**
```
xkcd123.mp3
unknown_track_2.mp3
```

**After:**
```
01 - First Breath After Coma.mp3
02 - The Only Moment We Were Alone.mp3
```

### Workflow 4: Organize into Folders

```bash
# Move files into Artist/Album/ structure
bash scripts/music-tagger.sh organize ~/Music/unsorted/ --dest ~/Music/sorted/ \
  --structure "{artist}/{album}"

# Result:
# ~/Music/sorted/Explosions in the Sky/The Earth Is Not a Cold Dead Place/01 - First Breath.mp3
# ~/Music/sorted/Mogwai/Young Team/01 - Yes! I Am a Long Way From Home.mp3
```

### Workflow 5: Extract Album Art

```bash
# Extract embedded cover art
bash scripts/music-tagger.sh art-extract ~/Music/song.mp3 --output cover.jpg

# Extract from all files in directory (saves per-album)
bash scripts/music-tagger.sh art-extract ~/Music/album/ --output-dir ~/Music/covers/
```

### Workflow 6: Embed Album Art

```bash
# Add cover art to a file
bash scripts/music-tagger.sh art-embed ~/Music/album/ --image cover.jpg
```

### Workflow 7: Strip All Tags

```bash
# Remove all metadata from files
bash scripts/music-tagger.sh strip ~/Music/file.mp3

# Batch strip
bash scripts/music-tagger.sh strip ~/Music/directory/
```

### Workflow 8: Auto-Tag from Filename

```bash
# Parse tags from filename pattern
bash scripts/music-tagger.sh auto-tag ~/Music/unsorted/ \
  --from-pattern "{track} - {artist} - {title}"

# Example: "01 - Mogwai - Hunted by a Freak.mp3"
# → track=1, artist=Mogwai, title=Hunted by a Freak
```

## Configuration

### Supported Formats

| Format | Read | Write | Art | Notes |
|--------|------|-------|-----|-------|
| MP3 | ✅ | ✅ | ✅ | ID3v2.3/v2.4 |
| FLAC | ✅ | ✅ | ✅ | Vorbis Comments |
| OGG | ✅ | ✅ | ✅ | Vorbis Comments |
| M4A/AAC | ✅ | ✅ | ✅ | MP4 atoms |
| WAV | ✅ | ✅ | ❌ | ID3 tags |
| AIFF | ✅ | ✅ | ✅ | ID3 tags |
| WMA | ✅ | ✅ | ✅ | ASF metadata |
| Opus | ✅ | ✅ | ✅ | Vorbis Comments |

### Supported Tag Fields

```
--artist       Artist name
--album        Album name
--title        Track title
--track        Track number (or N/TOTAL)
--year         Year
--genre        Genre
--albumartist  Album artist (for compilations)
--disc         Disc number (or N/TOTAL)
--composer     Composer
--comment      Comment
```

### Rename Patterns

```
{artist}       Artist name
{album}        Album name
{title}        Track title
{track}        Track number
{track:02d}    Track number zero-padded (01, 02...)
{year}         Year
{genre}        Genre
{disc}         Disc number
```

## Troubleshooting

### Issue: "mutagen not found"

```bash
pip3 install --user mutagen
# Make sure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Issue: "Permission denied" when renaming

```bash
# Check file permissions
ls -la ~/Music/album/
# Fix if needed
chmod 644 ~/Music/album/*.mp3
```

### Issue: Tags not showing in music player

Some players cache metadata. Try:
1. Remove the file from player library
2. Re-add it
3. Or use `--id3v2` flag for maximum compatibility:
```bash
bash scripts/music-tagger.sh tag file.mp3 --artist "Test" --id3v2
```

## Dependencies

- `python3` (3.8+)
- `mutagen` — Python audio metadata library
- `eyeD3` — ID3 tag editor (optional, for advanced MP3 features)
- `bash` (4.0+)
