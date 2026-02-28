# Listing Copy: Calibre Ebook Converter

## Metadata
- **Type:** Skill
- **Name:** calibre-ebook-converter
- **Display Name:** Calibre Ebook Converter
- **Categories:** [media, productivity]
- **Price:** $8
- **Dependencies:** [calibre, bash]
- **Icon:** 📚

## Tagline

Convert ebooks between formats — EPUB, MOBI, PDF, AZW3, and 20+ more

## Description

Tired of hunting for sketchy online converters every time you need an ebook in a different format? This skill installs Calibre's powerful CLI tools and wraps them in simple, agent-friendly commands.

Convert between EPUB, MOBI, PDF, AZW3, DOCX, HTML, TXT, and 20+ formats with a single command. Batch convert entire directories for Kindle, Kobo, or any reader. View and edit metadata — title, author, cover art, tags, series info. Even convert web pages into offline-readable ebooks.

**What it does:**
- 📖 Convert between 20+ ebook formats (EPUB ↔ MOBI ↔ PDF ↔ AZW3 ↔ DOCX)
- 📚 Batch convert entire directories in one command
- ✏️ View and edit metadata (title, author, cover, tags, series)
- 🖼️ Extract or set cover images
- 🌐 Convert web pages to EPUB for offline reading
- ⚡ Custom conversion options (margins, fonts, CSS)
- 🔧 Auto-installs Calibre CLI on Linux, macOS, and more

Perfect for avid readers, writers converting manuscripts, or anyone managing an ebook library.

## Quick Start Preview

```bash
# Convert EPUB to Kindle format
bash scripts/convert.sh book.epub book.mobi

# Batch convert all EPUBs to MOBI
bash scripts/convert.sh --batch ~/Books --format mobi --output ~/Kindle

# View metadata
bash scripts/metadata.sh info book.epub
```

## Core Capabilities

1. Format conversion — EPUB, MOBI, PDF, AZW3, DOCX, HTML, TXT, FB2, and more
2. Batch processing — Convert entire directories with progress tracking
3. Metadata viewing — See title, author, publisher, tags, size at a glance
4. Metadata editing — Set title, author, cover, tags, series, publisher
5. Cover management — Extract or set cover images
6. Web-to-ebook — Save web pages as EPUB for offline reading
7. Custom options — Pass any Calibre conversion flag (margins, fonts, CSS)
8. Auto-install — Detects OS and installs Calibre CLI automatically
9. Format filtering — Batch convert only specific source formats
10. Error handling — Graceful failures with clear error messages

## Dependencies
- `calibre` (auto-installed by scripts/install.sh)
- `bash` (4.0+)

## Installation Time
**5 minutes** — Run install script, start converting
