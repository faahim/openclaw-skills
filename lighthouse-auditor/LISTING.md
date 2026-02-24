# Listing Copy: Lighthouse Performance Auditor

## Metadata
- **Type:** Skill
- **Name:** lighthouse-auditor
- **Display Name:** Lighthouse Performance Auditor
- **Categories:** [dev-tools, analytics]
- **Price:** $12
- **Dependencies:** [node, chromium]

## Tagline

Run Lighthouse audits on any URL — get performance, accessibility, and SEO scores with fix recommendations.

## Description

Slow websites lose users. Poor accessibility excludes people. Bad SEO means nobody finds you. But manually running Lighthouse in Chrome DevTools for every page is tedious — and impossible to automate.

Lighthouse Auditor runs Google's Lighthouse CLI against any URL (or batch of URLs) and delivers clear scores with actionable fix recommendations. No browser needed — it runs headless in your terminal. Perfect for CI/CD gates, weekly site health checks, or quick audits before launch.

**What it does:**
- 🏎️ Performance scoring with specific optimization recommendations
- ♿ Accessibility audit against WCAG guidelines
- 🔍 SEO audit with indexability checks
- ✅ Best practices verification (HTTPS, console errors, etc.)
- 📊 Batch mode — audit entire sites at once
- 🚦 Threshold gates — fail CI if scores drop below minimums
- 📈 Multi-run median — stable scores for tracking over time
- 📄 HTML, JSON, and summary output formats

Perfect for developers, DevOps engineers, and anyone who needs reliable, automated web performance monitoring.

## Quick Start Preview

```bash
bash scripts/run.sh --url https://yoursite.com

# Output:
# 🔍 Auditing https://yoursite.com...
# ═══════════════════════════════════════
#   Performance:    92 🟢
#   Accessibility:  100 🟢
#   Best Practices: 100 🟢
#   SEO:            90 🟢
# ═══════════════════════════════════════
#   ⚠️  Serve images in next-gen formats (est. 0.3s savings)
```

## Core Capabilities

1. URL auditing — Run Lighthouse on any publicly accessible URL
2. Performance diagnostics — LCP, FID, CLS, TTFB with specific fix suggestions
3. Accessibility checks — WCAG compliance, contrast ratios, ARIA labels
4. SEO analysis — Meta tags, indexability, structured data, mobile-friendly
5. Batch auditing — Audit dozens of URLs from a file, get a comparison table
6. CI/CD thresholds — Set minimum scores, get non-zero exit code on failure
7. Multiple runs — Run N times, report median for stable tracking
8. Mobile & desktop — Switch presets with one flag
9. HTML reports — Generate shareable interactive Lighthouse reports
10. JSON output — Parse programmatically for dashboards and alerts
11. Headless — No GUI needed, runs on any server or CI runner
12. Auto-install — One script installs Lighthouse + Chromium

## Dependencies
- `node` (16+)
- `chromium` or `google-chrome`
- `jq` (optional)

## Installation Time
**5 minutes** — Run install.sh, start auditing

## Pricing Justification

**Why $12:**
- Comparable services: PageSpeed Insights (free but manual), SpeedCurve ($12-50/mo), Calibre ($30/mo)
- One-time payment vs recurring SaaS fees
- Self-hosted, no data sent to third parties
- Full automation + CI integration
