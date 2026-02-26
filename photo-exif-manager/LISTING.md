# Listing Copy: Photo EXIF Manager

## Metadata
- **Type:** Skill
- **Name:** photo-exif-manager
- **Display Name:** Photo EXIF Manager
- **Categories:** [media, productivity]
- **Price:** $8
- **Dependencies:** [exiftool, bash, jq]
- **Icon:** 📷

## Tagline

"View, strip, and batch-edit photo EXIF metadata — protect privacy, organize by date"

## Description

Your photos carry hidden data — camera model, GPS coordinates, timestamps, even serial numbers. Before uploading photos online, you should strip this data. Doing it manually is tedious, especially for large batches.

Photo EXIF Manager gives your OpenClaw agent full control over photo metadata using exiftool. View camera settings, strip GPS coordinates from hundreds of photos at once, batch-rename by date taken, export metadata to CSV, and bulk-set copyright fields.

**What it does:**
- 📷 View full EXIF data (camera, lens, exposure, GPS, resolution)
- 🔒 Strip GPS coordinates for privacy (batch — entire directories)
- 📅 Rename photos by date taken (YYYY-MM-DD_HHMMSS format)
- 📊 Export metadata to CSV for analysis
- ✏️ Bulk-set copyright, artist, and other fields
- 🗑️ Strip ALL metadata (nuclear option — saves disk space)
- 🔍 Find photos by camera model or date range
- 🗺️ Generate Google Maps links from photo GPS data

Perfect for photographers, bloggers, content creators, and anyone who cares about privacy when sharing photos online.

## Quick Start Preview

```bash
# Install exiftool
bash scripts/install.sh

# View EXIF data
bash scripts/run.sh view photo.jpg

# Strip GPS from entire directory
bash scripts/run.sh strip-gps ~/Photos/upload/
```

## Core Capabilities

1. EXIF viewer — Camera, lens, exposure, ISO, GPS, resolution at a glance
2. GPS stripping — Remove location data from batches of photos
3. Date-based renaming — Organize files as YYYY-MM-DD_HHMMSS
4. CSV export — Extract metadata for spreadsheet analysis
5. Bulk field editing — Set copyright, artist across libraries
6. Full metadata strip — Remove all EXIF/IPTC/XMP, save disk space
7. Camera search — Find all photos from a specific camera model
8. Date search — Filter photos by date range
9. GPS map links — Quick Google Maps links from photo coordinates
10. Auto-backup — Optionally keeps originals before modification
