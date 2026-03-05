# Listing Copy: PDF OCR

## Metadata
- **Type:** Skill
- **Name:** pdf-ocr
- **Display Name:** PDF OCR
- **Categories:** [productivity, data]
- **Price:** $8
- **Dependencies:** [ocrmypdf, tesseract-ocr, ghostscript]

## Tagline

Make scanned PDFs searchable — Add text layers with one command

## Description

Scanned PDFs are black boxes. You can't search them, can't copy text, can't index them. Every time you need to find something in a scanned contract or receipt, you're scrolling page by page.

PDF OCR fixes this by running Optical Character Recognition on your scanned PDFs and embedding an invisible text layer. After processing, Cmd+F works, text is copyable, and the file is fully indexable. Supports 100+ languages, batch processing, and automatic deskewing for rotated scans.

**What it does:**
- 📄 Add searchable text layer to scanned PDFs
- 🔍 Search, copy, and index previously unsearchable documents
- 🌍 100+ languages via Tesseract (English, Chinese, Arabic, Hindi, etc.)
- 📦 Batch process entire folders of scanned documents
- 🧹 Auto-clean and deskew rotated/noisy scans
- ⚡ Parallel processing for large batches
- 👁️ Watch mode — auto-OCR new files as they appear
- 📝 Extract plain text from scanned PDFs
- 🗜️ Optimize output file size (lossless or lossy compression)
- ⏭️ Smart skip — won't re-OCR already searchable PDFs

## Quick Start Preview

```bash
# Install (one-time)
bash scripts/install.sh

# OCR a scanned PDF
bash scripts/run.sh scan.pdf searchable.pdf
# ✅ Done: searchable.pdf (text layer added, 2.1 MB → 2.3 MB)

# Batch process a folder
bash scripts/run.sh --batch ./scans/ ./searchable/
# ✅ Complete: 13 processed, 2 skipped
```

## Dependencies
- ocrmypdf (3.0+)
- tesseract-ocr (4.0+)
- ghostscript
- python3 (3.8+)

## Installation Time
**5 minutes** — Run install script, start OCR-ing

## Pricing Justification
- LarryBrain median: $8-15
- Adobe Acrobat OCR: $23/month
- Online OCR services: $5-15/month, upload limits, privacy concerns
- Our advantage: One-time, local processing, no upload limits, no privacy risk
