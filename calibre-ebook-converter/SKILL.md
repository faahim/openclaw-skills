---
name: calibre-ebook-converter
description: >-
  Convert ebooks between formats (EPUB, MOBI, PDF, AZW3, DOCX, TXT, HTML) and manage metadata using Calibre CLI tools.
categories: [media, productivity]
dependencies: [calibre, bash]
---

# Calibre Ebook Converter

## What This Does

Convert ebooks between any format Calibre supports — EPUB ↔ MOBI ↔ PDF ↔ AZW3 ↔ DOCX ↔ TXT ↔ HTML and more. Edit metadata (title, author, cover, tags). Batch convert entire directories. All powered by Calibre's `ebook-convert` and `ebook-meta` CLI tools.

**Example:** "Convert all .epub files in ~/Books to .mobi for Kindle, strip DRM-free metadata, set author name."

## Quick Start (5 minutes)

### 1. Install Calibre

```bash
bash scripts/install.sh
```

This installs Calibre CLI tools (`ebook-convert`, `ebook-meta`, `calibredb`) system-wide.

### 2. Convert a Single File

```bash
bash scripts/convert.sh input.epub output.mobi
```

### 3. Batch Convert a Directory

```bash
bash scripts/convert.sh --batch ~/Books/epub --format mobi --output ~/Books/kindle
```

## Core Workflows

### Workflow 1: Single File Conversion

**Use case:** Convert one ebook to another format.

```bash
# EPUB to MOBI (Kindle)
bash scripts/convert.sh book.epub book.mobi

# EPUB to PDF with custom margins
bash scripts/convert.sh book.epub book.pdf --extra "--pdf-page-margin-top 72 --pdf-page-margin-bottom 72"

# DOCX to EPUB
bash scripts/convert.sh manuscript.docx manuscript.epub

# HTML to EPUB
bash scripts/convert.sh article.html article.epub
```

**Supported formats (input):** EPUB, MOBI, AZW3, PDF, DOCX, ODT, RTF, TXT, HTML, HTMLZ, CBZ, CBR, FB2, LIT, PDB, SNB

**Supported formats (output):** EPUB, MOBI, AZW3, PDF, DOCX, TXT, HTML, HTMLZ, FB2, LRF, OEB, PDB, PMLZ, RB, SNB, TCR, TXTZ, ZIP

### Workflow 2: Batch Conversion

**Use case:** Convert all ebooks in a directory.

```bash
# Convert all EPUBs to MOBI
bash scripts/convert.sh --batch ~/Books --format mobi

# Convert all EPUBs to MOBI, output to specific directory
bash scripts/convert.sh --batch ~/Books --format mobi --output ~/Kindle

# Convert with specific source format filter
bash scripts/convert.sh --batch ~/Books --from epub --format pdf --output ~/PDFs
```

**Output:**
```
[1/5] Converting: The Great Gatsby.epub → mobi ... ✅ (2.3s)
[2/5] Converting: 1984.epub → mobi ... ✅ (1.8s)
[3/5] Converting: Dune.epub → mobi ... ✅ (3.1s)
[4/5] Converting: Neuromancer.epub → mobi ... ✅ (1.5s)
[5/5] Converting: Snow Crash.epub → mobi ... ✅ (2.0s)

✅ Batch complete: 5/5 converted, 0 failed
Output: ~/Kindle/
```

### Workflow 3: View & Edit Metadata

**Use case:** Check or modify ebook metadata (title, author, tags, cover).

```bash
# View metadata
bash scripts/metadata.sh info book.epub

# Set title and author
bash scripts/metadata.sh set book.epub --title "The Great Gatsby" --author "F. Scott Fitzgerald"

# Set cover image
bash scripts/metadata.sh set book.epub --cover cover.jpg

# Add tags
bash scripts/metadata.sh set book.epub --tags "fiction,classic,american"

# Set series info
bash scripts/metadata.sh set book.epub --series "Foundation" --series-index 1

# Extract cover image
bash scripts/metadata.sh extract-cover book.epub cover_output.jpg
```

**View output:**
```
📖 Metadata: The Great Gatsby.epub
   Title:     The Great Gatsby
   Author:    F. Scott Fitzgerald
   Publisher: Scribner
   Date:      1925-04-10
   Language:  en
   Tags:      fiction, classic, american
   Format:    EPUB
   Size:      245 KB
```

### Workflow 4: Batch Metadata Update

**Use case:** Set the same author/publisher across many files.

```bash
# Set author for all EPUBs in a directory
bash scripts/metadata.sh batch ~/Books --author "Author Name"

# Add tags to all files
bash scripts/metadata.sh batch ~/Books --tags "my-collection"
```

### Workflow 5: Convert Web Page to Ebook

**Use case:** Save a web page as an EPUB for offline reading.

```bash
# Fetch URL and convert to EPUB
bash scripts/web-to-ebook.sh "https://example.com/long-article" article.epub

# Fetch with custom title
bash scripts/web-to-ebook.sh "https://example.com/long-article" article.epub --title "Great Article"
```

## Configuration

### Environment Variables

```bash
# Default output format (used when --format not specified in batch)
export CALIBRE_DEFAULT_FORMAT="mobi"

# Default output directory
export CALIBRE_OUTPUT_DIR="$HOME/Converted"

# PDF settings
export CALIBRE_PDF_MARGIN="72"  # points (1 inch = 72 points)
export CALIBRE_PDF_PAPER_SIZE="letter"  # letter, a4, a3, etc.
```

## Advanced Usage

### Custom Conversion Options

Calibre's `ebook-convert` has hundreds of options. Pass them with `--extra`:

```bash
# PDF with custom font size and paper size
bash scripts/convert.sh book.epub book.pdf \
  --extra "--pdf-default-font-size 14 --pdf-page-size a4"

# MOBI with no inline TOC
bash scripts/convert.sh book.epub book.mobi \
  --extra "--no-inline-toc"

# EPUB with custom CSS
bash scripts/convert.sh book.html book.epub \
  --extra "--extra-css style.css"
```

### Calibre Library Management

```bash
# Add book to Calibre library
calibredb add book.epub --library-path ~/CalibreLibrary

# List books in library
calibredb list --library-path ~/CalibreLibrary

# Search library
calibredb search "author:Fitzgerald" --library-path ~/CalibreLibrary

# Export from library
calibredb export 1 --to-dir ~/exports --library-path ~/CalibreLibrary
```

## Troubleshooting

### Issue: "ebook-convert: command not found"

**Fix:** Run the install script:
```bash
bash scripts/install.sh
```

Or install manually:
```bash
# Ubuntu/Debian
sudo apt-get install -y calibre

# Mac
brew install --cask calibre

# Generic Linux (official installer)
sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin
```

### Issue: PDF conversion looks bad

**Fix:** Adjust margins and font size:
```bash
bash scripts/convert.sh book.epub book.pdf \
  --extra "--pdf-default-font-size 12 --pdf-page-margin-top 50 --pdf-page-margin-bottom 50 --pdf-page-margin-left 50 --pdf-page-margin-right 50"
```

### Issue: MOBI file too large

**Fix:** Compress images during conversion:
```bash
bash scripts/convert.sh book.epub book.mobi \
  --extra "--output-profile kindle --transform-css-rules"
```

### Issue: Cover not showing

**Fix:** Set cover explicitly:
```bash
bash scripts/metadata.sh set book.epub --cover cover.jpg
```

## Dependencies

- `calibre` (provides `ebook-convert`, `ebook-meta`, `calibredb`)
- `bash` (4.0+)
- `curl` (for web-to-ebook workflow)
- Optional: `wget` (alternative for web fetching)
