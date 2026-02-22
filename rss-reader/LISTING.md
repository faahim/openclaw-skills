# Listing Copy: RSS Feed Reader

## Metadata
- **Type:** Skill
- **Name:** rss-reader
- **Display Name:** RSS Feed Reader
- **Categories:** [communication, data]
- **Price:** $8
- **Dependencies:** [bash, curl, xmlstarlet]

## Tagline

"Aggregate RSS/Atom feeds — Filter, track, and digest news from the terminal"

## Description

Keeping up with blogs, release notes, and news across dozens of sources means opening tabs, bookmarking, and forgetting. Your agent can't natively parse RSS/Atom XML feeds — it needs xmlstarlet for structured XPath extraction.

RSS Feed Reader fetches any RSS 2.0 or Atom feed, parses items with xmlstarlet, deduplicates against a local seen-state database, filters by keywords, and outputs clean digests. Run it on a cron schedule and get Telegram alerts when new items match your keywords.

**What it does:**
- 📡 Fetch unlimited RSS/Atom feeds with automatic format detection
- 🔍 Filter items by keywords (include/exclude)
- 📊 Track read state — only see new items
- 📝 Generate daily markdown digests grouped by tag
- 🔔 Send Telegram alerts for matching items
- 📦 Import/export OPML feed lists
- ⏰ Cron-ready — schedule fetches and digests

Perfect for developers tracking GitHub releases, sysadmins monitoring changelogs, and anyone who wants a no-nonsense feed reader that runs in their agent.

## Quick Start Preview

```bash
bash scripts/rss-reader.sh init
bash scripts/rss-reader.sh add "https://hnrss.org/frontpage" --tag tech
bash scripts/rss-reader.sh fetch --filter "AI,automation" --alert telegram
```

## Core Capabilities

1. RSS 2.0 + Atom parsing — xmlstarlet XPath extraction handles both formats
2. Keyword filtering — Include/exclude items by comma-separated keywords
3. Read state tracking — md5 hash deduplication, only shows new items
4. Telegram alerts — Instant notification when new items match filters
5. Daily digests — Markdown digest grouped by feed tag
6. OPML import/export — Standard feed list interchange format
7. Tag-based organization — Group feeds by topic (tech, tools, infra, etc.)
8. Cron scheduling — Run on any interval, log to file
9. Graceful failures — Bad feeds warn but don't crash the run
10. Zero external services — Runs locally with curl + xmlstarlet

## Dependencies
- `bash` (4.0+)
- `curl`
- `xmlstarlet` — XML parsing (apt install xmlstarlet)

## Installation Time
**3 minutes** — install xmlstarlet, init, add feeds
