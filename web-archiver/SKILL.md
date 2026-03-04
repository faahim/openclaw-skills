---
name: web-archiver
description: >-
  Save complete web pages as self-contained HTML files. Archive, organize, search, and manage your saved pages offline.
categories: [data, productivity]
dependencies: [monolith, bash, find, grep]
---

# Web Page Archiver

## What This Does

Save any web page as a single, self-contained HTML file with all CSS, images, and JavaScript embedded inline. No broken links, no missing images — the page works offline forever.

**Example:** "Archive 50 blog posts before they disappear, organize by topic, search through them later."

## Quick Start (5 minutes)

### 1. Install Monolith

```bash
# Run the install script
bash scripts/install.sh
```

### 2. Save Your First Page

```bash
bash scripts/archiver.sh save https://example.com
# Output: Saved → ~/web-archive/2026/03/example.com_2026-03-04_005300.html
```

### 3. Search Your Archive

```bash
bash scripts/archiver.sh search "kubernetes tutorial"
# Searches page titles and content across all archived pages
```

## Core Workflows

### Workflow 1: Save a Single Page

```bash
bash scripts/archiver.sh save https://blog.example.com/great-article

# With custom tags
bash scripts/archiver.sh save https://blog.example.com/great-article --tag dev --tag rust
```

**Output:**
```
🔖 Saving https://blog.example.com/great-article ...
✅ Saved → ~/web-archive/2026/03/blog.example.com_great-article_2026-03-04_120000.html
   Size: 2.4 MB | Tags: dev, rust
   Logged to ~/web-archive/index.tsv
```

### Workflow 2: Batch Archive from a URL List

```bash
# Create a list of URLs
cat urls.txt
# https://page1.com/article
# https://page2.com/tutorial
# https://page3.com/guide

bash scripts/archiver.sh batch urls.txt --tag reference
```

**Output:**
```
📦 Batch archiving 3 URLs...
[1/3] ✅ page1.com/article (1.8 MB)
[2/3] ✅ page2.com/tutorial (3.1 MB)
[3/3] ❌ page3.com/guide (timeout after 30s)
Done: 2 saved, 1 failed
```

### Workflow 3: Search Archived Pages

```bash
# Search by content
bash scripts/archiver.sh search "machine learning"

# Search by domain
bash scripts/archiver.sh search --domain blog.example.com

# Search by tag
bash scripts/archiver.sh search --tag dev

# List recent archives
bash scripts/archiver.sh list --recent 10
```

**Output:**
```
🔍 Found 3 matches for "machine learning":
  1. [2026-03-01] blog.example.com — "Intro to ML" (4.2 MB) [dev, ml]
  2. [2026-02-28] arxiv.org — "Attention Is All You Need" (1.1 MB) [research]
  3. [2026-02-15] medium.com — "ML in Production" (2.8 MB) [dev]
```

### Workflow 4: Archive Management

```bash
# Show archive stats
bash scripts/archiver.sh stats
# Total: 142 pages | 891 MB | 23 domains | Oldest: 2026-01-15

# Export index as JSON
bash scripts/archiver.sh export --format json > archive-index.json

# Remove old archives (older than 90 days)
bash scripts/archiver.sh prune --older-than 90

# Deduplicate (remove duplicate URLs)
bash scripts/archiver.sh dedup
```

## Configuration

### Environment Variables

```bash
# Archive directory (default: ~/web-archive)
export WEB_ARCHIVE_DIR="$HOME/web-archive"

# Timeout per page in seconds (default: 30)
export WEB_ARCHIVE_TIMEOUT=30

# Include JavaScript in archives (default: true)
export WEB_ARCHIVE_JS=true

# User agent for requests
export WEB_ARCHIVE_UA="Mozilla/5.0 (compatible; WebArchiver/1.0)"
```

### Archive Directory Structure

```
~/web-archive/
├── index.tsv              # Tab-separated index of all archives
├── 2026/
│   ├── 01/
│   │   ├── example.com_page_2026-01-15_120000.html
│   │   └── blog.dev_article_2026-01-20_090000.html
│   ├── 02/
│   │   └── ...
│   └── 03/
│       └── ...
└── tags/                  # Symlinks organized by tag
    ├── dev/
    │   ├── example.com_page.html -> ../../2026/01/...
    │   └── ...
    └── research/
        └── ...
```

## Advanced Usage

### Archive with OpenClaw Cron

```bash
# Archive a news site daily
# Add to OpenClaw cron: run every morning
bash scripts/archiver.sh save https://news.ycombinator.com --tag hn-daily
```

### Monitor & Archive on Change

```bash
# Save a page only if it changed since last archive
bash scripts/archiver.sh save https://example.com/status --if-changed
```

### Custom Monolith Options

```bash
# No JavaScript (smaller files, safer)
bash scripts/archiver.sh save https://example.com --no-js

# No images (text-only archive)
bash scripts/archiver.sh save https://example.com --no-images

# Isolate network (no external requests during save)
bash scripts/archiver.sh save https://example.com --isolate
```

## Troubleshooting

### Issue: "monolith: command not found"

**Fix:** Run the install script:
```bash
bash scripts/install.sh
```

Or install manually:
```bash
# Using cargo (if Rust installed)
cargo install monolith

# Using Homebrew (macOS)
brew install monolith

# Using apt (Debian/Ubuntu — may need PPA)
# Download binary from https://github.com/Y2Z/monolith/releases
```

### Issue: Page saves but images are missing

**Check:** Some sites block non-browser user agents.
```bash
# Try with a browser-like user agent
export WEB_ARCHIVE_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
bash scripts/archiver.sh save https://example.com
```

### Issue: Archive files are very large

**Fix:** Disable JavaScript and/or images:
```bash
bash scripts/archiver.sh save https://example.com --no-js --no-images
```

### Issue: Timeout on slow pages

**Fix:** Increase timeout:
```bash
export WEB_ARCHIVE_TIMEOUT=60
bash scripts/archiver.sh save https://slow-site.com
```

## Dependencies

- `monolith` (web page archiver — installed via scripts/install.sh)
- `bash` (4.0+)
- `curl` (for connectivity checks)
- `find`, `grep`, `awk` (standard Unix tools)
- Optional: `fzf` (for interactive search)
