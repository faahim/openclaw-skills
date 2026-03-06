---
name: docker-registry
description: >-
  Deploy and manage a private Docker container registry with authentication, TLS, garbage collection, and S3 storage support.
categories: [dev-tools, automation]
dependencies: [docker, htpasswd, openssl]
---

# Private Docker Registry

## What This Does

Run your own private Docker registry — push/pull images without Docker Hub rate limits or privacy concerns. Supports authentication, TLS, garbage collection, and optional S3 backend storage.

**Example:** "Set up a private registry on your server, push 50 images, clean up old tags, mirror Docker Hub images locally."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Docker must be installed
which docker || { echo "Install Docker first: https://docs.docker.com/engine/install/"; exit 1; }

# Install apache2-utils for htpasswd (if not present)
which htpasswd || sudo apt-get install -y apache2-utils 2>/dev/null || sudo yum install -y httpd-tools 2>/dev/null
```

### 2. Deploy Registry

```bash
# Run the setup script — creates registry with auth + TLS
bash scripts/setup.sh

# Default: runs on port 5000 with self-signed TLS cert
# Registry data stored in ~/.docker-registry/
```

### 3. Push Your First Image

```bash
# Tag and push
docker tag alpine:latest localhost:5000/alpine:latest
docker push localhost:5000/alpine:latest

# Verify
curl -sk https://localhost:5000/v2/_catalog
# {"repositories":["alpine"]}
```

## Core Workflows

### Workflow 1: Deploy with Authentication

**Use case:** Secure registry requiring login

```bash
# Setup creates a user automatically; add more:
bash scripts/manage.sh add-user myuser mypassword

# Login from any Docker client
docker login localhost:5000
# Username: myuser
# Password: mypassword

# Push image
docker tag myapp:latest localhost:5000/myapp:v1.0
docker push localhost:5000/myapp:v1.0
```

### Workflow 2: List & Manage Images

**Use case:** See what's in your registry

```bash
# List all repositories
bash scripts/manage.sh list

# List tags for a repository
bash scripts/manage.sh tags myapp

# Get image details (digest, size, layers)
bash scripts/manage.sh inspect myapp:v1.0

# Delete a tag
bash scripts/manage.sh delete myapp:v1.0
```

**Output:**
```
📦 Registry: https://localhost:5000
─────────────────────────────────
REPOSITORY     TAGS    SIZE
alpine         3       15.2 MB
myapp          2       245.8 MB
nginx          1       67.3 MB
─────────────────────────────────
Total: 3 repositories, 6 tags, 328.3 MB
```

### Workflow 3: Garbage Collection

**Use case:** Reclaim disk space from deleted images

```bash
# Dry run — see what would be deleted
bash scripts/manage.sh gc --dry-run

# Actually clean up
bash scripts/manage.sh gc

# Schedule automatic weekly cleanup
bash scripts/manage.sh gc --schedule weekly
```

**Output:**
```
🧹 Garbage Collection Results
─────────────────────────────
Blobs eligible:  47
Space reclaimable: 1.2 GB
Status: Cleaned (dry-run: false)
```

### Workflow 4: Mirror Docker Hub

**Use case:** Cache frequently-used images locally to avoid rate limits

```bash
# Configure as a pull-through cache for Docker Hub
bash scripts/setup.sh --mirror

# Now pulls from Docker Hub are cached automatically
docker pull localhost:5000/library/nginx:latest
# First pull: fetches from Docker Hub, caches locally
# Subsequent pulls: served from local cache
```

### Workflow 5: S3 Backend Storage

**Use case:** Store images in cloud storage instead of local disk

```bash
# Configure S3 backend
export REGISTRY_S3_BUCKET="my-registry-bucket"
export REGISTRY_S3_REGION="us-east-1"
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."

bash scripts/setup.sh --storage s3
```

## Configuration

### Environment Variables

```bash
# Registry settings
export REGISTRY_PORT=5000              # Port to listen on
export REGISTRY_DATA_DIR=~/.docker-registry  # Local data directory
export REGISTRY_DOMAIN=localhost       # Domain name (for TLS cert)

# Authentication
export REGISTRY_USER=admin             # Default admin username
export REGISTRY_PASS=changeme          # Default admin password

# TLS (auto-generated self-signed if not provided)
export REGISTRY_TLS_CERT=/path/to/cert.pem
export REGISTRY_TLS_KEY=/path/to/key.pem

# S3 storage (optional)
export REGISTRY_S3_BUCKET=""
export REGISTRY_S3_REGION=""
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""

# Garbage collection
export REGISTRY_GC_SCHEDULE="0 3 * * 0"  # Weekly at 3am Sunday
```

## Advanced Usage

### Remote Access (LAN/Internet)

```bash
# Deploy with your domain name
REGISTRY_DOMAIN=registry.myserver.com bash scripts/setup.sh

# If using Let's Encrypt:
REGISTRY_TLS_CERT=/etc/letsencrypt/live/registry.myserver.com/fullchain.pem \
REGISTRY_TLS_KEY=/etc/letsencrypt/live/registry.myserver.com/privkey.pem \
bash scripts/setup.sh

# From other machines:
docker login registry.myserver.com:5000
docker push registry.myserver.com:5000/myapp:latest
```

### Backup Registry Data

```bash
# Backup all registry data
bash scripts/manage.sh backup /path/to/backup.tar.gz

# Restore from backup
bash scripts/manage.sh restore /path/to/backup.tar.gz
```

### Registry Health Check

```bash
# Check registry status
bash scripts/manage.sh status

# Output:
# ✅ Registry: running (container: docker-registry)
# 📦 Images: 12 repositories, 47 tags
# 💾 Storage: 2.3 GB used (local)
# 🔐 Auth: enabled (3 users)
# 🔒 TLS: self-signed (expires 2027-03-06)
```

### Storage Quotas

```bash
# Set maximum storage (stops accepting pushes when exceeded)
bash scripts/manage.sh set-quota 50GB

# Check current usage
bash scripts/manage.sh disk-usage
```

## Troubleshooting

### Issue: "x509: certificate signed by unknown authority"

**Fix (for self-signed certs):**
```bash
# Copy the CA cert to Docker's trusted certs
sudo mkdir -p /etc/docker/certs.d/localhost:5000
sudo cp ~/.docker-registry/certs/ca.crt /etc/docker/certs.d/localhost:5000/ca.crt
sudo systemctl restart docker
```

### Issue: "unauthorized: authentication required"

**Fix:**
```bash
# Check credentials
bash scripts/manage.sh list-users

# Reset a user's password
bash scripts/manage.sh add-user admin newpassword

# Re-login
docker logout localhost:5000
docker login localhost:5000
```

### Issue: "manifest unknown" after deleting tags

**Fix:** Run garbage collection
```bash
bash scripts/manage.sh gc
```

### Issue: Disk space growing despite deletions

**Cause:** Docker registry uses content-addressable storage. Deleting tags doesn't free space until GC runs.

**Fix:**
```bash
bash scripts/manage.sh gc
```

## Key Principles

1. **Secure by default** — Auth + TLS enabled out of the box
2. **Simple management** — Single script for all operations
3. **Space-efficient** — Automatic garbage collection scheduling
4. **Flexible storage** — Local disk or S3-compatible backends
5. **Production-ready** — Handles restarts, health checks, backups
