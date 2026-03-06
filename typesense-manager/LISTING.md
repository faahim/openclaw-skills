# Listing Copy: Typesense Manager

## Metadata
- **Type:** Skill
- **Name:** typesense-manager
- **Display Name:** Typesense Search Engine Manager
- **Categories:** [dev-tools, data]
- **Icon:** 🔍
- **Dependencies:** [curl, jq, bash]

## Tagline
Install and manage Typesense — blazing-fast, typo-tolerant search for your apps

## Description

Building search into your app usually means wrestling with Elasticsearch's YAML configs, JVM tuning, and 2GB RAM overhead. Typesense is the modern alternative — a single binary that delivers sub-10ms search with built-in typo tolerance.

This skill installs Typesense, manages collections and documents, runs searches, and handles backups — all from your OpenClaw agent. No Docker required, no complex setup.

**What it does:**
- 🚀 One-command install (auto-detects OS/arch, downloads binary)
- 📦 Create collections with typed schemas and facets
- 📄 Index documents individually or bulk-import from JSONL/JSON
- 🔍 Search with typo tolerance, filters, facets, sorting, and geo-search
- 🔑 Manage scoped API keys (search-only, admin, per-collection)
- 📸 Export collections and take full snapshots for backup
- ⚙️ Run as systemd service with auto-restart
- 🔄 Zero-downtime reindexing via collection aliases

Perfect for developers building search features, indie hackers adding search to side projects, or anyone who needs fast full-text search without the Elasticsearch tax.

## Quick Start Preview

```bash
# Install & start
bash scripts/install.sh
bash scripts/run.sh start

# Create collection, index doc, search
bash scripts/manage.sh create-collection '{"name":"books","fields":[{"name":"title","type":"string"},{"name":"author","type":"string","facet":true}]}'
bash scripts/manage.sh index books '{"title":"The Pragmatic Programmer","author":"David Thomas"}'
bash scripts/manage.sh search books "pragmatc programer"  # typo-tolerant!
```

## Core Capabilities

1. Auto-install — Detects Linux/macOS, amd64/arm64, downloads correct binary
2. Server management — Start, stop, restart, health check, systemd service
3. Collection CRUD — Create schemas with typed fields, facets, sorting
4. Document indexing — Single insert or bulk import (JSONL/JSON)
5. Typo-tolerant search — Finds results despite misspellings
6. Filtered search — Filter by fields, facets, geo-radius, price ranges
7. API key management — Scoped keys for search-only or per-collection access
8. Collection aliases — Zero-downtime reindexing for production use
9. Export & backup — JSONL export and full server snapshots
10. Lightweight — ~50MB RAM for small datasets vs 2GB+ for Elasticsearch
