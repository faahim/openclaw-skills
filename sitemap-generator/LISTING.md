# Listing Copy: Sitemap Generator

## Metadata
- **Type:** Skill
- **Name:** sitemap-generator
- **Display Name:** Sitemap Generator
- **Categories:** [marketing, dev-tools]
- **Price:** $8
- **Dependencies:** [bash, curl]

## Tagline

"Crawl any website and generate a valid XML sitemap — SEO-ready in minutes"

## Description

Your site needs a sitemap for search engines to index it properly, but manually building one is tedious and error-prone. Most sitemap generators are SaaS tools that charge monthly, limit URLs, or require account setup.

Sitemap Generator crawls your website recursively, discovers all internal pages, and produces a standards-compliant `sitemap.xml` with proper `changefreq`, `priority`, and `lastmod` attributes. It runs locally with just bash and curl — no external services, no monthly fees, no URL limits.

**What it does:**
- 🕷️ Recursive BFS crawl with configurable depth (1-10+)
- 📄 Standards-compliant XML output (sitemaps.org schema)
- 🤖 Respects robots.txt disallow rules
- 🔍 Auto-assigns priority based on URL depth
- ⏰ Auto-assigns changefreq based on URL patterns
- 🚫 URL pattern filtering (exclude admin, API, auth pages)
- ✂️ Split large sitemaps (50k+ URLs) into indexed parts
- 🏃 Parallel crawling for speed
- 📊 Dry-run mode to preview URLs before generating

Perfect for developers, indie hackers, and SEO-conscious site owners who want reliable sitemap generation without external dependencies.

## Core Capabilities

1. Recursive website crawling — BFS traversal with depth control
2. XML sitemap generation — Valid sitemaps.org schema output
3. robots.txt compliance — Parses and respects disallow rules
4. Smart priority — Auto-assigns based on URL depth (/ = 1.0, /blog = 0.8, etc.)
5. Smart changefreq — Homepage = daily, blog = weekly, about = monthly
6. URL filtering — Exclude/include patterns via regex
7. Large site support — Split into indexed sub-sitemaps at 50k URLs
8. Polite crawling — Configurable delay and concurrency
9. Dry-run mode — Preview discovered URLs without generating XML
10. Search engine ping — Submit sitemap to Google and Bing after generation

## Dependencies
- `bash` (4.0+)
- `curl`
- `grep`, `sed`, `sort`, `awk` (standard Linux/Mac)

## Installation Time
**2 minutes** — No installation needed, just run the script
