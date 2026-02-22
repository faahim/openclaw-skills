---
name: rss-reader
description: >-
  Aggregate RSS/Atom feeds, filter by keywords, track read state, and generate digests.
categories: [communication, data]
dependencies: [bash, curl, xmlstarlet]
---

# RSS Feed Reader

## What This Does

Aggregates multiple RSS/Atom feeds into a single stream, filters entries by keywords, tracks what you've already seen, and generates clean digests. Perfect for staying on top of blogs, news, GitHub releases, and changelogs without leaving your terminal.

**Example:** "Monitor 15 feeds, show only entries matching 'AI' or 'automation', send a daily Telegram digest of new items."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# xmlstarlet parses RSS/Atom XML — agents can't do this natively
which xmlstarlet || sudo apt-get install -y xmlstarlet
which curl || sudo apt-get install -y curl
```

### 2. Add Your First Feed

```bash
# Initialize config
bash scripts/rss-reader.sh init

# Add feeds
bash scripts/rss-reader.sh add "https://hnrss.org/frontpage" --tag tech
bash scripts/rss-reader.sh add "https://github.com/anthropics/claude-code/releases.atom" --tag tools
bash scripts/rss-reader.sh add "https://blog.cloudflare.com/rss/" --tag infra
```

### 3. Fetch & Read

```bash
# Fetch all feeds and show new items
bash scripts/rss-reader.sh fetch

# Output:
# [2026-02-22 14:00:00] Fetching 3 feeds...
# ✅ hnrss.org/frontpage — 30 items (12 new)
# ✅ github.com/.../releases.atom — 5 items (2 new)
# ✅ blog.cloudflare.com/rss/ — 20 items (8 new)
#
# === 22 New Items ===
#
# [tech] Show HN: I built a CLI for managing RSS feeds
#   https://news.ycombinator.com/item?id=123456
#   2026-02-22 12:30
#
# [tools] Claude Code v1.5.0
#   https://github.com/anthropics/claude-code/releases/tag/v1.5.0
#   2026-02-22 10:00
# ...
```

## Core Workflows

### Workflow 1: Fetch New Items

```bash
# Fetch all feeds, show only NEW (unseen) items
bash scripts/rss-reader.sh fetch

# Fetch specific tag only
bash scripts/rss-reader.sh fetch --tag tech

# Fetch and mark all as read
bash scripts/rss-reader.sh fetch --mark-read
```

### Workflow 2: Filter by Keywords

```bash
# Only show items matching keywords
bash scripts/rss-reader.sh fetch --filter "AI,automation,OpenClaw"

# Exclude items matching keywords
bash scripts/rss-reader.sh fetch --exclude "sponsor,advertisement"
```

### Workflow 3: Generate Digest

```bash
# Generate a markdown digest of today's new items
bash scripts/rss-reader.sh digest

# Output → digest-2026-02-22.md:
# # Feed Digest — Feb 22, 2026
# ## tech (12 new)
# - [Show HN: CLI for RSS](https://...)
# - [New AI model released](https://...)
# ## tools (2 new)
# - [Claude Code v1.5.0](https://...)

# Generate and send via Telegram
bash scripts/rss-reader.sh digest --telegram
```

### Workflow 4: Send Telegram Alert on New Items

```bash
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

# Fetch and alert if new items found
bash scripts/rss-reader.sh fetch --alert telegram --filter "breaking,critical"
```

### Workflow 5: List & Manage Feeds

```bash
# List all feeds
bash scripts/rss-reader.sh list
# Output:
# 1. [tech] https://hnrss.org/frontpage (last: 2026-02-22 14:00)
# 2. [tools] https://github.com/.../releases.atom (last: 2026-02-22 14:00)
# 3. [infra] https://blog.cloudflare.com/rss/ (last: 2026-02-22 14:00)

# Remove a feed
bash scripts/rss-reader.sh remove "https://hnrss.org/frontpage"

# Import OPML file
bash scripts/rss-reader.sh import feeds.opml
```

### Workflow 6: Run on Schedule (Cron)

```bash
# Check feeds every 30 minutes, alert on new items
*/30 * * * * cd /path/to/skill && bash scripts/rss-reader.sh fetch --mark-read --alert telegram >> logs/rss.log 2>&1

# Daily digest at 8am
0 8 * * * cd /path/to/skill && bash scripts/rss-reader.sh digest --telegram >> logs/rss.log 2>&1
```

## Configuration

### Config File (~/.rss-reader/config.yaml)

```yaml
feeds:
  - url: https://hnrss.org/frontpage
    tag: tech
    interval: 1800  # seconds between fetches

  - url: https://github.com/anthropics/claude-code/releases.atom
    tag: tools
    interval: 3600

  - url: https://blog.cloudflare.com/rss/
    tag: infra
    interval: 3600

filters:
  include: []  # empty = show all
  exclude: ["sponsor", "advertisement"]

alerts:
  telegram:
    bot_token: "${TELEGRAM_BOT_TOKEN}"
    chat_id: "${TELEGRAM_CHAT_ID}"

digest:
  format: markdown  # markdown or text
  max_items: 50
  group_by: tag  # tag or date
```

### Environment Variables

```bash
# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Data directory (default: ~/.rss-reader)
export RSS_READER_DIR="$HOME/.rss-reader"
```

## Troubleshooting

### "command not found: xmlstarlet"

```bash
# Ubuntu/Debian
sudo apt-get install -y xmlstarlet
# Mac
brew install xmlstarlet
# Alpine
apk add xmlstarlet
```

### Feed returns empty results

Some feeds require a User-Agent header. The script sets `User-Agent: RSSReader/1.0` by default. If a feed blocks this:

```bash
# Test manually
curl -s -H "User-Agent: Mozilla/5.0" "https://example.com/feed.xml" | head -20
```

### Atom feeds not parsing

The script handles both RSS 2.0 and Atom formats automatically via xmlstarlet XPath queries.

## Key Principles

1. **Track state** — Seen items stored in `~/.rss-reader/seen.db` (plain text hash list)
2. **Fail gracefully** — Bad feeds log warnings, don't crash the whole run
3. **Lightweight** — curl + xmlstarlet, no heavy runtime
4. **OPML compatible** — Import/export standard OPML feed lists

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP fetching)
- `xmlstarlet` (XML/RSS/Atom parsing) — **this is why an agent needs this skill**
- `md5sum` or `sha256sum` (deduplication)
- Optional: `yq` (YAML config parsing, falls back to grep)
