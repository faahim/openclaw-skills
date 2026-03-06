---
name: meilisearch-manager
description: >-
  Install, configure, and manage Meilisearch — a lightning-fast, typo-tolerant search engine.
categories: [dev-tools, data]
dependencies: [curl, jq]
---

# Meilisearch Manager

## What This Does

Install and manage Meilisearch, a self-hosted search engine with instant typo-tolerant search. Add documents, configure indexes, manage API keys, and run production deployments — all from the command line.

**Example:** "Install Meilisearch, create a 'products' index, import 10k documents from JSON, and configure searchable/filterable attributes."

## Quick Start (5 minutes)

### 1. Install Meilisearch

```bash
bash scripts/install.sh
```

This installs the latest Meilisearch binary to `/usr/local/bin/meilisearch`.

### 2. Start the Server

```bash
bash scripts/run.sh start
# Meilisearch running at http://localhost:7700
```

### 3. Create an Index and Add Documents

```bash
# Create an index
bash scripts/run.sh create-index movies --primary-key id

# Add documents from a JSON file
bash scripts/run.sh add-docs movies /path/to/movies.json

# Search
bash scripts/run.sh search movies "dark knight"
```

## Core Workflows

### Workflow 1: Install & Run

```bash
# Install latest version
bash scripts/install.sh

# Start with master key (production)
bash scripts/run.sh start --master-key "your-secret-key-min-16-chars"

# Start in development mode (no auth)
bash scripts/run.sh start --env development

# Run as systemd service
bash scripts/install.sh --systemd
sudo systemctl start meilisearch
```

### Workflow 2: Manage Indexes

```bash
# Create index
bash scripts/run.sh create-index products --primary-key id

# List all indexes
bash scripts/run.sh list-indexes

# Configure searchable attributes
bash scripts/run.sh settings products searchable '["name", "description", "brand"]'

# Configure filterable attributes
bash scripts/run.sh settings products filterable '["price", "category", "rating"]'

# Configure sortable attributes
bash scripts/run.sh settings products sortable '["price", "rating", "created_at"]'

# Delete an index
bash scripts/run.sh delete-index products
```

### Workflow 3: Add & Manage Documents

```bash
# Add documents from JSON file
bash scripts/run.sh add-docs products ./data/products.json

# Add documents from JSON string
echo '[{"id":1,"name":"Widget","price":9.99}]' | bash scripts/run.sh add-docs products -

# Get a document by ID
bash scripts/run.sh get-doc products 42

# Delete a document
bash scripts/run.sh delete-doc products 42

# Delete all documents
bash scripts/run.sh delete-all-docs products
```

### Workflow 4: Search

```bash
# Basic search
bash scripts/run.sh search products "wireless headphones"

# Search with filters
bash scripts/run.sh search products "headphones" --filter 'price < 100 AND category = "electronics"'

# Search with sort
bash scripts/run.sh search products "headphones" --sort "price:asc"

# Search with limit
bash scripts/run.sh search products "headphones" --limit 5

# Search with facets
bash scripts/run.sh search products "headphones" --facets '["category", "brand"]'
```

### Workflow 5: Backups & Dumps

```bash
# Create a database dump
bash scripts/run.sh dump

# Check dump status
bash scripts/run.sh tasks

# Export all data (JSON backup)
bash scripts/run.sh export products > products-backup.json
```

### Workflow 6: API Key Management

```bash
# List API keys
bash scripts/run.sh keys list

# Create a search-only key
bash scripts/run.sh keys create --description "Frontend search" --actions '["search"]' --indexes '["products"]'

# Delete a key
bash scripts/run.sh keys delete <key-uid>
```

## Configuration

### Environment Variables

```bash
# Server connection
export MEILI_URL="http://localhost:7700"
export MEILI_MASTER_KEY="your-master-key-min-16-chars"

# For systemd service
export MEILI_DB_PATH="/var/lib/meilisearch/data"
export MEILI_ENV="production"
export MEILI_HTTP_ADDR="127.0.0.1:7700"
export MEILI_LOG_LEVEL="INFO"
```

### Systemd Service File

The installer creates `/etc/systemd/system/meilisearch.service`:

```ini
[Unit]
Description=Meilisearch
After=network.target

[Service]
Type=simple
User=meilisearch
ExecStart=/usr/local/bin/meilisearch --db-path /var/lib/meilisearch/data --env production --master-key YOUR_KEY
Restart=always

[Install]
WantedBy=multi-user.target
```

## Advanced Usage

### Nginx Reverse Proxy

```nginx
server {
    listen 443 ssl;
    server_name search.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:7700;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Index Settings Template

```bash
# Apply full settings from a JSON file
cat > settings.json << 'EOF'
{
  "searchableAttributes": ["name", "description", "tags"],
  "filterableAttributes": ["category", "price", "in_stock", "rating"],
  "sortableAttributes": ["price", "rating", "created_at"],
  "rankingRules": ["words", "typo", "proximity", "attribute", "sort", "exactness"],
  "stopWords": ["the", "a", "an", "is"],
  "synonyms": {
    "phone": ["smartphone", "mobile"],
    "laptop": ["notebook", "computer"]
  },
  "typoTolerance": {
    "enabled": true,
    "minWordSizeForTypos": { "oneTypo": 4, "twoTypos": 8 }
  }
}
EOF

bash scripts/run.sh settings products apply settings.json
```

### Bulk Import with Progress

```bash
# Import large datasets in batches
bash scripts/run.sh bulk-import products ./large-dataset.json --batch-size 10000
```

## Troubleshooting

### Issue: "command not found: meilisearch"

```bash
# Reinstall
bash scripts/install.sh
# Or check PATH
ls -la /usr/local/bin/meilisearch
```

### Issue: "Invalid API key"

```bash
# Check your master key is set
echo $MEILI_MASTER_KEY
# Must be at least 16 characters in production
```

### Issue: Port 7700 already in use

```bash
# Find what's using it
lsof -i :7700
# Start on different port
bash scripts/run.sh start --http-addr "127.0.0.1:7701"
```

### Issue: Large dataset import is slow

```bash
# Use bulk import with batching
bash scripts/run.sh bulk-import products data.json --batch-size 5000
# Check task status
bash scripts/run.sh tasks
```

## Key Principles

1. **Fast setup** — Running in under 5 minutes
2. **Production-ready** — Systemd service, API keys, reverse proxy
3. **Typo-tolerant** — Meilisearch handles typos out of the box
4. **Sub-50ms search** — Returns results in milliseconds
5. **No external deps** — Single binary, no database required

## Dependencies

- `curl` (download + API calls)
- `jq` (JSON parsing)
- `systemd` (optional, for service management)
- Linux amd64 or arm64
