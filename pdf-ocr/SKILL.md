---
name: pdf-ocr
description: >-
  Make scanned PDFs searchable by adding an invisible text layer using OCR.
categories: [productivity, data]
dependencies: [ocrmypdf, tesseract-ocr, ghostscript]
---

# PDF OCR — Make Scanned PDFs Searchable

## What This Does

Converts scanned PDF documents into searchable PDFs by running OCR (Optical Character Recognition) and embedding an invisible text layer. After processing, you can search, copy text, and index the PDF. Supports 100+ languages, batch processing, and automatic deskewing/cleaning.

**Example:** "OCR a 50-page scanned contract so I can search for 'indemnification' instantly."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. OCR a Single PDF

```bash
bash scripts/run.sh input.pdf output.pdf
```

### 3. OCR All PDFs in a Directory

```bash
bash scripts/run.sh --batch ./scanned-docs/ ./searchable-docs/
```

## Core Workflows

### Workflow 1: Basic OCR

**Use case:** Make a single scanned PDF searchable

```bash
bash scripts/run.sh scan.pdf scan-searchable.pdf
```

**Output:**
```
[PDF-OCR] Processing: scan.pdf
[PDF-OCR] Pages: 12
[PDF-OCR] Language: eng
[PDF-OCR] ✅ Done: scan-searchable.pdf (text layer added, 2.1 MB → 2.3 MB)
```

### Workflow 2: Multi-Language OCR

**Use case:** OCR a document with mixed languages (e.g., English + German)

```bash
bash scripts/run.sh --lang eng+deu contract.pdf contract-searchable.pdf
```

### Workflow 3: Batch Processing

**Use case:** OCR an entire folder of scanned documents

```bash
bash scripts/run.sh --batch --lang eng ./inbox/ ./processed/
```

**Output:**
```
[PDF-OCR] Batch mode: 15 PDFs found in ./inbox/
[PDF-OCR] [1/15] invoice-001.pdf → ✅ (3 pages, 0.8s)
[PDF-OCR] [2/15] contract-draft.pdf → ✅ (24 pages, 4.2s)
[PDF-OCR] [3/15] receipt.pdf → ⏭️ Already has text layer
...
[PDF-OCR] ✅ Complete: 13 processed, 2 skipped (already searchable)
```

### Workflow 4: Clean & Deskew Before OCR

**Use case:** Scanned documents that are slightly rotated or have noise

```bash
bash scripts/run.sh --clean --deskew scan.pdf clean-scan.pdf
```

### Workflow 5: Force Re-OCR

**Use case:** PDF already has a (bad) text layer, replace it

```bash
bash scripts/run.sh --force scan.pdf better-scan.pdf
```

### Workflow 6: Optimize File Size

**Use case:** OCR and compress the output

```bash
bash scripts/run.sh --optimize scan.pdf smaller-scan.pdf
```

### Workflow 7: Extract Text After OCR

**Use case:** Get plain text from a scanned PDF

```bash
bash scripts/run.sh --extract-text scan.pdf
# Outputs text to stdout
```

## Configuration

### Environment Variables

```bash
# Default language (ISO 639-3 code)
export PDF_OCR_LANG="eng"

# Default optimization level (0=none, 1=lossless, 2=lossy, 3=aggressive)
export PDF_OCR_OPTIMIZE=1

# Max parallel jobs for batch mode
export PDF_OCR_JOBS=4

# Skip PDFs that already have text
export PDF_OCR_SKIP_TEXT=true
```

### Supported Languages

Install additional language packs:

```bash
# List installed languages
tesseract --list-langs

# Install more (Ubuntu/Debian)
sudo apt-get install tesseract-ocr-deu  # German
sudo apt-get install tesseract-ocr-fra  # French
sudo apt-get install tesseract-ocr-jpn  # Japanese
sudo apt-get install tesseract-ocr-chi-sim  # Chinese (Simplified)
sudo apt-get install tesseract-ocr-ara  # Arabic
sudo apt-get install tesseract-ocr-hin  # Hindi
sudo apt-get install tesseract-ocr-ben  # Bengali

# Or install ALL languages
sudo apt-get install tesseract-ocr-all
```

## Advanced Usage

### Integrate with OpenClaw Cron

```bash
# Auto-OCR new files every hour
# In OpenClaw cron: run `bash scripts/run.sh --batch ~/Documents/scans/ ~/Documents/searchable/`
```

### Pipe to Other Tools

```bash
# OCR then grep
bash scripts/run.sh --extract-text invoice.pdf | grep -i "total"

# OCR then count pages with text
bash scripts/run.sh scan.pdf /tmp/out.pdf && pdftotext /tmp/out.pdf - | wc -w
```

### Use with Watch Mode

```bash
# Watch a directory for new PDFs and auto-OCR them
bash scripts/run.sh --watch ~/Downloads/ ~/Documents/ocr/
```

## Troubleshooting

### Issue: "ocrmypdf: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
pip install ocrmypdf
sudo apt-get install tesseract-ocr ghostscript
```

### Issue: Poor OCR quality

**Fix:**
1. Use `--clean --deskew` flags for noisy/rotated scans
2. Ensure correct language: `--lang fra` for French docs
3. Check scan resolution (300 DPI minimum recommended)

### Issue: "Unable to determine PDF page count"

**Fix:** PDF may be corrupted. Try:
```bash
# Repair with ghostscript first
gs -o repaired.pdf -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress input.pdf
bash scripts/run.sh repaired.pdf output.pdf
```

### Issue: Slow processing on large PDFs

**Fix:** Use `--jobs` for parallelism:
```bash
bash scripts/run.sh --jobs 8 --batch ./large-docs/ ./output/
```

## Dependencies

- `ocrmypdf` (3.0+) — Core OCR engine wrapper
- `tesseract-ocr` (4.0+) — OCR engine
- `ghostscript` — PDF processing
- `python3` (3.8+) — Runtime for ocrmypdf
- Optional: `pdftotext` (poppler-utils) — For text extraction mode
- Optional: `unpaper` — For advanced image cleaning
