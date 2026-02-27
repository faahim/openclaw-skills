---
name: typst-processor
description: >-
  Install Typst and compile professional documents (resumes, invoices, reports, letters) from markup to PDF.
categories: [writing, productivity]
dependencies: [bash, curl]
---

# Typst Document Processor

## What This Does

Installs [Typst](https://typst.app) — a modern markup-based document compiler — and provides ready-to-use templates for professional documents. Write in simple markup, get polished PDFs in seconds. No LaTeX complexity, no Word headaches.

**Example:** Write a resume in 20 lines of markup → compile to a pixel-perfect PDF in under 1 second.

## Quick Start (3 minutes)

### 1. Install Typst

```bash
bash scripts/install.sh
```

This auto-detects your OS/arch and installs the latest Typst binary.

### 2. Compile Your First Document

```bash
# Create a simple document
cat > hello.typ << 'EOF'
#set page(paper: "a4", margin: 2cm)
#set text(font: "Linux Libertine", size: 11pt)

= Hello World

This is my first Typst document. It supports:

- *Bold* and _italic_ text
- Mathematical equations: $E = m c^2$
- Tables, figures, and references
- Custom styling and templates

#table(
  columns: (1fr, 1fr, 1fr),
  [*Name*], [*Role*], [*Status*],
  [Alice], [Engineer], [Active],
  [Bob], [Designer], [On leave],
)
EOF

# Compile to PDF
typst compile hello.typ
# Output: hello.pdf
```

### 3. Use a Template

```bash
# Generate a resume from template
bash scripts/generate.sh resume \
  --name "Jane Smith" \
  --title "Senior Software Engineer" \
  --output resume.pdf
```

## Core Workflows

### Workflow 1: Resume / CV

```bash
bash scripts/generate.sh resume \
  --name "Your Name" \
  --title "Your Title" \
  --email "you@email.com" \
  --phone "+1-234-567-8900" \
  --output my-resume.pdf
```

This creates a `.typ` source file and compiles it to PDF. Edit the `.typ` file to customize content, then recompile:

```bash
typst compile my-resume.typ
```

### Workflow 2: Invoice

```bash
bash scripts/generate.sh invoice \
  --from "Your Company" \
  --to "Client Name" \
  --items "Web Development:40h:150|Design Review:8h:120|Hosting Setup:1:500" \
  --output invoice-001.pdf
```

### Workflow 3: Letter

```bash
bash scripts/generate.sh letter \
  --from "Your Name" \
  --to "Recipient Name" \
  --subject "Project Proposal" \
  --body "letter-body.txt" \
  --output letter.pdf
```

### Workflow 4: Report

```bash
bash scripts/generate.sh report \
  --title "Q1 2026 Performance Report" \
  --author "Your Name" \
  --output q1-report.pdf
```

Edit the generated `.typ` file to add sections, charts, and data.

### Workflow 5: Watch Mode (Live Preview)

```bash
# Auto-recompile on save
typst watch document.typ
```

### Workflow 6: Batch Compile

```bash
# Compile all .typ files in a directory
bash scripts/batch-compile.sh ./documents/
```

## Configuration

### Default Settings

Edit `scripts/defaults.conf` to set defaults:

```bash
# Default page settings
PAGE_SIZE="a4"          # a4, us-letter
FONT="Linux Libertine"  # Any installed font
FONT_SIZE="11pt"
MARGIN="2cm"

# Default output directory
OUTPUT_DIR="./output"
```

### Custom Fonts

```bash
# List available system fonts
fc-list | grep -i "font-name"

# Use custom font in .typ file
#set text(font: "Inter", size: 10pt)
```

## Templates Reference

| Template | Description | Generated Files |
|----------|-------------|-----------------|
| `resume` | Professional CV/resume | `resume.typ`, `resume.pdf` |
| `invoice` | Itemized invoice with totals | `invoice.typ`, `invoice.pdf` |
| `letter` | Formal business letter | `letter.typ`, `letter.pdf` |
| `report` | Multi-section report with TOC | `report.typ`, `report.pdf` |
| `slides` | Presentation slides | `slides.typ`, `slides.pdf` |
| `notes` | Meeting/lecture notes | `notes.typ`, `notes.pdf` |

## Advanced Usage

### Custom Templates

Create your own template in `templates/`:

```typst
// templates/custom.typ
#let custom-doc(title: "", author: "", body) = {
  set page(paper: "a4", margin: 2cm)
  set text(font: "Inter", size: 11pt)
  
  align(center)[
    #text(size: 24pt, weight: "bold")[#title]
    #v(0.5cm)
    #text(size: 14pt, fill: gray)[#author]
  ]
  
  v(1cm)
  body
}
```

### Export Formats

```bash
# PDF (default)
typst compile doc.typ doc.pdf

# PNG (per page)
typst compile doc.typ doc-{n}.png

# SVG
typst compile doc.typ doc-{n}.svg
```

### Typst Packages

```typst
// Use community packages
#import "@preview/tablex:0.0.8": tablex, rowspanx, colspanx

#tablex(
  columns: 3,
  rowspanx(2)[*Merged*], [B], [C],
  (), [E], [F],
)
```

## Troubleshooting

### Issue: "typst: command not found"

```bash
# Re-run installer
bash scripts/install.sh

# Or add to PATH manually
export PATH="$HOME/.local/bin:$PATH"
```

### Issue: Font not found

```bash
# Install common fonts
sudo apt-get install fonts-liberation fonts-inter  # Debian/Ubuntu
brew install font-inter                              # macOS

# Check available fonts
typst fonts
```

### Issue: Compilation error

```bash
# Typst shows line numbers in errors
typst compile doc.typ 2>&1 | head -20
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- Optional: `fc-list` (font listing)
