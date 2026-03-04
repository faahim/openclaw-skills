---
name: gotenberg-pdf
description: >-
  Run a self-hosted PDF generation API — convert HTML, URLs, Markdown, and Office docs to PDF.
categories: [dev-tools, productivity]
dependencies: [bash, docker, curl]
---

# Gotenberg PDF API

## What This Does

Run a self-hosted **Gotenberg** server that converts HTML, URLs, Markdown, and Office documents (docx, xlsx, pptx, odt) to PDF via a simple HTTP API. No cloud services, no API keys — everything runs locally in a Docker container.

**Example:** "Convert this HTML file to PDF" → `curl -F files=@page.html http://localhost:3000/forms/chromium/convert/html -o output.pdf`

## Quick Start (3 minutes)

### 1. Start Gotenberg

```bash
bash scripts/start.sh
```

This pulls and runs the Gotenberg Docker container on port 3000.

### 2. Convert HTML to PDF

```bash
bash scripts/convert.sh --html page.html --output result.pdf
```

### 3. Convert a URL to PDF

```bash
bash scripts/convert.sh --url https://example.com --output page.pdf
```

## Core Workflows

### Workflow 1: HTML to PDF

```bash
# Single file
bash scripts/convert.sh --html report.html --output report.pdf

# With custom page size and margins
bash scripts/convert.sh --html report.html --output report.pdf \
  --paper-width 8.5 --paper-height 11 \
  --margin-top 1 --margin-bottom 1 --margin-left 0.75 --margin-right 0.75

# HTML string (inline)
echo '<h1>Hello World</h1><p>Generated at '$(date)'</p>' > /tmp/test.html
bash scripts/convert.sh --html /tmp/test.html --output hello.pdf
```

### Workflow 2: URL to PDF

```bash
# Capture any webpage as PDF
bash scripts/convert.sh --url https://news.ycombinator.com --output hn.pdf

# With print background (colors, images)
bash scripts/convert.sh --url https://example.com --output page.pdf --print-background

# Wait for page to fully load (useful for JS-heavy sites)
bash scripts/convert.sh --url https://example.com --output page.pdf --wait-delay 3s
```

### Workflow 3: Markdown to PDF

```bash
# Convert Markdown to PDF (rendered via Chromium)
bash scripts/convert.sh --markdown README.md --output readme.pdf
```

### Workflow 4: Office Documents to PDF

```bash
# Word document
bash scripts/convert.sh --office report.docx --output report.pdf

# Spreadsheet
bash scripts/convert.sh --office data.xlsx --output data.pdf

# PowerPoint
bash scripts/convert.sh --office slides.pptx --output slides.pdf

# Multiple files merged into one PDF
bash scripts/convert.sh --office cover.docx chapter1.docx chapter2.docx --output book.pdf --merge
```

### Workflow 5: Merge Multiple PDFs

```bash
bash scripts/merge.sh file1.pdf file2.pdf file3.pdf --output combined.pdf
```

### Workflow 6: Batch Convert

```bash
# Convert all HTML files in a directory
bash scripts/batch.sh --dir ./html-reports --type html --output-dir ./pdfs

# Convert all docx files
bash scripts/batch.sh --dir ./documents --type docx --output-dir ./pdfs
```

## Direct API Usage

Gotenberg exposes a REST API on `http://localhost:3000`. Use curl directly:

```bash
# HTML to PDF
curl -f -X POST http://localhost:3000/forms/chromium/convert/html \
  -F files=@index.html \
  -o output.pdf

# URL to PDF
curl -f -X POST http://localhost:3000/forms/chromium/convert/url \
  -F url=https://example.com \
  -o output.pdf

# Office to PDF (LibreOffice engine)
curl -f -X POST http://localhost:3000/forms/libreoffice/convert \
  -F files=@document.docx \
  -o output.pdf

# Merge PDFs
curl -f -X POST http://localhost:3000/forms/pdfengines/merge \
  -F files=@file1.pdf \
  -F files=@file2.pdf \
  -o merged.pdf

# With options (paper size, margins, landscape)
curl -f -X POST http://localhost:3000/forms/chromium/convert/html \
  -F files=@page.html \
  -F paperWidth=8.27 \
  -F paperHeight=11.69 \
  -F marginTop=1 \
  -F marginBottom=1 \
  -F landscape=true \
  -o output.pdf
```

## Server Management

```bash
# Start server
bash scripts/start.sh

# Stop server
bash scripts/stop.sh

# Restart
bash scripts/restart.sh

# Check status
bash scripts/status.sh

# View logs
bash scripts/logs.sh

# Start on custom port
bash scripts/start.sh --port 4000

# Start with resource limits
bash scripts/start.sh --memory 512m --cpus 1
```

## Configuration

### Environment Variables

```bash
# Custom port (default: 3000)
export GOTENBERG_PORT=3000

# API timeout (default: 30s)
export GOTENBERG_TIMEOUT=60s

# Custom container name
export GOTENBERG_CONTAINER=gotenberg

# Chromium options
export GOTENBERG_CHROMIUM_DISABLE_JAVASCRIPT=false
export GOTENBERG_CHROMIUM_ALLOW_LIST=".*"  # URL patterns to allow
```

## Troubleshooting

### Issue: "Cannot connect to Docker daemon"

**Fix:** Make sure Docker is installed and running:
```bash
sudo systemctl start docker
# Or install Docker:
curl -fsSL https://get.docker.com | sh
```

### Issue: "Connection refused on port 3000"

**Fix:** Start the Gotenberg container:
```bash
bash scripts/start.sh
# Check if running:
docker ps | grep gotenberg
```

### Issue: Office conversion fails

**Fix:** Gotenberg uses LibreOffice internally. If converting complex docs, increase timeout:
```bash
bash scripts/start.sh --timeout 120s
```

### Issue: Large files time out

**Fix:** Increase the API timeout:
```bash
curl -f -X POST http://localhost:3000/forms/chromium/convert/url \
  -F url=https://example.com \
  -H "Gotenberg-Wait-Timeout: 120s" \
  -o output.pdf
```

## Dependencies

- `bash` (4.0+)
- `docker` — runs Gotenberg container
- `curl` — API calls

## Key Principles

1. **Self-hosted** — No cloud APIs, no rate limits, no API keys
2. **Multi-format** — HTML, URLs, Markdown, Office docs → PDF
3. **Docker-based** — One container, instant setup, easy cleanup
4. **API-first** — Simple REST API, works with curl or any HTTP client
5. **Production-ready** — Gotenberg is battle-tested (10k+ GitHub stars)
