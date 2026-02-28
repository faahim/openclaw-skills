---
name: duplicate-finder
description: >-
  Find and remove duplicate files to reclaim disk space. Scans directories using
  content hashing, generates reports, and safely removes duplicates.
categories: [automation, productivity]
dependencies: [bash, find, md5sum]
---

# Duplicate File Finder

## What This Does

Scans directories for duplicate files using content-based hashing (not just filenames). Generates detailed reports showing wasted space, lets you review before deleting, and supports dry-run mode. Works on any Linux/macOS system with zero external dependencies.

**Example:** "Scan my Downloads folder, find 2.3GB of duplicates across 847 files, review the report, then clean up."

## Quick Start (2 minutes)

### 1. Scan a Directory

```bash
bash scripts/find-dupes.sh ~/Downloads
```

**Output:**
```
🔍 Scanning ~/Downloads ...
   Found 2,341 files (4.7 GB total)
   Computing checksums...
   ✅ Scan complete!

📊 Results:
   Duplicate groups: 127
   Duplicate files:  389
   Wasted space:     1.8 GB

Report saved to: dupes-report-2026-02-28.txt
```

### 2. Review the Report

```bash
cat dupes-report-2026-02-28.txt
```

### 3. Remove Duplicates (keeps oldest file in each group)

```bash
bash scripts/find-dupes.sh ~/Downloads --delete --keep oldest
```

## Core Workflows

### Workflow 1: Scan and Report (Safe — No Deletions)

```bash
bash scripts/find-dupes.sh /path/to/scan
```

Generates a report file listing all duplicate groups with sizes, paths, and modification times.

### Workflow 2: Scan Multiple Directories

```bash
bash scripts/find-dupes.sh ~/Downloads ~/Documents ~/Pictures
```

Finds duplicates ACROSS directories (e.g., same photo in Downloads and Pictures).

### Workflow 3: Delete Duplicates (Interactive)

```bash
bash scripts/find-dupes.sh ~/Downloads --delete --keep newest --confirm
```

Options for `--keep`:
- `oldest` — Keep the oldest copy (by modification time)
- `newest` — Keep the newest copy
- `first` — Keep the first found (alphabetical path)
- `shortest` — Keep the file with the shortest path

### Workflow 4: Filter by File Type

```bash
# Only images
bash scripts/find-dupes.sh ~/Pictures --ext "jpg,png,gif,webp"

# Only documents
bash scripts/find-dupes.sh ~/Documents --ext "pdf,doc,docx,txt"

# Only videos (large space savings)
bash scripts/find-dupes.sh ~/Videos --ext "mp4,mkv,avi,mov"
```

### Workflow 5: Minimum File Size Filter

```bash
# Only files > 1MB (skip tiny duplicates)
bash scripts/find-dupes.sh ~/Downloads --min-size 1M

# Only files > 100MB (find big space wasters)
bash scripts/find-dupes.sh ~/Downloads --min-size 100M
```

### Workflow 6: Dry Run with Deletion Preview

```bash
bash scripts/find-dupes.sh ~/Downloads --delete --keep oldest --dry-run
```

Shows exactly what WOULD be deleted without touching anything.

### Workflow 7: Export as JSON

```bash
bash scripts/find-dupes.sh ~/Downloads --format json > dupes.json
```

Useful for programmatic processing or feeding into other tools.

## Configuration

### Environment Variables

```bash
# Default report directory (default: current directory)
export DUPES_REPORT_DIR="$HOME/reports"

# Default hash algorithm (md5 is fast, sha256 is more accurate for huge datasets)
export DUPES_HASH_ALGO="md5"  # or sha256

# Exclude hidden files/directories
export DUPES_SKIP_HIDDEN="true"
```

### Exclude Patterns

```bash
# Skip node_modules, .git, etc.
bash scripts/find-dupes.sh ~/Projects --exclude "node_modules,.git,vendor,__pycache__"
```

## Advanced Usage

### Schedule Regular Scans

```bash
# Weekly duplicate scan via cron
0 3 * * 0 cd /path/to/skill && bash scripts/find-dupes.sh /home/user --min-size 1M --format json >> /var/log/dupes-weekly.json
```

### Pipe to Other Tools

```bash
# Count total wasted space
bash scripts/find-dupes.sh ~/Downloads --format json | jq '[.groups[].wasted_bytes] | add' | numfmt --to=iec

# Get just the files to delete
bash scripts/find-dupes.sh ~/Downloads --delete --keep oldest --dry-run --format paths-only
```

### Compare Two Directories

```bash
# Find files in backup that already exist in main
bash scripts/find-dupes.sh ~/main-photos ~/backup-photos --cross-only
```

`--cross-only` shows only duplicates that span both directories (ignores duplicates within a single directory).

## Troubleshooting

### Issue: Scan is slow on large directories

**Fix:** Use `--min-size` to skip small files, or `--ext` to filter by type:
```bash
bash scripts/find-dupes.sh /data --min-size 10M
```

The tool uses a two-pass approach: first groups by file size (instant), then hashes only size-matched files.

### Issue: Permission denied errors

**Fix:** Run with appropriate permissions or skip unreadable files:
```bash
bash scripts/find-dupes.sh /data 2>/dev/null
```

### Issue: Want to use jdupes/fdupes instead

If `jdupes` or `fdupes` is installed, the script auto-detects and uses them for faster scanning. Install:
```bash
# Ubuntu/Debian
sudo apt-get install jdupes  # or fdupes

# Mac
brew install jdupes  # or fdupes
```

## How It Works

1. **Size grouping** — Files with unique sizes can't be duplicates (instant filter)
2. **Partial hash** — Hash first 4KB of size-matched files (fast filter)
3. **Full hash** — Hash entire file only for partial-hash matches (accurate)
4. **Report** — Group duplicates, calculate wasted space, generate report

This 3-stage approach makes scanning 100K+ files fast even without jdupes.

## Dependencies

- `bash` (4.0+)
- `find` (standard)
- `md5sum` or `md5` (standard on Linux/macOS)
- `stat` (standard)
- `sort`, `awk`, `wc` (standard)
- Optional: `jdupes` or `fdupes` (faster, auto-detected)
- Optional: `jq` (for JSON output)
