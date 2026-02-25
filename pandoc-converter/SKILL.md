---
name: pandoc-converter
description: >-
  Convert documents between 40+ formats — Markdown to PDF, HTML to DOCX, LaTeX to EPUB, and more.
categories: [productivity, data]
dependencies: [pandoc, bash, curl]
---

# Pandoc Document Converter

## What This Does

Convert documents between virtually any format using Pandoc — the universal document converter. Markdown → PDF, HTML → DOCX, LaTeX → EPUB, CSV → HTML tables, and 40+ other combinations. Handles templates, styling, table of contents, syntax highlighting, and batch conversion.

**Example:** "Convert all markdown files in docs/ to a single styled PDF with table of contents and custom fonts."

## Quick Start (5 minutes)

### 1. Install Pandoc

```bash
# Auto-install (detects OS)
bash scripts/install.sh

# Or manually:
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y pandoc

# macOS
brew install pandoc

# With PDF support (LaTeX)
sudo apt-get install -y pandoc texlive-latex-recommended texlive-fonts-recommended texlive-latex-extra

# Lightweight PDF (no LaTeX needed)
sudo apt-get install -y pandoc wkhtmltopdf
```

### 2. Convert Your First Document

```bash
# Markdown → PDF
bash scripts/convert.sh input.md output.pdf

# Markdown → DOCX
bash scripts/convert.sh input.md output.docx

# HTML → Markdown
bash scripts/convert.sh page.html output.md
```

### 3. Batch Convert

```bash
# Convert all .md files to PDF
bash scripts/batch-convert.sh ./docs/ pdf

# Convert all .html files to DOCX
bash scripts/batch-convert.sh ./pages/ docx
```

## Core Workflows

### Workflow 1: Markdown → Styled PDF

**Use case:** Generate professional PDFs from markdown documentation

```bash
bash scripts/convert.sh README.md output.pdf \
  --toc \
  --highlight-style=tango \
  --pdf-engine=xelatex \
  -V geometry:margin=1in \
  -V fontsize=12pt
```

**Output:**
```
✅ Converted README.md → output.pdf (styled, with TOC)
   Pages: 12 | Size: 245KB | Engine: xelatex
```

### Workflow 2: Multiple Markdown → Single PDF

**Use case:** Combine documentation chapters into one PDF

```bash
bash scripts/merge-convert.sh ./chapters/ output.pdf --toc

# Processes in order: 01-intro.md, 02-setup.md, 03-usage.md, etc.
```

**Output:**
```
✅ Merged 5 files → output.pdf
   Files: 01-intro.md, 02-setup.md, 03-usage.md, 04-api.md, 05-faq.md
   Pages: 47 | Size: 1.2MB
```

### Workflow 3: HTML → Clean Markdown

**Use case:** Convert web pages or HTML docs to clean markdown

```bash
# From file
bash scripts/convert.sh page.html output.md --wrap=none

# From URL (fetches first)
bash scripts/url-convert.sh https://example.com/docs output.md
```

### Workflow 4: DOCX → Markdown (with images)

**Use case:** Convert Word documents to markdown for version control

```bash
bash scripts/convert.sh report.docx output.md --extract-media=./media/

# Extracts images to ./media/ and updates markdown references
```

### Workflow 5: Markdown → EPUB (eBook)

**Use case:** Create eBooks from markdown files

```bash
bash scripts/convert.sh book.md book.epub \
  --metadata title="My Book" \
  --metadata author="Author Name" \
  --toc \
  --toc-depth=2
```

### Workflow 6: Lightweight PDF (No LaTeX)

**Use case:** Generate PDFs without installing LaTeX (uses wkhtmltopdf or weasyprint)

```bash
bash scripts/convert.sh input.md output.pdf --pdf-engine=wkhtmltopdf

# Or via HTML intermediate (more styling control)
bash scripts/convert.sh input.md output.pdf --pdf-engine=weasyprint --css=scripts/style.css
```

## Supported Formats

### Input Formats
markdown, html, docx, epub, latex, rst, textile, org, mediawiki, json, csv, tsv, docbook, opml, man

### Output Formats
pdf, docx, html, epub, latex, rst, plain text, rtf, odt, pptx, revealjs (slides), beamer (slides), man pages, mediawiki

### Common Conversions

| From | To | Command |
|------|-----|---------|
| Markdown | PDF | `convert.sh input.md output.pdf` |
| Markdown | DOCX | `convert.sh input.md output.docx` |
| Markdown | HTML | `convert.sh input.md output.html --standalone` |
| Markdown | EPUB | `convert.sh input.md output.epub` |
| Markdown | Slides | `convert.sh input.md slides.html -t revealjs` |
| HTML | Markdown | `convert.sh page.html output.md` |
| HTML | PDF | `convert.sh page.html output.pdf` |
| DOCX | Markdown | `convert.sh report.docx output.md` |
| DOCX | PDF | `convert.sh report.docx output.pdf` |
| LaTeX | PDF | `convert.sh paper.tex output.pdf` |
| CSV | HTML | `convert.sh data.csv table.html` |

## Configuration

### Custom Templates

```bash
# List default templates
pandoc --print-default-template=latex > my-template.tex

# Use custom template
bash scripts/convert.sh input.md output.pdf --template=my-template.tex
```

### CSS Styling (HTML/PDF output)

```bash
# Apply custom CSS
bash scripts/convert.sh input.md output.html --css=custom.css --standalone

# Use included minimal style
bash scripts/convert.sh input.md output.html --css=scripts/style.css --standalone
```

### Environment Variables

```bash
# Default PDF engine (xelatex, pdflatex, wkhtmltopdf, weasyprint)
export PANDOC_PDF_ENGINE="xelatex"

# Default highlight style
export PANDOC_HIGHLIGHT="tango"

# Default output directory
export PANDOC_OUTPUT_DIR="./output"
```

## Advanced Usage

### Pandoc Filters

```bash
# Use Lua filter for custom processing
bash scripts/convert.sh input.md output.pdf --lua-filter=scripts/wordcount.lua

# Use multiple filters
bash scripts/convert.sh input.md output.pdf \
  --lua-filter=scripts/diagram-filter.lua \
  --filter pandoc-crossref
```

### Reveal.js Presentations

```bash
# Markdown → Slides
bash scripts/convert.sh slides.md presentation.html \
  -t revealjs \
  -V theme=moon \
  -V transition=slide \
  --standalone
```

### Reference DOCX (branded output)

```bash
# Generate reference doc, customize in Word, then use as template
pandoc -o reference.docx --print-default-data-file reference.docx
# ... customize reference.docx styles in Word ...

bash scripts/convert.sh input.md output.docx --reference-doc=reference.docx
```

## Troubleshooting

### Issue: "pdflatex not found"

**Fix:** Install LaTeX or use lightweight engine:
```bash
# Full LaTeX
sudo apt-get install -y texlive-latex-recommended texlive-fonts-recommended

# Or skip LaTeX entirely
bash scripts/convert.sh input.md output.pdf --pdf-engine=wkhtmltopdf
```

### Issue: Unicode/emoji not rendering in PDF

**Fix:** Use XeLaTeX engine:
```bash
bash scripts/convert.sh input.md output.pdf --pdf-engine=xelatex
```

### Issue: Images not found

**Fix:** Set resource path:
```bash
bash scripts/convert.sh input.md output.pdf --resource-path=./images:./assets
```

### Issue: Large file conversion slow

**Fix:** For very large documents, increase timeout or convert in sections:
```bash
# Batch with parallel processing
bash scripts/batch-convert.sh ./docs/ pdf --parallel 4
```

## Dependencies

- `pandoc` (2.0+) — core converter
- `bash` (4.0+) — scripts
- `curl` — URL fetching
- Optional: `texlive` — PDF via LaTeX
- Optional: `wkhtmltopdf` — lightweight PDF
- Optional: `weasyprint` — CSS-styled PDF
