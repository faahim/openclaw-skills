# Listing Copy: Mermaid Diagram Generator

## Metadata
- **Type:** Skill
- **Name:** mermaid-diagrams
- **Display Name:** Mermaid Diagram Generator
- **Categories:** [dev-tools, productivity]
- **Price:** $8
- **Dependencies:** [node, npm]

## Tagline

Render flowcharts, sequence diagrams, ERDs, and Gantt charts to PNG/SVG from text

## Description

Your AI agent can write perfect Mermaid syntax — but it can't turn that into an actual image. This skill bridges the gap by installing mermaid-cli and giving your agent the ability to render any Mermaid diagram to PNG, SVG, or PDF.

Mermaid Diagram Generator handles the entire rendering pipeline: installs the mermaid-cli tool (with Chromium for headless rendering), provides smart defaults for sizing and themes, and includes a helper script for batch rendering. Works on Linux and macOS, including headless servers and Docker containers.

**What it does:**
- 📊 Render flowcharts, sequence diagrams, class diagrams, ERDs
- 📅 Generate Gantt charts, pie charts, git graphs
- 🎨 4 built-in themes (default, dark, forest, neutral) + custom themes
- 📁 Batch render entire directories of .mmd files
- 🖼️ Output PNG, SVG, or PDF with custom dimensions
- 🔧 Auto-detects Chromium path, handles headless environments

Perfect for developers documenting architecture, teams planning sprints, or anyone who needs diagrams generated programmatically.

## Quick Start Preview

```bash
# Render a flowchart
echo 'graph TD; A[Start]-->B{Decision}; B-->|Yes|C[Done]; B-->|No|D[Retry];' | mmdc -i - -o flowchart.png

# Sequence diagram with dark theme
mmdc -i sequence.mmd -o sequence.png -t dark -w 1400
```

## Core Capabilities

1. Flowchart rendering — Complex decision trees, process flows
2. Sequence diagrams — API call flows, system interactions
3. ER diagrams — Database schema visualization
4. Gantt charts — Project timelines with dependencies
5. Class diagrams — OOP architecture documentation
6. Pie & git graphs — Data visualization and branch history
7. Theme support — Dark, forest, neutral, or fully custom JSON themes
8. Batch processing — Render all .mmd files in a directory at once
9. Multi-format output — PNG for sharing, SVG for docs, PDF for reports
10. Headless-ready — Works on servers, Docker, CI/CD pipelines

## Dependencies
- `node` (16+)
- `npm`
- `@mermaid-js/mermaid-cli`

## Installation Time
**2 minutes** — npm install + verify
