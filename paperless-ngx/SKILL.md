---
name: paperless-ngx
description: >-
  Install, configure, and manage Paperless-ngx — a self-hosted document management system with OCR, tagging, and full-text search.
categories: [data, productivity]
dependencies: [docker, docker-compose, curl, jq]
---

# Paperless-ngx Document Manager

## What This Does

Automate the setup and management of [Paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) — a self-hosted document management system that OCRs your documents, makes them searchable, and organizes them with tags and correspondents. No more filing cabinets or cloud services that mine your data.

**Example:** "Deploy Paperless-ngx with Docker, configure OCR for English + German, set up auto-tagging rules, and back up the database nightly."

## Quick Start (10 minutes)

### 1. Check Dependencies

```bash
bash scripts/install.sh check
# Checks: Docker, Docker Compose, available ports, disk space
```

### 2. Deploy Paperless-ngx

```bash
bash scripts/install.sh deploy
# Pulls images, generates secrets, starts containers
# Default: http://localhost:8000 | admin:changeme
```

### 3. Verify Installation

```bash
bash scripts/run.sh status
# Output:
# ✅ Paperless-ngx running at http://localhost:8000
# ✅ Redis: healthy
# ✅ PostgreSQL: healthy
# ✅ Documents: 0 | Tags: 0 | Correspondents: 0
```

### 4. Upload Your First Document

```bash
# Drop a PDF into the consume directory
bash scripts/run.sh consume /path/to/document.pdf

# Or bulk import a folder
bash scripts/run.sh import /path/to/documents/
```

## Core Workflows

### Workflow 1: Deploy Fresh Instance

```bash
# Deploy with custom settings
bash scripts/install.sh deploy \
  --port 8443 \
  --ocr-languages "eng+deu+fra" \
  --admin-user admin \
  --admin-pass "$(openssl rand -base64 16)" \
  --data-dir /mnt/storage/paperless
```

### Workflow 2: Manage Documents via API

```bash
# Search documents
bash scripts/run.sh search "tax return 2025"

# List recent documents
bash scripts/run.sh list --limit 20 --ordering "-created"

# Get document details
bash scripts/run.sh get --id 42

# Download a document
bash scripts/run.sh download --id 42 --output ./downloads/

# Tag a document
bash scripts/run.sh tag --id 42 --tags "taxes,2025,personal"

# Set correspondent
bash scripts/run.sh correspondent --id 42 --name "IRS"
```

### Workflow 3: Auto-Tagging Rules

```bash
# Create a matching rule: tag "invoice" for docs containing "invoice" or "rechnung"
bash scripts/run.sh rule-add \
  --name "Auto-tag invoices" \
  --match "invoice|rechnung" \
  --match-type regex \
  --assign-tag "invoice"

# List all rules
bash scripts/run.sh rules

# Test a rule against existing documents
bash scripts/run.sh rule-test --id 1
```

### Workflow 4: Backup & Restore

```bash
# Full backup (database + media + config)
bash scripts/run.sh backup --output /backups/paperless-$(date +%Y%m%d).tar.gz

# Scheduled backup (add to cron)
bash scripts/run.sh backup-cron --schedule "0 2 * * *" --output /backups/ --keep 7

# Restore from backup
bash scripts/run.sh restore --input /backups/paperless-20260224.tar.gz
```

### Workflow 5: Monitor & Maintain

```bash
# Health check
bash scripts/run.sh health

# View processing queue
bash scripts/run.sh queue

# View logs (last 50 lines)
bash scripts/run.sh logs --lines 50

# Update to latest version
bash scripts/run.sh update

# Rebuild search index
bash scripts/run.sh reindex
```

## Configuration

### Docker Compose Override

Edit `docker-compose.override.yml` in your data directory to customize:

```yaml
services:
  webserver:
    environment:
      PAPERLESS_OCR_LANGUAGE: eng+deu+fra
      PAPERLESS_OCR_MODE: skip          # skip | redo | force
      PAPERLESS_CONSUMER_POLLING: 30     # seconds
      PAPERLESS_CONSUMER_DELETE_DUPLICATES: "true"
      PAPERLESS_FILENAME_FORMAT: "{created_year}/{correspondent}/{title}"
      PAPERLESS_TIME_ZONE: America/New_York
      PAPERLESS_TASK_WORKERS: 2
      PAPERLESS_THREADS_PER_WORKER: 1
```

### Environment Variables

```bash
# API access (set after deploy)
export PAPERLESS_URL="http://localhost:8000"
export PAPERLESS_TOKEN="your-api-token"

# Generate API token
bash scripts/run.sh token --user admin --pass changeme
```

## Advanced Usage

### Custom File Naming

```bash
# Set filename format
bash scripts/run.sh config set PAPERLESS_FILENAME_FORMAT \
  "{created_year}/{correspondent}/{doc_type}/{title}"

# Rename existing files to match
bash scripts/run.sh rename-files
```

### Email Integration

```bash
# Configure email fetching (checks inbox for attachments)
bash scripts/run.sh email-config \
  --imap-host imap.gmail.com \
  --imap-port 993 \
  --username "you@gmail.com" \
  --password "app-password" \
  --folder INBOX \
  --rule "from:invoices@* -> tag:invoice"
```

### Multi-User Setup

```bash
# Add user
bash scripts/run.sh user-add --username alice --email alice@example.com

# Set permissions
bash scripts/run.sh user-perms --username alice --can-view --can-edit
```

## Troubleshooting

### Issue: OCR not working for some languages

```bash
# Install additional OCR language packs
bash scripts/run.sh ocr-install jpn chi_sim ara
# Restart to apply
bash scripts/run.sh restart
```

### Issue: Consumer not picking up files

**Check:**
1. Consumer directory permissions: `bash scripts/run.sh check-perms`
2. Polling interval: may need to wait up to 30s
3. File format supported: PDF, PNG, JPG, TIFF, TXT, CSV, DOCX, ODT

### Issue: Out of disk space

```bash
# Check disk usage
bash scripts/run.sh disk-usage

# Clean up old thumbnails
bash scripts/run.sh cleanup --thumbnails

# Move data to larger volume
bash scripts/run.sh migrate --new-data-dir /mnt/bigdisk/paperless
```

### Issue: Slow search

```bash
# Rebuild the search index
bash scripts/run.sh reindex
# This may take a while for large libraries
```

## Dependencies

- `docker` (20.10+)
- `docker-compose` (v2+) or `docker compose`
- `curl` (for API calls)
- `jq` (for JSON parsing)
- ~2GB RAM minimum, 4GB recommended
- ~1GB disk for app, plus storage for documents

## Key Principles

1. **Privacy first** — Everything runs locally, no cloud dependency
2. **OCR everything** — Automatic text extraction from scanned documents
3. **Non-destructive** — Originals always preserved alongside OCR'd versions
4. **API-driven** — Full REST API for automation
5. **Backup religiously** — Automated backups with configurable retention
