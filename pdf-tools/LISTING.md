# Listing Copy: PDF Tools

## Metadata
- **Type:** Skill
- **Name:** pdf-tools
- **Display Name:** PDF Tools
- **Categories:** [productivity, data]
- **Price:** $10
- **Dependencies:** [poppler-utils, ghostscript, qpdf]
- **Icon:** 📄

## Tagline
Merge, split, compress, extract text, rotate, and watermark PDFs — all locally.

## Description

Working with PDFs is one of those tasks that always requires leaving the terminal — downloading some web tool, uploading files to a sketchy converter, or wrestling with Adobe. Your OpenClaw agent can't manipulate PDF files natively, and that's a real bottleneck when you're processing invoices, reports, or contracts.

PDF Tools gives your agent a complete PDF toolkit. Merge multiple files into one, split documents into individual pages, compress oversized PDFs for email, extract text for analysis, rotate pages, pull specific page ranges, and stamp watermarks — all from simple bash commands.

**What it does:**
- 📎 Merge unlimited PDFs into a single file
- ✂️ Split documents into individual page files
- 🗜️ Compress with 4 quality levels (up to 90% size reduction)
- 📝 Extract text from any page range
- 🔄 Rotate pages (90°, 180°, 270°)
- 📑 Extract specific page ranges
- 💧 Add text watermarks (DRAFT, CONFIDENTIAL, etc.)
- ℹ️ Get page count, metadata, and file info

Everything runs locally using proven open-source tools (poppler, ghostscript, qpdf). No cloud uploads, no API keys, no monthly fees.

Perfect for developers, freelancers, and anyone who regularly processes PDF documents.

## Quick Start Preview

```bash
bash scripts/pdf-tools.sh merge report.pdf ch1.pdf ch2.pdf ch3.pdf
# ✅ Merged 3 files → report.pdf (42 pages, 3.2MB)

bash scripts/pdf-tools.sh compress report.pdf small.pdf --quality ebook
# ✅ Compressed: 3.2MB → 0.8MB (75% reduction) → small.pdf
```

## Installation Time
**2 minutes** — Install 3 system packages, run commands.
