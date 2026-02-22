---
name: s3-file-manager
description: >-
  Manage AWS S3 buckets and files — upload, download, sync, list, delete, and configure lifecycle policies from the command line.
categories: [data, automation]
dependencies: [aws-cli, bash, jq]
---

# S3 File Manager

## What This Does

Manage AWS S3 storage directly from your OpenClaw agent. Upload files, download backups, sync directories, manage bucket lifecycle policies, and monitor storage usage — all through simple bash scripts wrapping the AWS CLI.

**Example:** "Sync my project's build folder to S3, set old files to auto-delete after 90 days, and check how much storage I'm using."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install AWS CLI (if not already installed)
which aws || {
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  cd /tmp && unzip -q awscliv2.zip && sudo ./aws/install
}

# Configure credentials
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Default region, Output format (json)
```

Or set environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

### 2. List Your Buckets

```bash
bash scripts/s3m.sh list-buckets

# Output:
# 📦 S3 Buckets:
# my-app-assets        (us-east-1)  Created: 2025-06-15
# my-backups           (us-east-1)  Created: 2025-08-20
# my-static-site       (us-west-2)  Created: 2026-01-10
```

### 3. Upload a File

```bash
bash scripts/s3m.sh upload ./report.pdf s3://my-bucket/reports/

# Output:
# ✅ Uploaded report.pdf → s3://my-bucket/reports/report.pdf (1.2 MB, 0.8s)
```

## Core Workflows

### Workflow 1: Upload Files

```bash
# Single file
bash scripts/s3m.sh upload ./file.txt s3://bucket/path/

# Directory (recursive)
bash scripts/s3m.sh upload ./build/ s3://bucket/builds/v2/ --recursive

# With public read access
bash scripts/s3m.sh upload ./image.png s3://bucket/public/ --acl public-read
```

### Workflow 2: Download Files

```bash
# Single file
bash scripts/s3m.sh download s3://bucket/data.csv ./local/

# Entire prefix
bash scripts/s3m.sh download s3://bucket/backups/2026-02/ ./local-backups/ --recursive
```

### Workflow 3: Sync Directories

```bash
# Local → S3 (upload new/changed files)
bash scripts/s3m.sh sync ./dist/ s3://bucket/static/ 

# S3 → Local (download new/changed files)
bash scripts/s3m.sh sync s3://bucket/data/ ./local-data/

# Sync with delete (mirror exactly)
bash scripts/s3m.sh sync ./dist/ s3://bucket/static/ --delete

# Sync excluding patterns
bash scripts/s3m.sh sync ./project/ s3://bucket/project/ --exclude "*.log" --exclude "node_modules/*"
```

### Workflow 4: List & Search Files

```bash
# List files in bucket/prefix
bash scripts/s3m.sh ls s3://bucket/reports/

# List with sizes (human-readable)
bash scripts/s3m.sh ls s3://bucket/ --human --recursive

# Search by pattern
bash scripts/s3m.sh find s3://bucket/ "*.pdf"

# Show total size of a prefix
bash scripts/s3m.sh du s3://bucket/backups/
```

### Workflow 5: Delete Files

```bash
# Single file
bash scripts/s3m.sh rm s3://bucket/old-file.txt

# All files with prefix
bash scripts/s3m.sh rm s3://bucket/temp/ --recursive

# Dry run first
bash scripts/s3m.sh rm s3://bucket/temp/ --recursive --dry-run
```

### Workflow 6: Bucket Management

```bash
# Create bucket
bash scripts/s3m.sh create-bucket my-new-bucket --region us-east-1

# Delete empty bucket
bash scripts/s3m.sh delete-bucket my-old-bucket

# Get bucket info (size, object count, region)
bash scripts/s3m.sh bucket-info my-bucket
```

### Workflow 7: Lifecycle Policies

```bash
# Auto-delete files older than 90 days
bash scripts/s3m.sh lifecycle my-bucket --expire-days 90

# Move to Glacier after 30 days, delete after 365
bash scripts/s3m.sh lifecycle my-bucket --glacier-days 30 --expire-days 365

# Auto-delete incomplete multipart uploads after 7 days
bash scripts/s3m.sh lifecycle my-bucket --abort-incomplete-days 7

# Show current lifecycle rules
bash scripts/s3m.sh lifecycle my-bucket --show
```

### Workflow 8: Pre-signed URLs

```bash
# Generate temporary download URL (expires in 1 hour)
bash scripts/s3m.sh presign s3://bucket/private-file.pdf

# Custom expiry (24 hours)
bash scripts/s3m.sh presign s3://bucket/private-file.pdf --expires 86400
```

### Workflow 9: Storage Report

```bash
# Full storage report across all buckets
bash scripts/s3m.sh report

# Output:
# 📊 S3 Storage Report (2026-02-22)
# ┌─────────────────────┬──────────┬─────────┬──────────┐
# │ Bucket              │ Objects  │ Size    │ Region   │
# ├─────────────────────┼──────────┼─────────┼──────────┤
# │ my-app-assets       │ 1,234    │ 2.1 GB  │ us-east-1│
# │ my-backups          │ 567      │ 15.8 GB │ us-east-1│
# │ my-static-site      │ 89       │ 45 MB   │ us-west-2│
# ├─────────────────────┼──────────┼─────────┼──────────┤
# │ Total               │ 1,890    │ 17.9 GB │          │
# └─────────────────────┴──────────┴─────────┴──────────┘
```

## Configuration

### Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# Optional: custom endpoint (MinIO, DigitalOcean Spaces, etc.)
export S3_ENDPOINT_URL="https://nyc3.digitaloceanspaces.com"

# Optional: default bucket
export S3_DEFAULT_BUCKET="my-bucket"
```

### S3-Compatible Services

Works with any S3-compatible storage:

```bash
# DigitalOcean Spaces
bash scripts/s3m.sh upload ./file.txt s3://my-space/path/ --endpoint https://nyc3.digitaloceanspaces.com

# MinIO
bash scripts/s3m.sh upload ./file.txt s3://my-minio/path/ --endpoint http://localhost:9000

# Cloudflare R2
bash scripts/s3m.sh upload ./file.txt s3://my-r2/path/ --endpoint https://ACCOUNT_ID.r2.cloudflarestorage.com
```

## Troubleshooting

### Issue: "Unable to locate credentials"

```bash
# Check if credentials are configured
aws sts get-caller-identity

# If not, configure:
aws configure
# Or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env vars
```

### Issue: "Access Denied"

Check IAM permissions. Minimum policy needed:

```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"],
  "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
}
```

### Issue: Slow uploads for large files

```bash
# Use multipart upload (automatic for files > 8MB)
# Increase parallelism:
aws configure set default.s3.max_concurrent_requests 20
```

## Dependencies

- `aws-cli` (v2 recommended)
- `bash` (4.0+)
- `jq` (JSON parsing for reports)
- Optional: `pv` (progress bars for large transfers)
