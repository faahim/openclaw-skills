---
name: meilisearch-manager
description: >-
  Install, configure, and manage Meilisearch — a lightning-fast, typo-tolerant search engine for your apps and data.
categories: [dev-tools, data]
dependencies: [curl, jq, bash]
---

# Meilisearch Manager

## What This Does

Install and manage [Meilisearch](https://www.meilisearch.com/) — a blazing-fast, typo-tolerant full-text search engine. Create indexes, ingest documents, configure search settings, and monitor your instance. No Elasticsearch complexity, no cloud lock-in.

**Example:** "Install Meilisearch, create a 'products' index, import 10k JSON documents, and configure searchable/filterable attributes — all in 5 minutes."

## Quick Start (5 minutes)

### 1. Install Meilisearch

```bash
# Download and install latest Meilisearch binary
bash scripts/install.sh

# Verify installation
meilisearch --version
```

### 2. Start the Server

```bash
# Start with a master key (required for production)
bash scripts/server.sh start --master-key "$(openssl rand -hex 16)"

# Or start in development mode (no auth)
bash scripts/server.sh start --env development
```

### 3. Create Your First Index & Add Documents

```bash
# Create an index
bash scripts/manage.sh create-index movies --primary-key id

# Add documents from a JSON file
bash scripts/manage.sh add-docs movies /path/to/movies.json

# Search!
bash scripts/manage.sh search movies "star wars"
```

## Core Workflows

### Workflow 1: Install & Run as a Service

**Use case:** Set up Meilisearch as a persistent background service

```bash
# Install binary
bash scripts/install.sh

# Install as systemd service
bash scripts/server.sh install-service --master-key "YOUR_MASTER_KEY" --port 7700

# Manage service
bash scripts/server.sh status
bash scripts/server.sh restart
bash scripts/server.sh logs
```

### Workflow 2: Index Management

**Use case:** Create and configure indexes with custom search settings

```bash
# Create index
bash scripts/manage.sh create-index products --primary-key sku

# Configure searchable attributes (order = priority)
bash scripts/manage.sh settings products searchableAttributes '["name", "description", "category"]'

# Configure filterable attributes
bash scripts/manage.sh settings products filterableAttributes '["price", "category", "inStock"]'

# Configure sortable attributes
bash scripts/manage.sh settings products sortableAttributes '["price", "rating", "createdAt"]'

# Configure ranking rules
bash scripts/manage.sh settings products rankingRules '["words", "typo", "proximity", "attribute", "sort", "exactness"]'

# List all indexes
bash scripts/manage.sh list-indexes
```

### Workflow 3: Document Ingestion

**Use case:** Bulk import documents from JSON/NDJSON files

```bash
# Add documents from JSON file
bash scripts/manage.sh add-docs products /path/to/products.json

# Add documents from NDJSON (one JSON per line)
bash scripts/manage.sh add-docs products /path/to/products.ndjson --format ndjson

# Add documents from stdin (pipe from API, database export, etc.)
curl -s https://api.example.com/products | bash scripts/manage.sh add-docs products -

# Update existing documents (partial update)
bash scripts/manage.sh update-docs products /path/to/updates.json

# Delete specific documents
bash scripts/manage.sh delete-docs products '["id1", "id2", "id3"]'

# Delete all documents in an index
bash scripts/manage.sh delete-all-docs products
```

### Workflow 4: Search & Filtering

**Use case:** Query your data with full-text search, filters, and facets

```bash
# Simple search
bash scripts/manage.sh search products "wireless headphones"

# Search with filters
bash scripts/manage.sh search products "headphones" --filter 'price < 100 AND category = "Electronics"'

# Search with sorting
bash scripts/manage.sh search products "headphones" --sort 'price:asc'

# Search with facets
bash scripts/manage.sh search products "headphones" --facets '["category", "brand"]'

# Search with pagination
bash scripts/manage.sh search products "headphones" --limit 20 --offset 40

# Search with highlighted results
bash scripts/manage.sh search products "headphones" --highlight
```

### Workflow 5: Backup & Restore

**Use case:** Create snapshots and restore data

```bash
# Create a dump (full backup)
bash scripts/manage.sh create-dump

# List dumps
ls -la /var/lib/meilisearch/dumps/

# Restore from dump (restart with dump file)
bash scripts/server.sh start --import-dump /path/to/dump.dump

# Export index to JSON (for external backup)
bash scripts/manage.sh export products > products-backup.json
```

### Workflow 6: Monitoring & Health

**Use case:** Check instance health and task status

```bash
# Health check
bash scripts/manage.sh health

# Get instance stats (documents per index, DB size)
bash scripts/manage.sh stats

# Check task status (indexing progress)
bash scripts/manage.sh tasks

# Get specific task
bash scripts/manage.sh task 42

# Get version info
bash scripts/manage.sh version
```

## Configuration

### Environment Variables

```bash
# Meilisearch connection
export MEILI_HOST="http://localhost:7700"
export MEILI_MASTER_KEY="your-master-key-here"

# Optional: custom data directory
export MEILI_DB_PATH="/var/lib/meilisearch/data"
export MEILI_DUMP_DIR="/var/lib/meilisearch/dumps"

# Optional: performance tuning
export MEILI_MAX_INDEXING_MEMORY="2Gi"
export MEILI_MAX_INDEXING_THREADS="4"
```

### Systemd Service Config

The `install-service` command creates `/etc/systemd/system/meilisearch.service`:

```ini
[Unit]
Description=Meilisearch Search Engine
After=network.target

[Service]
Type=simple
User=meilisearch
ExecStart=/usr/local/bin/meilisearch --env production --master-key ${MEILI_MASTER_KEY} --http-addr 0.0.0.0:7700 --db-path /var/lib/meilisearch/data --dump-dir /var/lib/meilisearch/dumps
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## Advanced Usage

### Multi-Tenant Setup

```bash
# Use tenant tokens for API key scoping
bash scripts/manage.sh create-key --description "Frontend search" \
  --actions '["search"]' \
  --indexes '["products", "articles"]' \
  --expires-at "2027-01-01T00:00:00Z"

# List API keys
bash scripts/manage.sh list-keys
```

### Synonyms & Stop Words

```bash
# Add synonyms
bash scripts/manage.sh settings products synonyms '{"phone": ["smartphone", "mobile"], "laptop": ["notebook", "computer"]}'

# Add stop words
bash scripts/manage.sh settings products stopWords '["the", "a", "an", "is", "are"]'

# Add typo tolerance settings
bash scripts/manage.sh settings products typoTolerance '{"enabled": true, "minWordSizeForTypos": {"oneTypo": 4, "twoTypos": 8}}'
```

### Reverse Proxy with Nginx

```bash
# Generate Nginx config for Meilisearch
bash scripts/manage.sh nginx-config --domain search.example.com --port 7700
```

## Troubleshooting

### Issue: "connection refused" on port 7700

**Fix:**
```bash
# Check if Meilisearch is running
bash scripts/server.sh status

# Check if port is in use
ss -tlnp | grep 7700

# Start the server
bash scripts/server.sh start
```

### Issue: "Invalid API key"

**Fix:**
```bash
# Check your master key
echo $MEILI_MASTER_KEY

# Generate API keys from master key
bash scripts/manage.sh list-keys
```

### Issue: Slow indexing

**Fix:**
```bash
# Increase memory and threads
export MEILI_MAX_INDEXING_MEMORY="4Gi"
export MEILI_MAX_INDEXING_THREADS="$(nproc)"
bash scripts/server.sh restart
```

### Issue: Large payload rejected

**Fix:**
```bash
# Meilisearch accepts up to 100MB per batch
# Split large files:
bash scripts/manage.sh add-docs products /path/to/huge.json --batch-size 10000
```

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to Meilisearch API)
- `jq` (JSON processing)
- `openssl` (key generation)
- Optional: `systemd` (service management)
- Optional: `nginx` (reverse proxy)
