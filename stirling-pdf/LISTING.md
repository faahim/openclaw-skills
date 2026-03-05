# Listing Copy: Stirling PDF Server

## Metadata
- **Type:** Skill
- **Name:** stirling-pdf
- **Display Name:** Stirling PDF Server
- **Categories:** [productivity, automation]
- **Icon:** 📄
- **Dependencies:** [docker, curl]

## Tagline

Deploy a self-hosted PDF toolkit — merge, split, compress, OCR, watermark, and 25+ more operations

## Description

Managing PDFs shouldn't require uploading sensitive documents to random websites. Every time you use an online PDF tool, your files pass through someone else's servers — contracts, financial docs, personal records, all of it.

Stirling PDF is a self-hosted PDF processing server with 30+ operations that runs entirely on your machine. Merge, split, compress, rotate, watermark, OCR, convert images to PDF, extract text, add passwords, flatten forms — all through a clean web UI and a full REST API. Your files never leave your server.

**What it does:**
- 📄 Merge, split, rotate, and reorder PDF pages
- 🗜️ Compress PDFs (reduce file size by 50-80%)
- 🔍 OCR scanned documents (make them searchable)
- 💧 Add watermarks (DRAFT, CONFIDENTIAL, custom text)
- 🔒 Encrypt/decrypt PDFs with passwords
- 🖼️ Convert images ↔ PDF (JPG, PNG, TIFF, WebP)
- 📝 Extract text content from any PDF
- 🌐 HTML to PDF conversion
- ✍️ Flatten form fields and add signatures

**Why use this skill:**
- **Privacy-first** — no data leaves your server
- **One-click deploy** — Docker container, running in 3 minutes
- **Full API** — automate PDF processing with curl/scripts
- **Batch processing** — process hundreds of files programmatically

Perfect for developers, sysadmins, and anyone handling sensitive documents who needs reliable PDF tools without third-party services.

## Quick Start Preview

```bash
# Deploy Stirling PDF
bash scripts/deploy.sh

# Merge PDFs via API
curl -X POST http://localhost:8080/api/v1/general/merge-pdfs \
  -F "fileInput=@file1.pdf" -F "fileInput=@file2.pdf" -o merged.pdf

# Compress a large PDF
curl -X POST http://localhost:8080/api/v1/general/compress-pdf \
  -F "fileInput=@large.pdf" -F "optimizeLevel=3" -o compressed.pdf
```

## Core Capabilities

1. Merge PDFs — combine multiple files into one document
2. Split PDFs — extract specific pages or split by page range
3. Compress — reduce file size by 50-80% for email/upload
4. OCR — make scanned documents searchable with Tesseract
5. Watermark — stamp text overlays (DRAFT, CONFIDENTIAL, etc.)
6. Password protection — encrypt/decrypt PDF files
7. Image conversion — convert JPG/PNG ↔ PDF bidirectionally
8. HTML to PDF — render web pages as PDF documents
9. Text extraction — pull text content from any PDF
10. Batch processing — automate with API + shell scripts
11. Self-hosted — Docker deploy, zero cloud dependencies
12. Auto-restart — container restarts on crash/reboot

## Installation Time
**3 minutes** — Run deploy script, start processing
