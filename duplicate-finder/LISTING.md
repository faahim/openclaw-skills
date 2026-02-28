# Listing Copy: Duplicate File Finder

## Metadata
- **Type:** Skill
- **Name:** duplicate-finder
- **Display Name:** Duplicate File Finder
- **Categories:** [automation, productivity]
- **Price:** $8
- **Dependencies:** [bash, find, md5sum]

## Tagline
Find and remove duplicate files — Reclaim gigabytes of wasted disk space

## Description

Duplicate files silently eat your disk space. Photos copied twice, downloads re-downloaded, backups of backups. Before you know it, you've lost gigabytes to files you already have.

**Duplicate File Finder** scans your directories using content-based hashing to find exact duplicates — regardless of filename. It uses a fast 3-stage approach (size grouping → partial hash → full hash) that handles 100K+ files efficiently, even without specialized tools.

**What it does:**
- 🔍 Scan one or multiple directories for exact duplicates
- 📊 Generate detailed reports with file sizes, paths, and modification times
- 🗑️ Safely remove duplicates with configurable keep rules (oldest, newest, shortest path)
- 🔒 Dry-run mode — see what would be deleted before touching anything
- 🎯 Filter by file type (images, videos, documents) or minimum size
- ⚡ Auto-detects jdupes/fdupes for blazing-fast scans
- 📁 Cross-directory comparison — find duplicates between your main drive and backup

Perfect for developers cleaning up project directories, photographers organizing photo libraries, or anyone who wants to reclaim disk space without risking data loss.

## Quick Start Preview

```bash
# Scan a directory
bash scripts/find-dupes.sh ~/Downloads

# Find only large duplicates
bash scripts/find-dupes.sh ~/Downloads --min-size 10M

# Preview what would be deleted
bash scripts/find-dupes.sh ~/Downloads --delete --keep oldest --dry-run
```

## Core Capabilities

1. Content-based detection — Finds duplicates by file content, not filename
2. 3-stage hashing — Fast scanning: size filter → partial hash → full hash
3. Multiple keep strategies — Keep oldest, newest, first, or shortest path
4. Dry-run mode — Preview deletions before committing
5. File type filtering — Scan only images, videos, documents, etc.
6. Size filtering — Skip small files, focus on big space wasters
7. Cross-directory scan — Find duplicates across multiple directories
8. Exclusion patterns — Skip node_modules, .git, vendor directories
9. Multiple output formats — Text report, JSON, or paths-only for piping
10. Auto-detection — Uses jdupes/fdupes when available for speed
