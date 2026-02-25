# Listing Copy: Duplicate File Finder

## Metadata
- **Type:** Skill
- **Name:** duplicate-finder
- **Display Name:** Duplicate File Finder
- **Categories:** [automation, productivity]
- **Price:** $8
- **Dependencies:** [bash, find, sha256sum, awk, sort]

## Tagline
Find and remove duplicate files — Reclaim wasted disk space in seconds

## Description

Duplicate files silently eat your disk space. Downloads folder full of "image (2).png" and "backup_final_FINAL.zip"? Backups with identical files across directories? Without a systematic scanner, you'll never find them all.

Duplicate File Finder scans your directories using SHA-256 checksums, groups identical files, reports exactly how much space is wasted, and safely removes duplicates — keeping one copy of each. No external services, no GUI needed. Just point it at a folder and go.

**What it does:**
- 🔍 Scan any directory (or multiple) for duplicate files
- 📊 Report duplicate groups with wasted space breakdown
- 🧹 Safely remove duplicates (dry-run first, trash or delete)
- 🎯 Filter by file type, size, or cross-directory only
- 📋 JSON output for scripting and agent integration
- ⚡ Parallel checksumming for speed on large directories
- 🔄 Schedule weekly scans via cron

Perfect for developers, sysadmins, and anyone whose Downloads folder has gotten out of control.

## Quick Start Preview

```bash
# Scan for duplicates
bash scripts/scan.sh ~/Downloads

# Output:
# 📊 47 duplicate groups, 142 redundant files, 2.3 GB wasted
# To clean: bash scripts/clean.sh /tmp/dupfinder-report.txt --dry-run
```

## Core Capabilities

1. Directory scanning — Recursively find all files with checksum comparison
2. Size-first optimization — Groups by file size before hashing (10x faster)
3. Multi-directory support — Scan across multiple dirs, find cross-directory dupes
4. File type filtering — Focus on images, videos, documents, or any extension
5. Size thresholds — Skip tiny files, focus on space hogs
6. Safe cleanup — Dry-run mode, trash option, keeps first occurrence
7. JSON output — Pipe results to other tools or agent workflows
8. Parallel hashing — Uses multiple cores for large file sets
9. Cron-ready — Schedule regular scans
10. Zero dependencies — Uses standard Linux tools (coreutils + findutils)
