# Listing Copy: Meilisearch Manager

## Metadata
- **Type:** Skill
- **Name:** meilisearch-manager
- **Display Name:** Meilisearch Manager
- **Categories:** [dev-tools, data]
- **Icon:** 🔍
- **Price:** $12
- **Dependencies:** [curl, jq]

## Tagline

Install and manage Meilisearch — lightning-fast typo-tolerant search for your apps

## Description

Setting up search for your app shouldn't require Elasticsearch clusters or Algolia subscriptions. Meilisearch is a lightweight, blazing-fast search engine — but installing, configuring indexes, and managing documents still takes work.

Meilisearch Manager handles everything: one-command install, systemd service setup, index management, document imports, search queries, API key management, and backups. Your OpenClaw agent can spin up a production search engine in under 5 minutes.

**What it does:**
- 🚀 One-command install (latest binary, auto-detect architecture)
- 📦 Create and configure indexes with searchable/filterable/sortable attributes
- 📄 Import documents from JSON files with bulk batching for large datasets
- 🔍 Search with filters, sorting, facets, and highlighting
- 🔑 Manage API keys for frontend/backend separation
- 💾 Database dumps and full document export
- ⚙️ Systemd service setup for production deployments
- 🔧 Full settings management (synonyms, stop words, ranking rules, typo tolerance)

Perfect for developers, indie hackers, and self-hosters who want powerful search without the complexity of Elasticsearch or the cost of Algolia.

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Start server
bash scripts/run.sh start --env development

# Create index, add docs, search
bash scripts/run.sh create-index products --primary-key id
bash scripts/run.sh add-docs products ./data.json
bash scripts/run.sh search products "wireless headphones" --filter 'price < 100'
```

## Core Capabilities

1. One-command install — Downloads latest binary, detects amd64/arm64 automatically
2. Systemd service — Production-ready service with auto-restart and master key
3. Index management — Create, list, configure, and delete search indexes
4. Document CRUD — Add, get, delete, and bulk-import documents from JSON
5. Typo-tolerant search — Configurable typo tolerance, synonyms, stop words
6. Filtered search — Filter by attributes, sort results, get facet counts
7. Settings management — Searchable, filterable, sortable attributes + ranking rules
8. API key management — Create scoped keys for frontend search
9. Bulk import — Batch large datasets with configurable batch sizes
10. Backup & export — Database dumps and full JSON document export

## Dependencies
- `curl`
- `jq`
- Linux (amd64 or arm64)
- `systemd` (optional, for service management)

## Installation Time
**5 minutes** — Install binary, start server, create first index
