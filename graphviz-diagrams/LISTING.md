# Listing Copy: Graphviz Diagram Generator

## Metadata
- **Type:** Skill
- **Name:** graphviz-diagrams
- **Display Name:** Graphviz Diagram Generator
- **Categories:** [design, dev-tools]
- **Price:** $8
- **Dependencies:** [graphviz, bash]

## Tagline

Generate architecture diagrams, flowcharts, and ERDs as actual images from text

## Description

Manually drawing system diagrams in Figma or draw.io is slow, hard to version control, and a pain to update when architecture changes. You need diagrams that live as code.

Graphviz Diagram Generator renders professional diagrams — architecture views, flowcharts, dependency graphs, state machines, ERDs — as PNG/SVG/PDF images directly from DOT language. Your agent describes the diagram in text, this skill produces an actual image file you can share, embed in docs, or commit to your repo.

**What it does:**
- 📐 Render DOT language to PNG, SVG, or PDF
- 🏗️ Built-in templates for common diagrams (microservices, CI/CD, network topology)
- 📦 Generate dependency graphs from package.json or requirements.txt
- 🎨 Themes: light, dark, minimal — or custom colors
- 📁 Batch render entire directories of .dot files
- 👀 Watch mode: auto-render on file changes
- ⚡ 6 layout engines: dot, neato, fdp, sfdp, circo, twopi

Perfect for developers who want diagrams as code — version-controlled, reproducible, and generated in seconds.

## Quick Start Preview

```bash
bash scripts/install.sh  # One-time setup

echo 'digraph { A -> B -> C }' | bash scripts/render.sh --output simple.png
# ✅ Rendered: simple.png (12K, PNG)
```

## Core Capabilities

1. DOT to image rendering — PNG, SVG, PDF output from text descriptions
2. Architecture diagrams — Microservices, monoliths, layered systems
3. Flowcharts — Decision trees, process flows, deployment pipelines
4. ERD generation — Database schema visualization with relationships
5. Dependency graphs — Auto-generate from package.json/requirements.txt
6. Built-in templates — Microservices, CI/CD, network topology
7. Theme support — Light, dark, minimal, or custom colors
8. Batch rendering — Process entire directories of .dot files
9. Watch mode — Auto-render on file changes (inotify)
10. Multiple engines — dot, neato, fdp, sfdp, circo, twopi

## Dependencies
- `graphviz` (auto-installed by scripts/install.sh)
- `bash` (4.0+)
- Optional: `jq` (for package.json dependency graphs)
- Optional: `inotify-tools` (for watch mode)

## Installation Time
**2 minutes** — Run install.sh, start rendering

## Pricing Justification

**Why $8:**
- Simple utility, broad appeal
- Graphviz is free but setup + good templates have value
- Time saved: minutes vs hours in GUI tools
- Diagrams-as-code is trending in DevOps/engineering
