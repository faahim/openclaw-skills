---
name: duplicate-finder
description: >-
  Find and remove duplicate files by content hash. Reclaim disk space fast.
categories: [automation, productivity]
dependencies: [bash, find, md5sum, sort]
---

# Duplicate File Finder

## What This Does

Scans directories for duplicate files by computing content hashes (MD5/SHA256). Identifies wasted disk space from identical files regardless of filename. Generates reports, offers interactive or automatic deduplication via hardlinks, symlinks, or deletion.

**Example:** "Scan ~/Downloads for duplicates, found 2.3 GB of wasted space across 847 duplicate files."

## Quick Start (2 minutes)

### 1. Scan a Directory

```bash
bash scripts/find-duplicates.sh ~/Downloads
```

**Output:**
```
🔍 Scanning ~/Downloads ...
📊 Scanned 3,247 files (12.4 GB)
🔴 Found 847 duplicate files in 312 groups
💾 Wasted space: 2.3 GB

Top duplicate groups:
  1. [4 copies] photo_2024.jpg (18.2 MB each) → 54.6 MB wasted
  2. [3 copies] backup.tar.gz (42.1 MB each) → 84.2 MB wasted
  3. [7 copies] logo.png (1.2 MB each) → 7.2 MB wasted

Full report: /tmp/duplicates-report-20260301.txt
```

### 2. Install Optional Tools (Faster Scanning)

```bash
# For 10-100x faster scanning on large directories
# Ubuntu/Debian
sudo apt-get install -y jdupes

# Mac
brew install jdupes

# Or use fdupes (slower but widely available)
sudo apt-get install -y fdupes
```

If jdupes/fdupes are not installed, the skill falls back to a pure bash implementation using md5sum.

## Core Workflows

### Workflow 1: Find Duplicates (Report Only)

```bash
# Scan directory, just report — no changes
bash scripts/find-duplicates.sh ~/Pictures

# Scan multiple directories
bash scripts/find-duplicates.sh ~/Downloads ~/Documents ~/Desktop

# Scan with minimum file size (ignore small files)
bash scripts/find-duplicates.sh --min-size 1M ~/Downloads

# Include hidden files
bash scripts/find-duplicates.sh --hidden ~/Documents
```

### Workflow 2: Interactive Cleanup

```bash
# Review each duplicate group and choose what to keep
bash scripts/find-duplicates.sh --interactive ~/Downloads
```

**Interactive output:**
```
--- Group 1 of 312 (3 files, 54.6 MB wasted) ---
  [1] ~/Downloads/photo_2024.jpg (2024-03-15 14:22)
  [2] ~/Downloads/old/photo_2024.jpg (2024-01-10 09:15)
  [3] ~/Downloads/backup/photo_2024.jpg (2024-02-28 18:40)

Keep which? (1/2/3/all/skip) >
```

### Workflow 3: Auto-Deduplicate with Hardlinks

```bash
# Replace duplicates with hardlinks (saves space, zero data loss risk)
bash scripts/find-duplicates.sh --action hardlink ~/Pictures

# Output:
# ✅ Replaced 847 duplicates with hardlinks
# 💾 Reclaimed: 2.3 GB
```

### Workflow 4: Dry Run Deletion

```bash
# See what WOULD be deleted (keeps newest file in each group)
bash scripts/find-duplicates.sh --action delete --dry-run ~/Downloads

# Actually delete (keeps newest)
bash scripts/find-duplicates.sh --action delete --keep newest ~/Downloads
```

### Workflow 5: Export Report

```bash
# JSON report for processing
bash scripts/find-duplicates.sh --format json ~/Downloads > duplicates.json

# CSV report
bash scripts/find-duplicates.sh --format csv ~/Downloads > duplicates.csv
```

## Configuration

### Command-Line Options

```
Usage: find-duplicates.sh [OPTIONS] DIRECTORY [DIRECTORY...]

Options:
  --min-size SIZE      Minimum file size (e.g., 1K, 1M, 1G). Default: 1 byte
  --max-size SIZE      Maximum file size
  --hidden             Include hidden files/directories
  --follow-links       Follow symbolic links
  --exclude PATTERN    Exclude files matching glob pattern (repeatable)
  --hash ALGO          Hash algorithm: md5 (default), sha256, sha1
  --action ACTION      What to do: report (default), hardlink, symlink, delete
  --keep STRATEGY      Which file to keep: newest (default), oldest, shortest-path
  --dry-run            Show what would happen without making changes
  --interactive        Review each group interactively
  --format FORMAT      Output format: text (default), json, csv
  --output FILE        Write report to file instead of stdout
  -j, --jobs N         Parallel hashing jobs (default: nproc)
  -q, --quiet          Only output summary
  -v, --verbose        Show each file being hashed
```

### Environment Variables

```bash
# Default hash algorithm
export DUPFINDER_HASH="md5"

# Default minimum size
export DUPFINDER_MIN_SIZE="1K"

# Default action
export DUPFINDER_ACTION="report"
```

## Advanced Usage

### Schedule Regular Scans

```bash
# Add to crontab — weekly scan, email report
0 3 * * 0 bash /path/to/scripts/find-duplicates.sh --format text --quiet ~/Downloads ~/Documents > /tmp/weekly-dupes.txt 2>&1
```

### Pipe to Other Tools

```bash
# Find duplicates and delete interactively with fzf
bash scripts/find-duplicates.sh --format json ~/Downloads | jq -r '.groups[].files[1:][]' | fzf --multi | xargs rm -v

# Count wasted space per directory
bash scripts/find-duplicates.sh --format json ~/Home | jq '[.groups[].wasted_bytes] | add'
```

### Compare Two Directories

```bash
# Find files that exist in both dirs (cross-directory duplicates only)
bash scripts/find-duplicates.sh --cross-only ~/Downloads ~/Backup
```

## How It Works

1. **Size grouping** — Groups files by size (different sizes = can't be duplicates)
2. **Partial hash** — Hashes first 4KB of same-size files (fast elimination)
3. **Full hash** — Only fully hashes files with matching partial hashes
4. **Reporting** — Groups duplicates, calculates wasted space, outputs report

This 3-stage approach means most files are never fully hashed, making it fast even on large directories.

## Troubleshooting

### Issue: "Permission denied" errors

```bash
# Run with sudo for system-wide scan, or skip unreadable:
bash scripts/find-duplicates.sh --exclude '/proc/*' --exclude '/sys/*' /
```

### Issue: Very slow on large directories

```bash
# Use jdupes (much faster) or increase min-size to skip small files:
bash scripts/find-duplicates.sh --min-size 100K ~/Pictures
```

### Issue: False positives with hardlinks

The script automatically detects and skips existing hardlinks (same inode). No risk of flagging hardlinks as duplicates.

## Dependencies

- `bash` (4.0+)
- `find`, `md5sum`/`shasum`, `sort`, `stat` (standard on Linux/Mac)
- Optional: `jdupes` or `fdupes` (10-100x faster)
- Optional: `jq` (for JSON output processing)
