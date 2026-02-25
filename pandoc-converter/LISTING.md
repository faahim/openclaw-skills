# Listing Copy: Pandoc Document Converter

## Metadata
- **Type:** Skill
- **Name:** pandoc-converter
- **Display Name:** Pandoc Document Converter
- **Categories:** [productivity, data]
- **Price:** $10
- **Dependencies:** [pandoc, bash, curl]

## Tagline

Convert documents between 40+ formats — Markdown to PDF, HTML to DOCX, and everything in between.

## Description

Converting documents between formats is one of those tasks that sounds simple until you actually need to do it. Markdown to PDF with proper styling? HTML to clean Word documents? Merging chapters into an eBook? Without the right tooling, you're copy-pasting into Google Docs and hoping for the best.

Pandoc Document Converter gives your OpenClaw agent the power of Pandoc — the Swiss Army knife of document conversion. One command converts between 40+ formats: Markdown, PDF, DOCX, HTML, EPUB, LaTeX, slides, and more. It handles table of contents, syntax highlighting, custom templates, CSS styling, and batch conversion of entire directories.

**What it does:**
- 📄 Convert between 40+ document formats (MD, PDF, DOCX, HTML, EPUB, LaTeX, RST, slides)
- 📚 Merge multiple files into a single output (chapters → book PDF)
- 🎨 Apply custom CSS, templates, and reference docs for branded output
- ⚡ Batch convert entire directories with parallel processing
- 🌐 Fetch and convert web pages directly from URLs
- 📊 Auto-detect PDF engines (XeLaTeX, wkhtmltopdf, WeasyPrint)
- 🔧 Auto-installer detects your OS and sets up everything

Perfect for developers documenting projects, writers publishing eBooks, teams standardizing on formats, or anyone who needs reliable document conversion without cloud services.

## Quick Start Preview

```bash
# Install pandoc (auto-detects OS)
bash scripts/install.sh

# Convert markdown to PDF
bash scripts/convert.sh README.md output.pdf --toc

# Batch convert all docs
bash scripts/batch-convert.sh ./docs/ pdf
```

## Core Capabilities

1. Single file conversion — Any format to any format in one command
2. Batch conversion — Convert entire directories with parallel support
3. Merge & combine — Multiple files into one PDF, EPUB, or DOCX
4. URL conversion — Fetch web pages and convert to any format
5. PDF engines — Auto-selects XeLaTeX, pdflatex, wkhtmltopdf, or WeasyPrint
6. Custom styling — CSS for HTML/PDF, reference DOCX for Word, LaTeX templates
7. Table of contents — Auto-generated TOC with configurable depth
8. Syntax highlighting — 100+ language themes for code blocks
9. Reveal.js slides — Markdown to presentation slides
10. Cross-platform — Works on Ubuntu, Debian, Fedora, Arch, macOS

## Dependencies
- `pandoc` (2.0+)
- `bash` (4.0+)
- `curl`
- Optional: `texlive`, `wkhtmltopdf`, or `weasyprint` for PDF

## Installation Time
**5 minutes** — Run install script, start converting
