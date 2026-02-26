---
name: photo-exif-manager
description: >-
  View, strip, and batch-edit EXIF/GPS metadata from photos using exiftool.
categories: [media, productivity]
dependencies: [exiftool, bash, jq]
---

# Photo EXIF Manager

## What This Does

Manage EXIF metadata across your photo library — view camera settings, strip GPS coordinates for privacy, batch-rename by date, and bulk-edit metadata fields. Uses exiftool under the hood.

**Example:** "Strip GPS data from 500 photos before uploading to a blog. Rename all files by date taken. Extract a CSV of camera settings."

## Quick Start (3 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. View EXIF Data

```bash
bash scripts/run.sh view /path/to/photo.jpg
```

### 3. Strip GPS for Privacy

```bash
bash scripts/run.sh strip-gps /path/to/photos/
```

## Core Workflows

### Workflow 1: View Full EXIF Data

```bash
bash scripts/run.sh view photo.jpg

# Output:
# ━━━ EXIF: photo.jpg ━━━
# Camera:      Canon EOS R5
# Lens:        RF 24-70mm F2.8L
# Date:        2026-02-15 14:32:08
# Exposure:    1/250s  f/2.8  ISO 400
# Resolution:  8192x5464
# GPS:         23.8103°N, 90.4125°E
# File Size:   12.4 MB
```

### Workflow 2: Strip GPS from All Photos (Privacy)

```bash
# Strip GPS from directory (recursive)
bash scripts/run.sh strip-gps /path/to/photos/

# Output:
# [1/142] ✅ Stripped GPS: IMG_0001.jpg
# [2/142] ✅ Stripped GPS: IMG_0002.jpg
# ...
# ━━━ Done: 142 files processed, 138 had GPS data removed ━━━
```

### Workflow 3: Batch Rename by Date Taken

```bash
# Rename files to YYYY-MM-DD_HHMMSS format
bash scripts/run.sh rename-by-date /path/to/photos/

# Output:
# IMG_0001.jpg → 2026-02-15_143208.jpg
# IMG_0002.jpg → 2026-02-15_143215.jpg
# DSC_4521.jpg → 2026-02-14_091022.jpg
# ━━━ Renamed 142 files ━━━
```

### Workflow 4: Export EXIF to CSV

```bash
# Extract key metadata to CSV for analysis
bash scripts/run.sh export-csv /path/to/photos/ > metadata.csv

# Output CSV columns:
# filename,camera,lens,date,exposure,fstop,iso,gps_lat,gps_lon,filesize
```

### Workflow 5: Bulk Set Copyright / Artist

```bash
# Add copyright to all photos
bash scripts/run.sh set-field /path/to/photos/ Copyright "© 2026 Fahim"
bash scripts/run.sh set-field /path/to/photos/ Artist "Fahim"

# Output:
# [1/142] ✅ Set Copyright on IMG_0001.jpg
# ...
```

### Workflow 6: Strip ALL Metadata

```bash
# Remove ALL EXIF/IPTC/XMP (nuclear option — keeps image data only)
bash scripts/run.sh strip-all /path/to/photos/

# Output:
# [1/142] ✅ Stripped all metadata: IMG_0001.jpg (saved 1.2 MB)
# ...
# ━━━ Total space saved: 84.3 MB ━━━
```

### Workflow 7: Find Photos by Camera/Date

```bash
# Find all photos taken with a specific camera
bash scripts/run.sh find-by /path/to/photos/ camera "iPhone 15 Pro"

# Find photos from a specific date range
bash scripts/run.sh find-by /path/to/photos/ date "2026-02-01" "2026-02-28"
```

### Workflow 8: View GPS on Map

```bash
# Extract GPS and generate a Google Maps link
bash scripts/run.sh gps-link photo.jpg

# Output:
# 📍 GPS: 23.8103°N, 90.4125°E
# 🗺️  https://www.google.com/maps?q=23.8103,90.4125
```

## Configuration

### Environment Variables (Optional)

```bash
# Default copyright text for set-field
export EXIF_DEFAULT_COPYRIGHT="© 2026 Your Name"

# Backup originals before modification (default: true)
export EXIF_BACKUP=true

# Supported extensions (default: jpg,jpeg,png,tiff,heic,raw,cr2,nef,arw,dng)
export EXIF_EXTENSIONS="jpg,jpeg,png,heic"
```

## Troubleshooting

### Issue: "exiftool: command not found"

```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: sudo apt-get install -y libimage-exiftool-perl
# Mac: brew install exiftool
# Arch: sudo pacman -S perl-image-exiftool
```

### Issue: "Permission denied" on photos

```bash
# Check file permissions
ls -la /path/to/photos/
# Fix: chmod 644 /path/to/photos/*.jpg
```

### Issue: HEIC files not recognized

```bash
# HEIC support requires exiftool 12.0+
exiftool -ver  # Check version
# Update: sudo apt-get update && sudo apt-get install -y libimage-exiftool-perl
```

## Dependencies

- `exiftool` (libimage-exiftool-perl) — EXIF read/write
- `bash` (4.0+) — script runtime
- `jq` — JSON processing for CSV export
- `bc` — calculations (usually pre-installed)
