---
name: pdf-tools
description: >-
  Merge, split, compress, extract text, count pages, rotate, and watermark PDFs from the command line.
categories: [productivity, data]
dependencies: [poppler-utils, ghostscript, qpdf]
---

# PDF Tools

## What This Does

A complete PDF toolkit for your OpenClaw agent. Merge multiple PDFs into one, split pages out, compress file size, extract text, rotate pages, add watermarks, and get page counts — all via simple bash commands. No cloud services, no uploads, everything runs locally.

**Example:** "Merge 5 invoices into one PDF, compress it to under 2MB, then extract the text for analysis."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. Try It

```bash
# Merge PDFs
bash scripts/pdf-tools.sh merge output.pdf file1.pdf file2.pdf file3.pdf

# Split a PDF into individual pages
bash scripts/pdf-tools.sh split input.pdf ./pages/

# Compress a PDF (reduce file size)
bash scripts/pdf-tools.sh compress input.pdf output.pdf

# Extract text from a PDF
bash scripts/pdf-tools.sh text input.pdf

# Count pages
bash scripts/pdf-tools.sh pages input.pdf

# Rotate all pages 90° clockwise
bash scripts/pdf-tools.sh rotate input.pdf output.pdf 90

# Extract specific page range
bash scripts/pdf-tools.sh extract input.pdf output.pdf 3-7

# Add text watermark
bash scripts/pdf-tools.sh watermark input.pdf output.pdf "CONFIDENTIAL"
```

## Core Workflows

### Workflow 1: Merge Multiple PDFs

**Use case:** Combine invoices, reports, or documents into a single file.

```bash
bash scripts/pdf-tools.sh merge combined.pdf invoice-jan.pdf invoice-feb.pdf invoice-mar.pdf
```

**Output:**
```
✅ Merged 3 files → combined.pdf (12 pages, 1.2MB)
```

### Workflow 2: Compress for Email

**Use case:** Shrink a large PDF to fit email attachment limits.

```bash
# Standard compression (good quality, smaller size)
bash scripts/pdf-tools.sh compress report.pdf report-small.pdf

# Aggressive compression (lower quality, much smaller)
bash scripts/pdf-tools.sh compress report.pdf report-tiny.pdf --quality screen
```

**Quality levels:**
- `default` — Balanced (default)
- `printer` — High quality print
- `ebook` — Medium quality, good for screens
- `screen` — Lowest quality, smallest size

**Output:**
```
✅ Compressed: 8.5MB → 1.2MB (86% reduction) → report-small.pdf
```

### Workflow 3: Extract Text for Analysis

**Use case:** Pull text from a PDF so the agent can analyze, summarize, or search it.

```bash
# Extract all text
bash scripts/pdf-tools.sh text document.pdf

# Extract text from specific pages
bash scripts/pdf-tools.sh text document.pdf --pages 1-5

# Save to file
bash scripts/pdf-tools.sh text document.pdf > extracted.txt
```

### Workflow 4: Split and Extract Pages

**Use case:** Pull specific pages from a large document.

```bash
# Split into individual page files
bash scripts/pdf-tools.sh split big-doc.pdf ./pages/
# Creates: ./pages/page-001.pdf, ./pages/page-002.pdf, ...

# Extract page range
bash scripts/pdf-tools.sh extract big-doc.pdf chapter3.pdf 15-28
```

### Workflow 5: Watermark Documents

**Use case:** Stamp "DRAFT" or "CONFIDENTIAL" on every page.

```bash
bash scripts/pdf-tools.sh watermark contract.pdf contract-marked.pdf "DRAFT"
```

### Workflow 6: Get PDF Info

**Use case:** Quick stats about a PDF file.

```bash
bash scripts/pdf-tools.sh info document.pdf
```

**Output:**
```
📄 document.pdf
   Pages: 42
   Size: 3.8MB
   Title: Annual Report 2026
   Author: Finance Team
   Created: 2026-01-15
```

## Configuration

### Environment Variables (Optional)

```bash
# Default compression quality
export PDF_TOOLS_QUALITY="ebook"

# Default output directory for splits
export PDF_TOOLS_SPLIT_DIR="./pdf-pages"
```

## Troubleshooting

### Issue: "command not found: gs"

```bash
# Ubuntu/Debian
sudo apt-get install ghostscript

# Mac
brew install ghostscript
```

### Issue: "command not found: pdfunite"

```bash
# Ubuntu/Debian
sudo apt-get install poppler-utils

# Mac
brew install poppler
```

### Issue: "command not found: qpdf"

```bash
# Ubuntu/Debian
sudo apt-get install qpdf

# Mac
brew install qpdf
```

### Issue: Watermark not visible

The watermark uses Ghostscript PostScript overlay. If text doesn't appear, ensure ghostscript is installed and the input PDF isn't encrypted.

## Dependencies

- `poppler-utils` — pdfunite, pdfseparate, pdftotext, pdfinfo
- `ghostscript` (gs) — compression, watermarking
- `qpdf` — page extraction, rotation, encryption
- `bash` (4.0+)
