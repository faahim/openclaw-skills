---
name: tesseract-ocr
description: >-
  Extract text from images, screenshots, and scanned PDFs using Tesseract OCR.
categories: [data, productivity]
dependencies: [tesseract-ocr, imagemagick, poppler-utils]
---

# Tesseract OCR Tool

## What This Does

Extract text from images, screenshots, scanned PDFs, and photos using Tesseract OCR engine. Batch-process folders of images, preprocess for better accuracy, and output to text/JSON/searchable PDF. Agents cannot perform OCR natively — this skill installs and runs real OCR software.

**Example:** "Extract text from 50 receipt photos, output as structured text files."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. OCR a Single Image

```bash
bash scripts/run.sh --input photo.png
# Output: photo.txt (extracted text printed to stdout and saved)
```

### 3. OCR a PDF

```bash
bash scripts/run.sh --input scanned-document.pdf --output result.txt
```

## Core Workflows

### Workflow 1: Extract Text from Image

```bash
bash scripts/run.sh --input screenshot.png

# Output:
# [OCR] Processing: screenshot.png
# [OCR] Language: eng | PSM: 3 | OEM: 3
# [OCR] ✅ Extracted 847 characters → screenshot.txt
```

### Workflow 2: Batch OCR a Folder

```bash
bash scripts/run.sh --input ./receipts/ --output ./text/ --format txt

# Output:
# [OCR] Found 23 files in ./receipts/
# [OCR] ✅ receipt-001.jpg → text/receipt-001.txt (1203 chars)
# [OCR] ✅ receipt-002.png → text/receipt-002.txt (956 chars)
# ...
# [OCR] Done: 23/23 files processed, 0 failures
```

### Workflow 3: OCR Scanned PDF (Multi-page)

```bash
bash scripts/run.sh --input contract.pdf --output contract.txt --dpi 300

# Output:
# [OCR] Extracting pages from contract.pdf (DPI: 300)...
# [OCR] Found 12 pages
# [OCR] Processing page 1/12...
# ...
# [OCR] ✅ All pages merged → contract.txt (15,847 chars)
```

### Workflow 4: Create Searchable PDF

```bash
bash scripts/run.sh --input scanned.pdf --format searchable-pdf --output searchable.pdf

# Output:
# [OCR] Creating searchable PDF from scanned.pdf...
# [OCR] ✅ Searchable PDF → searchable.pdf (12 pages)
```

### Workflow 5: Preprocess for Better Accuracy

```bash
bash scripts/run.sh --input blurry-photo.jpg --preprocess --output result.txt

# Preprocessing: deskew, denoise, threshold, sharpen
# Then OCR on cleaned image
```

### Workflow 6: Non-English OCR

```bash
# Install additional language
bash scripts/install.sh --lang deu  # German
bash scripts/run.sh --input german-doc.png --lang deu
```

## Configuration

### Command-Line Options

```
--input <file|dir>     Input image, PDF, or directory
--output <file|dir>    Output file or directory (default: input name + .txt)
--format <fmt>         Output format: txt (default), json, searchable-pdf, hocr
--lang <code>          Tesseract language code (default: eng)
--dpi <num>            DPI for PDF extraction (default: 300)
--psm <num>            Page segmentation mode (default: 3)
                       3=auto, 6=single block, 7=single line, 8=single word
--preprocess           Apply image preprocessing (deskew, denoise, threshold)
--confidence           Include confidence scores in output
--quiet                Suppress progress output
```

### Page Segmentation Modes (PSM)

| PSM | Use Case |
|-----|----------|
| 3 | Fully automatic (default — best for most documents) |
| 4 | Column text (newspapers, multi-column layouts) |
| 6 | Single uniform block of text |
| 7 | Single line of text |
| 8 | Single word |
| 11 | Sparse text (labels, signs, scattered text) |
| 13 | Raw line — treat image as single text line, no preprocessing |

### JSON Output Format

```bash
bash scripts/run.sh --input receipt.jpg --format json
```

```json
{
  "file": "receipt.jpg",
  "text": "ACME STORE\n123 Main St\nTotal: $42.99",
  "confidence": 91.2,
  "characters": 42,
  "language": "eng",
  "processed_at": "2026-02-24T12:00:00Z"
}
```

## Advanced Usage

### Batch with Parallel Processing

```bash
bash scripts/run.sh --input ./large-folder/ --output ./results/ --parallel 4
```

### OCR Only Specific Pages of PDF

```bash
bash scripts/run.sh --input document.pdf --pages 1-5,8,12 --output partial.txt
```

### Whitelist Characters (Numbers Only)

```bash
bash scripts/run.sh --input meter-reading.jpg --whitelist "0123456789."
```

### Pipe to Other Tools

```bash
# Extract and search
bash scripts/run.sh --input doc.png --quiet | grep "invoice"

# Extract and count words
bash scripts/run.sh --input doc.png --quiet | wc -w
```

## Troubleshooting

### Issue: "tesseract: command not found"

```bash
bash scripts/install.sh
# Or manually:
sudo apt-get install tesseract-ocr  # Ubuntu/Debian
brew install tesseract               # macOS
```

### Issue: Poor accuracy on photos

Use `--preprocess` flag — applies deskew, denoise, and adaptive thresholding:
```bash
bash scripts/run.sh --input blurry.jpg --preprocess
```

### Issue: Non-English text garbled

Install the language pack:
```bash
sudo apt-get install tesseract-ocr-fra  # French
bash scripts/run.sh --input doc.jpg --lang fra
```

### Issue: PDF extraction fails

Ensure poppler-utils is installed:
```bash
sudo apt-get install poppler-utils  # provides pdftoppm
```

## Supported Input Formats

- **Images:** PNG, JPG/JPEG, TIFF, BMP, GIF, WebP
- **Documents:** PDF (scanned/image-based)
- **Batch:** Any directory containing the above formats

## Dependencies

- `tesseract-ocr` (5.0+) — OCR engine
- `imagemagick` — Image preprocessing (deskew, denoise, threshold)
- `poppler-utils` — PDF page extraction (pdftoppm)
- `bash` (4.0+)
