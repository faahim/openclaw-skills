# Listing Copy: Web Page Archiver

## Metadata
- **Type:** Skill
- **Name:** web-archiver
- **Display Name:** Web Page Archiver
- **Categories:** [data, productivity]
- **Price:** $10
- **Dependencies:** [monolith, bash, curl]

## Tagline

Save complete web pages as single HTML files — Never lose a page to link rot

## Description

Web pages disappear. Blogs shut down, articles get paywalled, documentation moves. By the time you need that tutorial you bookmarked, it's gone.

Web Page Archiver uses monolith to save complete web pages as single, self-contained HTML files — all CSS, images, fonts, and JavaScript baked into one file. No broken images, no missing styles. The page works offline, forever.

**What it does:**
- 🔖 Save any URL as a complete, self-contained HTML file
- 📦 Batch archive from URL lists (save 100 pages in one command)
- 🔍 Search through archived pages by content, domain, or tags
- 🏷️ Tag and organize archives with automatic directory structure
- 📊 Track archive stats — total pages, size, top domains
- 🔄 Dedup and prune — keep your archive clean
- ⏱️ Change detection — only re-archive if content changed
- 📤 Export index as JSON/CSV for analysis

**Perfect for:** Developers saving documentation, researchers collecting references, anyone who's lost an important page to the internet's memory hole.

## Quick Start Preview

```bash
# Save a page
bash scripts/archiver.sh save https://example.com/tutorial --tag dev

# Search archives
bash scripts/archiver.sh search "kubernetes"

# Batch save from a list
bash scripts/archiver.sh batch urls.txt --tag reference
```

## Core Capabilities

1. Single-file archives — Complete pages in one HTML file (images, CSS, JS embedded)
2. Batch archiving — Save hundreds of URLs from a text file
3. Full-text search — Find pages by content, title, domain, or tags
4. Tag system — Organize with tags, browse via tag directories
5. Change detection — Re-archive only when content changes
6. Date-based organization — Auto-sorted by year/month
7. Index tracking — TSV index of all archives with metadata
8. Prune & dedup — Clean up old or duplicate archives
9. JSON/CSV export — Export archive index for analysis
10. Auto-install — One-command monolith installation for Linux/macOS

## Dependencies
- `monolith` (auto-installed via scripts/install.sh)
- `bash` (4.0+)
- `curl`

## Installation Time
**5 minutes** — Run install script, start archiving
