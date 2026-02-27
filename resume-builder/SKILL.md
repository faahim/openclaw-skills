---
name: resume-builder
description: >-
  Generate professional resumes from YAML data — outputs PDF, HTML, and Markdown using pandoc and LaTeX.
categories: [writing, productivity]
dependencies: [pandoc, texlive, wkhtmltopdf]
---

# Resume Builder

## What This Does

Generate polished, professional resumes from structured YAML data. Write your experience once, output it as PDF, HTML, or Markdown. Multiple templates included. No manual formatting — just edit your data and regenerate.

**Example:** "Update `resume.yaml` with new job, run `bash scripts/build.sh`, get `resume.pdf` in 3 seconds."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install pandoc + LaTeX (for PDF generation)
bash scripts/install.sh

# Verify installation
pandoc --version && pdflatex --version | head -1
```

### 2. Create Your Resume

```bash
# Copy the template
cp templates/resume-template.yaml resume.yaml

# Edit with your details
# (see template for all fields — name, contact, experience, education, skills)
nano resume.yaml
```

### 3. Generate Resume

```bash
# Generate PDF (default)
bash scripts/build.sh resume.yaml

# Generate all formats
bash scripts/build.sh resume.yaml --all

# Output:
# ✅ output/resume.pdf (2 pages, professional layout)
# ✅ output/resume.html (web-ready, responsive)
# ✅ output/resume.md (plain markdown)
```

## Core Workflows

### Workflow 1: Quick PDF Resume

**Use case:** Generate a PDF resume from YAML data

```bash
bash scripts/build.sh resume.yaml --format pdf --template modern
```

**Output:**
```
📄 Building resume from resume.yaml...
📐 Template: modern
🔨 Generating PDF via pandoc + LaTeX...
✅ output/resume.pdf (2 pages, 48KB)
```

### Workflow 2: Multiple Formats

**Use case:** Generate PDF, HTML, and Markdown simultaneously

```bash
bash scripts/build.sh resume.yaml --all
```

**Output:**
```
✅ output/resume.pdf
✅ output/resume.html
✅ output/resume.md
```

### Workflow 3: Tailored Resumes

**Use case:** Generate different versions for different job applications

```bash
# Full-stack role
bash scripts/build.sh resume.yaml --sections "summary,experience,skills,education" --output fullstack-resume.pdf

# Backend-focused role
bash scripts/build.sh resume.yaml --sections "summary,experience,skills" --filter-skills "Python,Go,PostgreSQL,AWS" --output backend-resume.pdf
```

### Workflow 4: Cover Letter

**Use case:** Generate a matching cover letter

```bash
bash scripts/build.sh resume.yaml --cover-letter --company "Acme Corp" --role "Senior Developer"
```

## Resume YAML Format

```yaml
# resume.yaml
name: Jane Smith
title: Senior Software Engineer
contact:
  email: jane@example.com
  phone: "+1-555-0123"
  location: San Francisco, CA
  linkedin: linkedin.com/in/janesmith
  github: github.com/janesmith
  website: janesmith.dev

summary: >-
  8+ years building scalable web applications. Expert in React, Node.js,
  and cloud infrastructure. Led teams of 5-12 engineers. Passionate about
  developer tooling and open source.

experience:
  - company: TechCorp
    role: Senior Software Engineer
    dates: "2022 — Present"
    location: San Francisco, CA
    highlights:
      - Led migration from monolith to microservices, reducing deploy time by 80%
      - Built real-time analytics pipeline processing 2M events/day
      - Mentored 4 junior engineers through promotion cycles

  - company: StartupXYZ
    role: Software Engineer
    dates: "2019 — 2022"
    location: Remote
    highlights:
      - Designed and shipped core API serving 500K monthly active users
      - Implemented CI/CD pipeline reducing release cycle from 2 weeks to 2 hours
      - Open-sourced internal testing framework (1.2K GitHub stars)

education:
  - institution: UC Berkeley
    degree: B.S. Computer Science
    dates: "2015 — 2019"
    gpa: "3.8"
    highlights:
      - Dean's List (6 semesters)
      - Teaching Assistant for Data Structures (CS61B)

skills:
  languages: [JavaScript, TypeScript, Python, Go, SQL]
  frameworks: [React, Next.js, Node.js, Express, FastAPI]
  infrastructure: [AWS, Docker, Kubernetes, Terraform, GitHub Actions]
  databases: [PostgreSQL, Redis, MongoDB, DynamoDB]
  tools: [Git, Linux, Vim, Figma]

certifications:
  - name: AWS Solutions Architect — Associate
    date: "2023"
  - name: Kubernetes Application Developer (CKAD)
    date: "2022"

projects:
  - name: OpenMetrics
    url: github.com/janesmith/openmetrics
    description: Open-source application monitoring library (2.3K stars)
  - name: DevDash
    url: devdash.io
    description: Developer productivity dashboard with GitHub/Jira integration
```

## Templates

### Available Templates

| Template | Style | Best For |
|----------|-------|----------|
| `modern` | Clean, minimal, good whitespace | Tech roles, startups |
| `classic` | Traditional, serif fonts | Enterprise, finance |
| `compact` | Dense, single-page optimized | When you need to fit a lot |

```bash
# Use a specific template
bash scripts/build.sh resume.yaml --template classic
bash scripts/build.sh resume.yaml --template compact
```

## Configuration

### Environment Variables

```bash
# Default output directory
export RESUME_OUTPUT_DIR="./output"

# Default template
export RESUME_TEMPLATE="modern"

# Default format
export RESUME_FORMAT="pdf"

# Paper size (a4 or letter)
export RESUME_PAPER="letter"
```

## Advanced Usage

### Custom LaTeX Header

```bash
# Add custom styling
bash scripts/build.sh resume.yaml --header custom-header.tex
```

### Watch Mode (Auto-rebuild)

```bash
# Rebuild on file changes (requires inotifywait)
bash scripts/watch.sh resume.yaml
```

### JSON Input (Alternative)

```bash
# Also accepts JSON
bash scripts/build.sh resume.json --format pdf
```

## Troubleshooting

### Issue: "pdflatex not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install texlive-latex-base texlive-fonts-recommended texlive-latex-extra

# Mac
brew install --cask mactex-no-gui
```

### Issue: "pandoc: command not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install pandoc

# Mac
brew install pandoc
```

### Issue: PDF looks wrong / missing fonts

**Fix:**
```bash
# Install full font packages
sudo apt-get install texlive-fonts-extra
```

### Issue: Unicode characters not rendering

**Fix:** Use XeLaTeX engine:
```bash
bash scripts/build.sh resume.yaml --engine xelatex
```

## Dependencies

- `pandoc` (2.0+) — document conversion
- `texlive` — LaTeX for PDF rendering
- `wkhtmltopdf` (optional) — HTML-to-PDF alternative
- `bash` (4.0+)
- `yq` or `python3` — YAML parsing
