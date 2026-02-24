---
name: lighthouse-auditor
description: >-
  Run Google Lighthouse audits on any URL — get performance, accessibility, SEO, and best practices scores with actionable recommendations.
categories: [dev-tools, analytics]
dependencies: [node, chromium]
---

# Lighthouse Performance Auditor

## What This Does

Runs Google Lighthouse CLI against any URL to generate detailed performance, accessibility, SEO, and best practices reports. Get scores, diagnostics, and actionable recommendations — all from your terminal.

**Example:** "Audit https://mysite.com, get a performance score of 72 with specific recommendations to improve LCP and CLS."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

This installs:
- `lighthouse` CLI (via npm)
- Chromium (if not already available)

### 2. Run Your First Audit

```bash
bash scripts/run.sh --url https://example.com
```

**Output:**
```
🔍 Auditing https://example.com...

═══════════════════════════════════════
  LIGHTHOUSE REPORT — example.com
═══════════════════════════════════════
  Performance:    95 🟢
  Accessibility:  100 🟢
  Best Practices: 100 🟢
  SEO:            90 🟢
═══════════════════════════════════════

Top Issues:
  ⚠️  Serve images in next-gen formats (est. 0.3s savings)
  ⚠️  Eliminate render-blocking resources (est. 0.2s savings)

Full report: /tmp/lighthouse/example.com-2026-02-24.html
```

## Core Workflows

### Workflow 1: Quick Score Check

**Use case:** Get a fast overview of a site's health.

```bash
bash scripts/run.sh --url https://yoursite.com --format summary
```

### Workflow 2: Full HTML Report

**Use case:** Generate a detailed interactive report for sharing.

```bash
bash scripts/run.sh --url https://yoursite.com --format html --output ./reports/
```

Opens or saves a full Lighthouse HTML report with expandable diagnostics.

### Workflow 3: JSON for CI/CD

**Use case:** Integrate into build pipelines, parse scores programmatically.

```bash
bash scripts/run.sh --url https://yoursite.com --format json --output ./reports/

# Parse scores
cat ./reports/latest.json | jq '.categories | to_entries[] | "\(.key): \(.value.score * 100)"'
```

### Workflow 4: Mobile vs Desktop

**Use case:** Compare mobile and desktop performance.

```bash
# Mobile (default Lighthouse behavior)
bash scripts/run.sh --url https://yoursite.com --preset mobile

# Desktop
bash scripts/run.sh --url https://yoursite.com --preset desktop
```

### Workflow 5: Specific Categories Only

**Use case:** Only care about performance, skip the rest.

```bash
bash scripts/run.sh --url https://yoursite.com --only-categories performance,seo
```

### Workflow 6: Multi-URL Batch Audit

**Use case:** Audit multiple pages at once.

```bash
# Create a URL list
cat > urls.txt << 'EOF'
https://yoursite.com
https://yoursite.com/about
https://yoursite.com/blog
https://yoursite.com/contact
EOF

bash scripts/run.sh --batch urls.txt --output ./reports/
```

**Output:**
```
═══════════════════════════════════════════════════
  BATCH AUDIT RESULTS
═══════════════════════════════════════════════════
  URL                         Perf  A11y  BP   SEO
  ─────────────────────────── ───── ───── ──── ────
  /                           92    100   100  90
  /about                      88    95    100  92
  /blog                       65    90    92   85
  /contact                    90    100   100  88
═══════════════════════════════════════════════════
  Worst performer: /blog (Performance: 65)
```

### Workflow 7: Set Score Thresholds (CI Gate)

**Use case:** Fail CI if scores drop below thresholds.

```bash
bash scripts/run.sh \
  --url https://yoursite.com \
  --threshold "performance=80,accessibility=90,seo=80"

# Exit code 0 = all pass, 1 = threshold violated
echo "Exit code: $?"
```

## Configuration

### Environment Variables

```bash
# Custom Chromium path (optional — auto-detected)
export CHROME_PATH="/usr/bin/chromium-browser"

# Output directory (default: /tmp/lighthouse)
export LIGHTHOUSE_OUTPUT_DIR="./reports"

# Default preset (mobile|desktop)
export LIGHTHOUSE_PRESET="desktop"
```

### Config File (Optional)

```yaml
# lighthouse-config.yaml
preset: desktop
output_dir: ./reports
thresholds:
  performance: 80
  accessibility: 90
  best-practices: 90
  seo: 80
urls:
  - https://yoursite.com
  - https://yoursite.com/blog
```

```bash
bash scripts/run.sh --config lighthouse-config.yaml
```

## Advanced Usage

### Run as Cron Job (Weekly Audits)

```bash
# Weekly audit every Monday at 9am
0 9 * * 1 cd /path/to/skill && bash scripts/run.sh --config config.yaml --format json >> /var/log/lighthouse-audit.log 2>&1
```

### Compare Runs Over Time

```bash
# Run multiple audits, compare
bash scripts/run.sh --url https://yoursite.com --format json --output ./reports/run-1.json
# ... make changes ...
bash scripts/run.sh --url https://yoursite.com --format json --output ./reports/run-2.json

# Compare scores
jq -s '.[0].categories.performance.score, .[1].categories.performance.score' ./reports/run-1.json ./reports/run-2.json
```

### Custom Lighthouse Flags

```bash
# Pass any Lighthouse CLI flag
bash scripts/run.sh --url https://yoursite.com --extra-flags "--throttling.cpuSlowdownMultiplier=2 --screenEmulation.disabled"
```

## Troubleshooting

### Issue: "Chrome not found"

**Fix:**
```bash
# Install Chromium
sudo apt-get install -y chromium-browser
# Or set custom path
export CHROME_PATH=$(which chromium-browser || which google-chrome || which chromium)
```

### Issue: "Protocol error" or blank reports

**Fix:** Ensure no other Chrome instances are using the same debugging port:
```bash
bash scripts/run.sh --url https://yoursite.com --extra-flags "--port=9224"
```

### Issue: Scores vary between runs

**Normal** — Lighthouse scores have natural variance (±3-5 points). For stable results:
```bash
# Run 3 times, take median
bash scripts/run.sh --url https://yoursite.com --runs 3
```

### Issue: Timeout on slow sites

**Fix:**
```bash
bash scripts/run.sh --url https://yoursite.com --extra-flags "--max-wait-for-load=60000"
```

## Key Principles

1. **Headless by default** — No GUI needed, runs in any terminal/CI
2. **Actionable output** — Scores + specific fix recommendations
3. **CI-ready** — JSON output + threshold exit codes
4. **Batch support** — Audit entire sites, not just single pages
5. **Reproducible** — Pin presets and flags for consistent results

## Dependencies

- `node` (16+)
- `lighthouse` (npm, installed by install.sh)
- `chromium` or `google-chrome` (installed by install.sh if missing)
- `jq` (optional, for JSON parsing)
