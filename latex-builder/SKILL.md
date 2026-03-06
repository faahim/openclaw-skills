---
name: latex-builder
description: >-
  Install TeX Live and compile LaTeX documents to PDF. Includes templates for resumes, letters, reports, and academic papers.
categories: [writing, productivity]
dependencies: [bash, curl]
---

# LaTeX Builder

## What This Does

Installs a minimal TeX Live distribution and compiles LaTeX documents to PDF — all from the command line. Includes ready-to-use templates for resumes, cover letters, reports, and academic papers. No GUI needed, no manual package management.

**Example:** "Compile my resume from LaTeX source to PDF, auto-installing any missing packages."

## Quick Start (5 minutes)

### 1. Install TeX Live (Minimal)

```bash
bash scripts/install.sh
```

This installs a ~500MB minimal TeX Live with `tlmgr` for on-demand package installation. If TeX Live is already installed, it skips.

### 2. Compile a Document

```bash
bash scripts/build.sh input.tex

# Output: input.pdf in the same directory
```

### 3. Use a Template

```bash
# List available templates
bash scripts/build.sh --list-templates

# Generate from template
bash scripts/build.sh --template resume --output my-resume.tex

# Edit my-resume.tex, then compile
bash scripts/build.sh my-resume.tex
```

## Core Workflows

### Workflow 1: Compile LaTeX to PDF

```bash
bash scripts/build.sh document.tex

# With bibliography
bash scripts/build.sh document.tex --bib

# With multiple passes (for cross-references)
bash scripts/build.sh document.tex --passes 3

# Clean auxiliary files after build
bash scripts/build.sh document.tex --clean
```

### Workflow 2: Auto-Install Missing Packages

```bash
# If compilation fails due to missing packages, auto-install and retry
bash scripts/build.sh document.tex --auto-install
```

### Workflow 3: Watch Mode (Recompile on Change)

```bash
# Recompile when .tex file changes
bash scripts/build.sh document.tex --watch
```

### Workflow 4: Generate from Template

```bash
# Available templates: resume, letter, report, paper, slides
bash scripts/build.sh --template resume --output my-resume.tex
bash scripts/build.sh --template letter --output cover-letter.tex
bash scripts/build.sh --template report --output quarterly-report.tex
bash scripts/build.sh --template paper --output research-paper.tex
bash scripts/build.sh --template slides --output presentation.tex
```

### Workflow 5: Batch Compile

```bash
# Compile all .tex files in a directory
bash scripts/build.sh --dir ./documents/
```

## Configuration

### Environment Variables

```bash
# Custom TeX Live install path (default: ~/texlive)
export TEXLIVE_DIR="$HOME/texlive"

# PDF viewer (optional, for --open flag)
export PDF_VIEWER="evince"

# Default LaTeX engine (pdflatex, xelatex, lualatex)
export LATEX_ENGINE="pdflatex"
```

## Templates

### Resume Template
Modern, clean single-page resume. Sections: contact, summary, experience, education, skills.

### Letter Template
Professional business letter with sender/recipient blocks, date, salutation.

### Report Template
Multi-section report with title page, table of contents, numbered sections, bibliography.

### Paper Template
Academic paper with abstract, sections, figures, citations (BibTeX-ready).

### Slides Template
Beamer presentation with title slide, content slides, two-column layout.

## Advanced Usage

### Use XeLaTeX (for Unicode/custom fonts)

```bash
LATEX_ENGINE=xelatex bash scripts/build.sh document.tex
```

### Use LuaLaTeX

```bash
LATEX_ENGINE=lualatex bash scripts/build.sh document.tex
```

### Install Specific Packages

```bash
bash scripts/install.sh --packages "geometry hyperref fancyhdr biblatex"
```

### Full TeX Live Install (2GB+)

```bash
bash scripts/install.sh --full
```

## Troubleshooting

### Issue: "pdflatex: command not found"

```bash
# Re-run installer
bash scripts/install.sh

# Or add to PATH manually
export PATH="$HOME/texlive/2025/bin/$(uname -m)-linux:$PATH"
```

### Issue: "File `<package>.sty' not found"

```bash
# Auto-install the missing package
bash scripts/build.sh document.tex --auto-install

# Or install manually
tlmgr install <package-name>
```

### Issue: Bibliography not showing

```bash
# Use --bib flag for full bibtex pipeline
bash scripts/build.sh document.tex --bib
```

### Issue: Fonts not found (XeLaTeX)

```bash
# Install common font packages
bash scripts/install.sh --packages "fontspec libertine"
```

## Dependencies

- `bash` (4.0+)
- `curl` or `wget` (for TeX Live download)
- ~500MB disk space (minimal install) or ~2GB (full)
- Optional: `inotifywait` (for --watch mode; from `inotify-tools`)
