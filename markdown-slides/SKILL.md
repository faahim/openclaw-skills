---
name: markdown-slides
description: >-
  Convert Markdown files into beautiful presentation slides (HTML, PDF, PPTX) using Marp CLI.
categories: [productivity, media]
dependencies: [node, npm, marp-cli]
---

# Markdown Slides

## What This Does

Converts Markdown files into polished presentation slides in HTML, PDF, or PowerPoint format using [Marp CLI](https://github.com/marp-team/marp-cli). Write your slides in plain Markdown with simple directives, then export to any format. No GUI needed — perfect for developers and technical presenters.

**Example:** "Write slides in Markdown → get a PDF presentation with themes, speaker notes, and custom styling in seconds."

## Quick Start (5 minutes)

### 1. Install Marp CLI

```bash
bash scripts/install.sh
```

### 2. Create Your First Deck

```bash
cat > my-deck.md << 'EOF'
---
marp: true
theme: default
paginate: true
---

# My Presentation

A slide deck built from Markdown

---

## Slide Two

- Point one
- Point two
- Point three

---

## Slide Three

### With code!

```python
print("Hello from slides!")
```

---

# Thank You!

Questions?
EOF
```

### 3. Generate Slides

```bash
# HTML (opens in browser)
npx @marp-team/marp-cli my-deck.md --html

# PDF
npx @marp-team/marp-cli my-deck.md --pdf

# PowerPoint
npx @marp-team/marp-cli my-deck.md --pptx
```

## Core Workflows

### Workflow 1: Quick HTML Presentation

**Use case:** Create a slide deck for a meeting

```bash
bash scripts/run.sh --input slides.md --format html
# Output: slides.html (open in any browser)
```

### Workflow 2: PDF for Sharing

**Use case:** Export slides as PDF to share via email/Slack

```bash
bash scripts/run.sh --input slides.md --format pdf
# Output: slides.pdf
```

### Workflow 3: PowerPoint for Corporate

**Use case:** Need PPTX for teams that require PowerPoint

```bash
bash scripts/run.sh --input slides.md --format pptx
# Output: slides.pptx
```

### Workflow 4: Custom Theme

**Use case:** Brand-consistent slides with custom CSS

```bash
bash scripts/run.sh --input slides.md --format pdf --theme scripts/custom-theme.css
# Output: slides.pdf with custom styling
```

### Workflow 5: Watch Mode (Live Preview)

**Use case:** Edit slides and see changes in real-time

```bash
bash scripts/run.sh --input slides.md --watch
# Opens browser with live-reloading preview
```

### Workflow 6: Batch Convert

**Use case:** Convert multiple decks at once

```bash
bash scripts/run.sh --input ./decks/ --format pdf --output ./exports/
# Converts all .md files in decks/ to PDF
```

## Markdown Slide Syntax

### Slide Separators

Use `---` to separate slides:

```markdown
# Slide 1
Content here

---

# Slide 2
More content
```

### Front Matter (Global Settings)

```yaml
---
marp: true
theme: default        # default, gaia, uncover
paginate: true        # page numbers
header: "Company Name"
footer: "Confidential"
backgroundColor: #fff
color: #333
---
```

### Per-Slide Directives

```markdown
<!-- _backgroundColor: #264653 -->
<!-- _color: white -->

# Dark Slide

This slide has a custom background
```

### Images

```markdown
![bg](background.jpg)          # Full background
![bg left](photo.jpg)          # Split: image left, text right
![bg right:40%](photo.jpg)     # Split: 40% image on right
![width:500px](diagram.png)    # Sized inline image
```

### Speaker Notes

```markdown
# My Slide

Visible content here

<!--
Speaker notes go here.
The audience won't see this.
-->
```

### Multi-Column Layout

```markdown
<!-- _class: columns -->

# Two Columns

<div style="display: flex; gap: 2em;">
<div>

**Left Column**
- Item 1
- Item 2

</div>
<div>

**Right Column**
- Item A
- Item B

</div>
</div>
```

## Available Themes

| Theme | Style | Best For |
|-------|-------|----------|
| `default` | Clean, minimal | Technical talks, tutorials |
| `gaia` | Bold, colorful | Keynotes, marketing |
| `uncover` | Elegant, subtle | Business presentations |

### Using Custom CSS Theme

Create a CSS file:

```css
/* custom-theme.css */
section {
  font-family: 'Inter', sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

h1 {
  color: #ffd700;
  text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
}

code {
  background: rgba(255,255,255,0.1);
  border-radius: 4px;
  padding: 2px 6px;
}
```

Apply it:

```bash
bash scripts/run.sh --input slides.md --format pdf --theme custom-theme.css
```

## Configuration

### Environment Variables

```bash
# Chrome/Chromium path (for PDF/PPTX export)
export CHROME_PATH="/usr/bin/chromium-browser"

# Default output directory
export MARP_OUTPUT_DIR="./exports"
```

### Config File (.marprc.yml)

```yaml
# .marprc.yml — place in project root
allowLocalFiles: true
html: true
options:
  looseYAML: false
  markdown:
    breaks: false
```

## Advanced Usage

### Generate with Table of Contents

```bash
# Add --html flag to enable HTML elements in slides
bash scripts/run.sh --input slides.md --format html --html-tags
```

### Export All Formats at Once

```bash
bash scripts/run.sh --input slides.md --format all
# Outputs: slides.html, slides.pdf, slides.pptx
```

### Use with OpenClaw Cron

```bash
# Auto-generate updated slides every hour from a changing source
bash scripts/run.sh --input /path/to/auto-slides.md --format pdf --output /path/to/shared/
```

## Troubleshooting

### Issue: "Chrome/Chromium not found" (PDF/PPTX export)

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install -y chromium-browser

# Or use Puppeteer's bundled Chromium
npx @marp-team/marp-cli --pdf slides.md
# It will download Chromium automatically on first run
```

### Issue: Images not loading in PDF

**Fix:** Use `--allow-local-files` flag:
```bash
npx @marp-team/marp-cli slides.md --pdf --allow-local-files
```

### Issue: Custom fonts not rendering

**Fix:** Install fonts system-wide or use Google Fonts in your theme CSS:
```css
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap');
```

### Issue: Slides look different in PDF vs HTML

**Cause:** PDF rendering uses Chromium's print engine.
**Fix:** Preview in HTML first, then export. Adjust CSS `@media print` rules if needed.

## Dependencies

- `node` (16+) and `npm`
- `@marp-team/marp-cli` (installed via npm)
- `chromium` or `chrome` (for PDF/PPTX export — auto-downloaded if missing)

## Key Principles

1. **Markdown-first** — Write content, not fiddle with GUI
2. **Theme once** — Set CSS theme, reuse across all decks
3. **Version control** — Slides are plain text, perfect for git
4. **Multiple outputs** — One source → HTML, PDF, PPTX
5. **Speaker notes** — HTML comments become speaker notes
