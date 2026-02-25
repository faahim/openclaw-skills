---
name: duplicate-finder
description: >-
  Find and remove duplicate files. Scans directories using checksums, reports wasted disk space, and safely cleans duplicates.
categories: [automation, productivity]
dependencies: [bash, find, sha256sum, awk, sort]
---

# Duplicate File Finder

## What This Does

Scans directories for duplicate files using SHA-256 checksums. Groups identical files, reports total wasted disk space, and lets you safely remove duplicates (keeping one copy). Works on any file type — images, documents, downloads, backups.

**Example:** "Scan ~/Downloads for duplicates, found 47 duplicate groups wasting 2.3 GB, cleaned up with one command."

## Quick Start (2 minutes)

### 1. Scan a Directory

```bash
bash scripts/scan.sh ~/Downloads
```

**Output:**
```
🔍 Scanning /home/user/Downloads...
   Found 1,247 files (4.8 GB total)
   Computing checksums... done (23s)

📊 Duplicate Report:
   47 duplicate groups found
   142 redundant files
   2.3 GB wasted space

Top duplicates by size:
   [1] 847 MB — video-backup.mp4 (3 copies)
   [2] 234 MB — dataset.csv (2 copies)
   [3] 156 MB — presentation.pptx (4 copies)

Full report: /tmp/dupfinder-report-20260225.txt
```

### 2. View Duplicate Details

```bash
bash scripts/scan.sh ~/Downloads --details
```

Shows every duplicate group with full paths:
```
━━━ Group 1 (847 MB × 3 copies, 1.7 GB wasted) ━━━
  KEEP: /home/user/Downloads/video-backup.mp4
  DUP:  /home/user/Downloads/old/video-backup.mp4
  DUP:  /home/user/Downloads/archive/video-backup (1).mp4
```

### 3. Remove Duplicates

```bash
# Dry run first (shows what would be deleted)
bash scripts/clean.sh /tmp/dupfinder-report-20260225.txt --dry-run

# Actually delete (keeps first occurrence, removes rest)
bash scripts/clean.sh /tmp/dupfinder-report-20260225.txt

# Move duplicates to trash instead of deleting
bash scripts/clean.sh /tmp/dupfinder-report-20260225.txt --trash ~/.Trash
```

## Core Workflows

### Workflow 1: Find Duplicates Across Multiple Directories

```bash
bash scripts/scan.sh ~/Downloads ~/Documents ~/Pictures
```

Scans all directories together, finding cross-directory duplicates too.

### Workflow 2: Filter by File Type

```bash
# Only images
bash scripts/scan.sh ~/Pictures --ext "jpg,png,gif,webp"

# Only documents
bash scripts/scan.sh ~/Documents --ext "pdf,docx,xlsx"

# Only videos
bash scripts/scan.sh ~/Videos --ext "mp4,mkv,avi,mov"
```

### Workflow 3: Find Large Duplicates Only

```bash
# Only files > 10 MB
bash scripts/scan.sh ~/Downloads --min-size 10M

# Only files > 100 MB
bash scripts/scan.sh ~/Downloads --min-size 100M
```

### Workflow 4: Scheduled Cleanup

```bash
# Add to crontab — weekly scan of Downloads
echo "0 9 * * 0 bash /path/to/scripts/scan.sh ~/Downloads --min-size 1M > /tmp/weekly-dupes.txt 2>&1" | crontab -

# Or use OpenClaw cron for agent-managed cleanup
```

### Workflow 5: Compare Two Directories

```bash
# Find files that exist in both dirs
bash scripts/scan.sh ~/backup ~/current --cross-only
```

Only reports duplicates that span across different source directories.

## Configuration

### Environment Variables

```bash
# Hash algorithm (default: sha256sum, faster: md5sum)
export DUPFINDER_HASH="sha256sum"

# Max parallel hash jobs (default: 4)
export DUPFINDER_JOBS=4

# Exclude patterns (comma-separated)
export DUPFINDER_EXCLUDE=".git,.DS_Store,node_modules,__pycache__"

# Report output directory
export DUPFINDER_REPORT_DIR="/tmp"
```

### Command Line Options

```
Usage: scan.sh <dir1> [dir2...] [options]

Options:
  --ext <extensions>    Filter by file extensions (comma-separated)
  --min-size <size>     Minimum file size (e.g., 1K, 10M, 1G)
  --max-size <size>     Maximum file size
  --details             Show full paths for all duplicates
  --cross-only          Only show cross-directory duplicates
  --json                Output as JSON
  --hash <algo>         Hash algorithm (sha256sum, md5sum, b2sum)
  --jobs <n>            Parallel hash jobs
  --exclude <pattern>   Exclude glob patterns (comma-separated)
  -o, --output <file>   Output report file path
  -q, --quiet           Minimal output (just summary)
```

## Advanced Usage

### JSON Output for Scripting

```bash
bash scripts/scan.sh ~/Downloads --json > dupes.json
```

```json
{
  "scanned": {"dirs": 1, "files": 1247, "total_bytes": 4800000000},
  "duplicates": {
    "groups": 47,
    "redundant_files": 142,
    "wasted_bytes": 2300000000
  },
  "groups": [
    {
      "hash": "a1b2c3...",
      "size": 847000000,
      "copies": 3,
      "wasted": 1694000000,
      "files": [
        "/home/user/Downloads/video-backup.mp4",
        "/home/user/Downloads/old/video-backup.mp4",
        "/home/user/Downloads/archive/video-backup (1).mp4"
      ]
    }
  ]
}
```

### Integration with OpenClaw Agent

The agent can use this skill to:
1. Scan directories on schedule
2. Report findings via Telegram
3. Auto-clean with confirmation
4. Track space savings over time

```bash
# Agent workflow example
REPORT=$(bash scripts/scan.sh ~/Downloads --min-size 5M --quiet)
# Agent reads report, asks user for confirmation, then cleans
```

## Troubleshooting

### Issue: Scan is very slow

**Fix:** Use faster hash or limit file size:
```bash
# Use MD5 instead of SHA-256 (faster, still reliable for dedup)
bash scripts/scan.sh ~/Downloads --hash md5sum

# Skip small files
bash scripts/scan.sh ~/Downloads --min-size 1M

# Increase parallelism
bash scripts/scan.sh ~/Downloads --jobs 8
```

### Issue: Permission denied errors

**Fix:** Run with appropriate permissions or exclude system dirs:
```bash
bash scripts/scan.sh /home --exclude "/proc,/sys,/dev,/run"
```

### Issue: Too many results

**Fix:** Filter by size or type:
```bash
bash scripts/scan.sh ~/Downloads --min-size 10M --ext "mp4,zip,tar.gz"
```

## Dependencies

- `bash` (4.0+)
- `find` (GNU findutils)
- `sha256sum` or `md5sum` (coreutils)
- `awk` (gawk or mawk)
- `sort`, `uniq`, `wc` (coreutils)
- `numfmt` (coreutils, for human-readable sizes)
- Optional: `parallel` (GNU parallel, for faster hashing)
