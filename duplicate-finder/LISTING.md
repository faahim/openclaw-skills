# Listing Copy: Duplicate File Finder

## Metadata
- **Type:** Skill
- **Name:** duplicate-finder
- **Display Name:** Duplicate File Finder
- **Categories:** [automation, productivity]
- **Price:** $8
- **Dependencies:** [bash, find, md5sum]

## Tagline

Find and remove duplicate files by content hash — reclaim wasted disk space instantly

## Description

Duplicate files silently eat your disk space. Downloads copied twice, photos synced to multiple folders, backups of backups — it adds up fast. Most people have gigabytes of wasted space they don't know about.

Duplicate File Finder scans your directories using a fast 3-stage hashing approach: first grouping by file size, then partial hashing (first 4KB), then full content hashing. This means only actual candidate duplicates get fully hashed — making it fast even on directories with thousands of files.

**What it does:**
- 🔍 Scan any directory recursively for duplicate files
- ⚡ 3-stage hashing for speed (size → partial → full)
- 📊 Detailed reports with wasted space per group
- 🔗 Deduplicate via hardlinks (zero data loss)
- 🗑️ Safe deletion with dry-run preview
- 🎯 Interactive mode — review each group before acting
- 📋 Export as JSON or CSV for further processing
- 🛡️ Existing hardlinks auto-detected (no false positives)

Perfect for developers cleaning up project directories, photographers managing photo libraries, or anyone wanting to reclaim disk space without risking data loss.

## Core Capabilities

1. Content-based detection — finds duplicates regardless of filename
2. 3-stage hashing — fast scanning without hashing every file
3. Hardlink deduplication — reclaim space with zero data loss
4. Interactive review — choose what to keep per group
5. Dry-run mode — preview all changes before committing
6. JSON/CSV export — pipe results to other tools
7. Cross-directory mode — find files duplicated across locations
8. Size filters — skip tiny files, focus on space hogs
9. Parallel hashing — uses all CPU cores
10. jdupes/fdupes acceleration — auto-uses fast tools if installed

## Dependencies
- `bash` (4.0+), `find`, `md5sum`, `sort`, `stat`
- Optional: `jdupes` or `fdupes` (10-100x faster)

## Installation Time
**2 minutes** — No installation needed, runs immediately
