---
name: sitemap-generator
description: >-
  Crawl any website and generate a valid XML sitemap with changefreq, priority, and lastmod. Supports depth limits, pattern filtering, and robots.txt compliance.
categories: [marketing, dev-tools]
dependencies: [bash, curl]
---

# Sitemap Generator

## What This Does

Crawls a website recursively, discovers all internal pages, and generates a standards-compliant `sitemap.xml` file. Respects robots.txt, supports depth limits, URL pattern filtering, and outputs proper XML with changefreq/priority attributes.

**Example:** "Crawl https://example.com up to 3 levels deep, exclude /admin/* paths, generate sitemap.xml with 247 URLs."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
which curl grep sed sort || echo "Install missing: apt-get install curl grep sed"
```

### 2. Generate a Sitemap

```bash
bash scripts/crawl.sh --url https://example.com --depth 3 --output sitemap.xml
```

### 3. View Results

```bash
head -20 sitemap.xml
echo "Total URLs: $(grep -c '<url>' sitemap.xml)"
```

## Core Workflows

### Workflow 1: Basic Site Crawl

```bash
bash scripts/crawl.sh --url https://yoursite.com --depth 2

# Output:
# [crawl] Starting: https://yoursite.com (depth: 2)
# [crawl] Found: https://yoursite.com/ (200)
# [crawl] Found: https://yoursite.com/about (200)
# [crawl] Found: https://yoursite.com/blog (200)
# ...
# [done] 47 URLs → sitemap.xml
```

### Workflow 2: Filtered Crawl

Exclude admin, API, and auth pages:

```bash
bash scripts/crawl.sh \
  --url https://yoursite.com \
  --depth 3 \
  --exclude '/admin|/api/|/auth|/login|\.pdf$|\.zip$' \
  --output sitemap.xml
```

### Workflow 3: Respect robots.txt

```bash
bash scripts/crawl.sh \
  --url https://yoursite.com \
  --depth 3 \
  --respect-robots \
  --output sitemap.xml
```

### Workflow 4: Generate Sitemap Index (Large Sites)

For sites with 50,000+ URLs, split into multiple sitemaps:

```bash
bash scripts/crawl.sh \
  --url https://yoursite.com \
  --depth 5 \
  --max-urls 50000 \
  --split 10000 \
  --output-dir sitemaps/

# Creates:
# sitemaps/sitemap-1.xml (10,000 URLs)
# sitemaps/sitemap-2.xml (10,000 URLs)
# sitemaps/sitemap-index.xml (references all parts)
```

### Workflow 5: Dry Run (List URLs Only)

```bash
bash scripts/crawl.sh \
  --url https://yoursite.com \
  --depth 2 \
  --dry-run

# Prints URLs to stdout without generating XML
```

## Configuration

### Command-Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `--url` | (required) | Root URL to crawl |
| `--depth` | `3` | Maximum crawl depth |
| `--output` | `sitemap.xml` | Output file path |
| `--exclude` | (none) | Regex pattern to exclude URLs |
| `--include` | (none) | Regex pattern — only include matching URLs |
| `--delay` | `0.5` | Seconds between requests (be polite) |
| `--timeout` | `10` | HTTP timeout per request (seconds) |
| `--max-urls` | `50000` | Maximum URLs to include |
| `--user-agent` | `SitemapBot/1.0` | User-Agent header |
| `--respect-robots` | off | Parse and respect robots.txt |
| `--changefreq` | `weekly` | Default change frequency |
| `--priority` | `0.5` | Default priority (0.0-1.0) |
| `--dry-run` | off | List URLs without generating XML |
| `--split` | (none) | Split sitemap every N URLs |
| `--output-dir` | `.` | Directory for split sitemaps |
| `--concurrency` | `5` | Parallel requests (uses xargs) |

### Priority Rules

The script auto-assigns priority based on URL depth:
- `/` → 1.0
- `/about`, `/blog` → 0.8
- `/blog/post-1` → 0.6
- `/blog/2024/01/post` → 0.4
- Deeper → 0.3

### Change Frequency Rules

Auto-assigned based on URL patterns:
- Homepage → `daily`
- Blog/news → `weekly`
- About/contact → `monthly`
- Everything else → `weekly`

## Output Format

### Standard sitemap.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://yoursite.com/</loc>
    <lastmod>2026-02-26</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://yoursite.com/about</loc>
    <lastmod>2026-02-26</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
</urlset>
```

### Sitemap Index (for split sitemaps)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>https://yoursite.com/sitemap-1.xml</loc>
    <lastmod>2026-02-26</lastmod>
  </sitemap>
  <sitemap>
    <loc>https://yoursite.com/sitemap-2.xml</loc>
    <lastmod>2026-02-26</lastmod>
  </sitemap>
</sitemapindex>
```

## Advanced Usage

### Submit to Search Engines

After generating your sitemap:

```bash
# Google
curl "https://www.google.com/ping?sitemap=https://yoursite.com/sitemap.xml"

# Bing
curl "https://www.bing.com/ping?sitemap=https://yoursite.com/sitemap.xml"
```

### Schedule Regular Regeneration

```bash
# Crontab: regenerate weekly
0 3 * * 0 cd /path/to/skill && bash scripts/crawl.sh --url https://yoursite.com --depth 3 --output /var/www/html/sitemap.xml
```

### Compare Sitemaps

```bash
# Diff old vs new
diff <(grep '<loc>' old-sitemap.xml | sort) <(grep '<loc>' sitemap.xml | sort)
```

## Troubleshooting

### Issue: Too slow on large sites

**Fix:** Increase concurrency and reduce delay:
```bash
bash scripts/crawl.sh --url https://yoursite.com --concurrency 10 --delay 0.1
```

### Issue: Missing pages

**Check:**
1. Increase depth: `--depth 5`
2. Check if pages require JavaScript (this crawls HTML only)
3. Check robots.txt isn't blocking the crawler

### Issue: Duplicate URLs

The script deduplicates automatically (normalizes trailing slashes, query params). If still seeing dupes, use `--exclude` to filter query strings:
```bash
--exclude '\?utm_|#'
```

### Issue: Permission denied / 403 errors

**Fix:** Set a realistic User-Agent:
```bash
--user-agent "Mozilla/5.0 (compatible; SitemapBot/1.0)"
```

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests)
- `grep`, `sed`, `sort`, `awk` (text processing — standard on Linux/Mac)
- Optional: `xargs` (parallel crawling — standard on most systems)
