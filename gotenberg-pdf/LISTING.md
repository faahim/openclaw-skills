# Listing Copy: Gotenberg PDF API

## Metadata
- **Type:** Skill
- **Name:** gotenberg-pdf
- **Display Name:** Gotenberg PDF API
- **Categories:** [dev-tools, productivity]
- **Icon:** 📄
- **Price:** $12
- **Dependencies:** [bash, docker, curl]

## Tagline

Self-hosted PDF generation API — convert HTML, URLs, and Office docs to PDF

## Description

Need to generate PDFs programmatically? Most solutions require expensive cloud APIs with rate limits, or cobbling together wkhtmltopdf and LibreOffice commands. Gotenberg wraps both Chromium and LibreOffice into a single Docker container with a clean REST API.

**Gotenberg PDF API** lets your OpenClaw agent run a self-hosted PDF generation server. Convert HTML files, capture web pages, transform Markdown, and convert Office documents (docx, xlsx, pptx) — all through simple curl commands. No API keys, no rate limits, no cloud dependencies.

**What it does:**
- 📄 HTML/CSS to pixel-perfect PDF (Chromium rendering)
- 🌐 Capture any URL as PDF with full JavaScript support
- 📝 Markdown to styled PDF
- 📊 Office docs (docx, xlsx, pptx, odt) to PDF via LibreOffice
- 🔗 Merge multiple PDFs into one
- 📦 Batch convert entire directories
- ⚙️ Custom page sizes, margins, orientation, backgrounds
- 🐳 One Docker container, instant setup

Perfect for developers generating reports, invoices, documentation, or any workflow that needs reliable PDF output.

## Quick Start Preview

```bash
bash scripts/start.sh
# ✅ Gotenberg running on http://localhost:3000

bash scripts/convert.sh --url https://example.com --output page.pdf
# ✅ Created: page.pdf (42K)
```

## Core Capabilities

1. HTML to PDF — Pixel-perfect rendering via headless Chromium
2. URL capture — Convert any webpage to PDF with JS support
3. Markdown to PDF — Styled Markdown conversion
4. Office conversion — docx, xlsx, pptx, odt via LibreOffice
5. PDF merging — Combine multiple PDFs into one
6. Batch processing — Convert entire directories
7. Custom formatting — Paper size, margins, orientation, backgrounds
8. Wait delays — Let JS-heavy pages load before capture
9. Docker-based — One container, easy setup and cleanup
10. REST API — Simple curl interface, works with any language

## Dependencies
- `bash` (4.0+)
- `docker`
- `curl`

## Installation Time
**3 minutes** — Pull Docker image, start container, convert
