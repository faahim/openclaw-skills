# Listing Copy: Archive Manager

## Metadata
- **Type:** Skill
- **Name:** archive-manager
- **Display Name:** Archive Manager
- **Categories:** [automation, productivity]
- **Price:** $8
- **Dependencies:** [bash, tar, p7zip-full, unrar, zstd]

## Tagline

Universal archive tool — Create, extract, encrypt, and batch-process zip, tar, 7z, rar, and more

## Description

Tired of remembering different flags for tar, 7z, zip, and unrar? Archive Manager gives your OpenClaw agent a single unified interface for every common archive format.

Archive Manager handles creation, extraction, listing, integrity testing, format conversion, and batch operations across 7 archive formats. It auto-installs missing tools for your OS, supports AES-256 encryption for 7z and zip, and processes entire directories of mixed archives in one command.

**What it does:**
- 🗃️ Create archives in any format (tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z)
- 📦 Extract any archive — auto-detects format from extension
- 🔒 Password-protect archives with AES-256 encryption (7z/zip)
- 📋 List contents and test integrity without extracting
- 🔄 Convert between formats (rar→7z, tar.gz→tar.zst, etc.)
- ⚡ Batch operations — extract, create, or test entire directories
- ✂️ Split large archives into manageable chunks
- 🚫 Exclude patterns (node_modules, .git, *.log)

Perfect for developers managing backups, sysadmins archiving logs, or anyone who deals with multiple archive formats regularly.

## Quick Start Preview

```bash
# Install all archive tools
bash scripts/install.sh

# Create a backup
bash scripts/run.sh create backup.tar.gz ~/project --exclude node_modules

# Extract anything
bash scripts/run.sh extract archive.7z --output ~/restored

# Batch extract a downloads folder
bash scripts/run.sh batch-extract ~/downloads --output ~/extracted
```

## Core Capabilities

1. Multi-format support — tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z, rar
2. Auto-format detection — determines format from file extension
3. Encryption — AES-256 for 7z, ZipCrypto for zip
4. Batch extract — process entire directories of mixed archives
5. Batch create — compress all subdirectories individually
6. Integrity testing — verify archives without extracting
7. Format conversion — convert between any supported formats
8. Split archives — break large 7z files into chunks
9. Exclude patterns — skip files/dirs during creation
10. Auto-install — detects OS and installs all dependencies
11. Compression levels — control speed vs. ratio (1-9)
12. Dry run — preview operations before executing

## Dependencies
- `bash` (4.0+), `tar`, `gzip`, `bzip2`, `xz-utils`, `zstd`, `p7zip-full`, `zip`, `unzip`, `unrar`

## Installation Time
**2 minutes** — run install.sh, start archiving
