# Listing Copy: Meilisearch Manager

## Metadata
- **Type:** Skill
- **Name:** meilisearch-manager
- **Display Name:** Meilisearch Manager
- **Categories:** [dev-tools, data]
- **Icon:** 🔎
- **Dependencies:** [curl, jq, bash]

## Tagline

Install and manage Meilisearch — lightning-fast full-text search for your apps and data

## Description

Setting up search for your app shouldn't require a PhD in Elasticsearch. But configuring clusters, managing shards, and writing complex query DSL turns a simple feature into a multi-day project. You need search that works in minutes, not weeks.

Meilisearch Manager gives your OpenClaw agent full control over Meilisearch — the blazing-fast, typo-tolerant search engine. Install the binary, start a server, create indexes, ingest documents, and run searches — all through simple bash scripts. No YAML manifests, no Docker compose files, no cloud dashboards.

**What it does:**
- 🚀 One-command install (auto-detects OS/arch, downloads binary)
- 📦 Create and configure indexes with searchable, filterable, and sortable attributes
- 📤 Bulk import documents from JSON/NDJSON files with batch processing
- 🔍 Full-text search with filters, sorting, facets, and highlighting
- 🔐 API key management for multi-tenant setups
- 💾 Backup and restore with dumps and JSON exports
- 🔧 Systemd service installation for production deployments
- 📊 Health monitoring, task tracking, and instance statistics
- 🌐 Nginx reverse proxy config generation

Perfect for developers and indie hackers who want powerful search without Elasticsearch's complexity or Algolia's monthly bill.

## Core Capabilities

1. Binary installation — Auto-detect OS/arch, download and install Meilisearch
2. Server lifecycle — Start, stop, restart, monitor with PID or systemd
3. Index management — Create, delete, list, configure indexes
4. Document ingestion — Bulk import JSON/NDJSON with batching support
5. Full-text search — Queries with filters, sorting, facets, highlighting
6. Settings control — Searchable/filterable/sortable attributes, synonyms, stop words, typo tolerance
7. API key management — Create scoped keys for multi-tenant access
8. Backup & restore — Create dumps, export indexes to JSON
9. Health monitoring — Status checks, task tracking, instance stats
10. Production setup — Systemd service, Nginx reverse proxy config
