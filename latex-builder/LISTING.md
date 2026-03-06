# Listing Copy: LaTeX Builder

## Metadata
- **Type:** Skill
- **Name:** latex-builder
- **Display Name:** LaTeX Builder
- **Categories:** [writing, productivity]
- **Price:** $10
- **Dependencies:** [bash, curl]
- **Icon:** 📄

## Tagline

Compile LaTeX documents to PDF — with templates, auto-install, and watch mode

## Description

Writing professional documents shouldn't require wrestling with TeX Live installation or package management. LaTeX Builder handles the entire toolchain — from installing a minimal TeX distribution to compiling your documents with a single command.

Includes ready-to-use templates for resumes, cover letters, reports, academic papers, and Beamer presentations. Missing a LaTeX package? The `--auto-install` flag detects and installs it automatically. Need live preview? Use `--watch` to recompile on every save.

**What it does:**
- 📥 Installs TeX Live (minimal ~500MB or full ~2GB) with one command
- 🔨 Compiles `.tex` → `.pdf` via pdflatex, xelatex, or lualatex
- 📦 Auto-detects and installs missing packages on the fly
- 📝 5 professional templates (resume, letter, report, paper, slides)
- 👀 Watch mode — recompiles on file changes
- 📁 Batch compile entire directories
- 📚 Full BibTeX/Biber bibliography pipeline
- 🧹 Clean auxiliary files after build

Perfect for developers, academics, and anyone who wants beautiful typeset documents without the setup headache.

## Quick Start Preview

```bash
# Install TeX Live
bash scripts/install.sh

# Compile a document
bash scripts/build.sh thesis.tex

# Use a template
bash scripts/build.sh --template resume --output my-resume.tex
bash scripts/build.sh my-resume.tex
```

## Dependencies
- `bash` (4.0+)
- `curl` or `wget`
- ~500MB disk (minimal) or ~2GB (full install)

## Installation Time
**5-10 minutes** (mostly TeX Live download)
