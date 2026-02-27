---
name: archive-manager
description: >-
  Create, extract, list, encrypt, and batch-process archives in any format — zip, tar.gz, tar.bz2, tar.xz, 7z, rar, zstd.
categories: [automation, productivity]
dependencies: [bash, tar, gzip, p7zip-full, unrar]
---

# Archive Manager

## What This Does

Unified CLI for creating, extracting, listing, testing, and encrypting archives across every common format. Automatically installs missing tools, handles batch operations, and supports password-protected archives. No more remembering tar flags or 7z syntax.

**Example:** "Extract 50 mixed archives into organized folders, encrypt a directory as password-protected 7z, batch-compress a folder tree."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

This auto-detects your OS (Debian/Ubuntu, RHEL/Fedora, Arch, macOS) and installs:
- `p7zip-full` (7z support)
- `unrar` (RAR extraction)
- `zstd` (Zstandard compression)
- `xz-utils` (XZ compression)

### 2. Create an Archive

```bash
# Zip a directory
bash scripts/run.sh create mybackup.tar.gz ~/Documents

# 7z with password
bash scripts/run.sh create secret.7z ~/private --password "hunter2"

# Zstandard (fastest compression)
bash scripts/run.sh create fast.tar.zst ~/data
```

### 3. Extract an Archive

```bash
# Auto-detects format
bash scripts/run.sh extract mybackup.tar.gz

# Extract to specific directory
bash scripts/run.sh extract secret.7z --output ~/restored --password "hunter2"

# Extract RAR
bash scripts/run.sh extract game.rar --output ~/games
```

## Core Workflows

### Workflow 1: Create Archives (Any Format)

```bash
# tar.gz (most common)
bash scripts/run.sh create backup.tar.gz /path/to/files

# tar.bz2 (better compression, slower)
bash scripts/run.sh create backup.tar.bz2 /path/to/files

# tar.xz (best compression, slowest)
bash scripts/run.sh create backup.tar.xz /path/to/files

# tar.zst (fast + good compression, modern)
bash scripts/run.sh create backup.tar.zst /path/to/files

# zip (cross-platform compatible)
bash scripts/run.sh create backup.zip /path/to/files

# 7z (best ratio overall)
bash scripts/run.sh create backup.7z /path/to/files
```

### Workflow 2: Extract Any Archive

```bash
# Auto-detects format from extension
bash scripts/run.sh extract archive.tar.gz
bash scripts/run.sh extract archive.zip
bash scripts/run.sh extract archive.7z
bash scripts/run.sh extract archive.rar
bash scripts/run.sh extract archive.tar.xz
bash scripts/run.sh extract archive.tar.zst
```

### Workflow 3: List Contents Without Extracting

```bash
bash scripts/run.sh list archive.7z
bash scripts/run.sh list backup.tar.gz
bash scripts/run.sh list files.zip
```

### Workflow 4: Test Archive Integrity

```bash
bash scripts/run.sh test backup.7z
# Output: ✅ Archive OK — 142 files verified
# or:     ❌ Archive CORRUPT — CRC mismatch in 3 files
```

### Workflow 5: Encrypted Archives

```bash
# Create encrypted 7z (AES-256)
bash scripts/run.sh create secrets.7z ~/sensitive --password "strong-pass-here"

# Create encrypted zip (ZipCrypto — less secure but more compatible)
bash scripts/run.sh create secrets.zip ~/sensitive --password "strong-pass-here"

# Extract with password
bash scripts/run.sh extract secrets.7z --password "strong-pass-here"
```

### Workflow 6: Batch Operations

```bash
# Extract all archives in a directory
bash scripts/run.sh batch-extract ~/downloads --output ~/extracted

# Compress multiple directories individually
bash scripts/run.sh batch-create ~/projects --format tar.gz --output ~/backups
# Creates: project1.tar.gz, project2.tar.gz, ...

# Test all archives in a directory
bash scripts/run.sh batch-test ~/backups
```

### Workflow 7: Convert Between Formats

```bash
# Convert rar to 7z
bash scripts/run.sh convert old-archive.rar --to 7z

# Convert tar.gz to tar.zst (recompress with zstd)
bash scripts/run.sh convert backup.tar.gz --to tar.zst
```

## Advanced Usage

### Split Large Archives

```bash
# Create 100MB split archive
bash scripts/run.sh create bigbackup.7z ~/data --split 100m
# Output: bigbackup.7z.001, bigbackup.7z.002, ...
```

### Exclude Patterns

```bash
bash scripts/run.sh create backup.tar.gz ~/project \
  --exclude "node_modules" \
  --exclude "*.log" \
  --exclude ".git"
```

### Compression Level

```bash
# Fast compression (level 1)
bash scripts/run.sh create fast.7z ~/data --level 1

# Maximum compression (level 9)
bash scripts/run.sh create tiny.7z ~/data --level 9
```

### Dry Run

```bash
# Preview what would be archived without creating it
bash scripts/run.sh create backup.tar.gz ~/project --dry-run
```

## Troubleshooting

### Issue: "7z: command not found"

```bash
bash scripts/install.sh
# Or manually: sudo apt install p7zip-full
```

### Issue: "unrar: command not found"

```bash
bash scripts/install.sh
# Or manually: sudo apt install unrar
```

### Issue: Cannot extract password-protected archive

Make sure you pass `--password` flag:
```bash
bash scripts/run.sh extract file.7z --password "yourpassword"
```

### Issue: Corrupt archive

Test it first:
```bash
bash scripts/run.sh test file.7z
```

## Supported Formats

| Format | Create | Extract | Encrypt | Notes |
|--------|--------|---------|---------|-------|
| tar.gz | ✅ | ✅ | ❌ | Most universal |
| tar.bz2 | ✅ | ✅ | ❌ | Better ratio than gz |
| tar.xz | ✅ | ✅ | ❌ | Best tar compression |
| tar.zst | ✅ | ✅ | ❌ | Fast + good ratio |
| zip | ✅ | ✅ | ✅ | Cross-platform |
| 7z | ✅ | ✅ | ✅ | Best overall ratio |
| rar | ❌ | ✅ | ✅ | Extract only (proprietary) |

## Dependencies

- `bash` (4.0+)
- `tar` (GNU tar)
- `gzip`, `bzip2`, `xz-utils` (tar compression)
- `zstd` (Zstandard)
- `p7zip-full` (7z format)
- `zip`, `unzip` (zip format)
- `unrar` (RAR extraction)
