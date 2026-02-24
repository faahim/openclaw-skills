# Listing Copy: Tesseract OCR Tool

## Metadata
- **Type:** Skill
- **Name:** tesseract-ocr
- **Display Name:** Tesseract OCR Tool
- **Categories:** [data, productivity]
- **Price:** $10
- **Dependencies:** [tesseract-ocr, imagemagick, poppler-utils]

## Tagline

Extract text from images and scanned PDFs — batch OCR with preprocessing

## Description

AI agents can't read text from images or scanned PDFs natively. When you need to extract text from screenshots, receipts, scanned contracts, or photo documents, you need real OCR software.

Tesseract OCR Tool installs and runs Google's Tesseract OCR engine through your OpenClaw agent. Single images, multi-page PDFs, or entire folders — it handles them all with automatic preprocessing for maximum accuracy. No cloud API, no per-page fees, runs entirely on your machine.

**What it does:**
- 📸 OCR images: PNG, JPG, TIFF, BMP, WebP, GIF
- 📄 Extract text from scanned/image PDFs (multi-page)
- 📁 Batch process entire folders with parallel execution
- 🔧 Auto-preprocess: deskew, denoise, sharpen, threshold
- 📊 Output as plain text, JSON (with confidence), hOCR, or searchable PDF
- 🌍 100+ languages supported (install additional packs)
- 🔤 Character whitelisting (e.g., numbers only for meter readings)
- 📑 Page selection for large PDFs (e.g., pages 1-5,8,12)

Perfect for developers, researchers, and anyone who needs to digitize documents, process receipts, or extract data from screenshots.

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# OCR an image
bash scripts/run.sh --input screenshot.png
# → Extracted 847 characters → screenshot.txt

# OCR a scanned PDF
bash scripts/run.sh --input contract.pdf --output contract.txt
# → 12 pages processed → contract.txt (15,847 chars)

# Batch a folder
bash scripts/run.sh --input ./receipts/ --output ./text/
# → 23/23 files processed, 0 failures
```

## Core Capabilities

1. Image OCR — Extract text from any common image format
2. PDF OCR — Convert scanned PDFs to searchable text (multi-page)
3. Searchable PDF output — Create PDFs with selectable/searchable text layer
4. Batch processing — Process entire directories at once
5. Image preprocessing — Deskew, denoise, threshold for blurry/skewed images
6. JSON output — Structured output with confidence scores
7. 100+ languages — English default, install any Tesseract language pack
8. Character whitelisting — Restrict to specific character sets
9. Page selection — OCR specific pages from large PDFs
10. hOCR output — Structured HTML with word-level bounding boxes
11. Zero cloud dependency — Runs 100% locally, no API costs
12. One-command install — Cross-platform installer (apt, brew, dnf, pacman)

## Dependencies
- `tesseract-ocr` (5.0+)
- `imagemagick`
- `poppler-utils`

## Installation Time
**5 minutes** — Run install.sh, start OCR-ing

## Pricing Justification

**Why $10:**
- LarryBrain median: $10-15
- Cloud OCR alternatives: $1.50-3.00 per 1000 pages (Google Vision, AWS Textract)
- Our advantage: One-time payment, unlimited pages, no per-use fees
- Complexity: Medium (PDF extraction + preprocessing + multi-format output)
