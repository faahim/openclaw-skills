---
name: minio-storage
description: >-
  Install and manage MinIO — self-hosted S3-compatible object storage. Create buckets, manage files, set policies, configure lifecycle rules.
categories: [data, dev-tools]
dependencies: [bash, curl, wget]
---

# MinIO Object Storage Manager

## What This Does

Deploy and manage MinIO, a high-performance S3-compatible object storage server, directly from your OpenClaw agent. Create buckets, upload/download files, set access policies, manage users, and configure lifecycle rules — all without touching a web UI.

**Example:** "Set up a private object storage server, create a `backups` bucket with 30-day retention, and upload tonight's database dump."

## Quick Start (5 minutes)

### 1. Install MinIO Server + Client

```bash
bash scripts/install.sh
```

This installs:
- `minio` server binary
- `mc` (MinIO Client) CLI tool

### 2. Start MinIO Server

```bash
bash scripts/run.sh start \
  --data-dir /data/minio \
  --port 9000 \
  --console-port 9001 \
  --root-user minioadmin \
  --root-password "$(openssl rand -base64 24)"
```

**Output:**
```
✅ MinIO server started
   API:     http://localhost:9000
   Console: http://localhost:9001
   Root user: minioadmin
   Credentials saved to: ~/.minio-creds
```

### 3. Create Your First Bucket

```bash
bash scripts/run.sh create-bucket my-files
```

**Output:**
```
✅ Bucket 'my-files' created
   Endpoint: http://localhost:9000/my-files
```

## Core Workflows

### Workflow 1: Install & Start Server

**Use case:** Fresh MinIO deployment

```bash
# Install (one-time)
bash scripts/install.sh

# Start with custom data directory
bash scripts/run.sh start --data-dir /srv/minio-data
```

### Workflow 2: Bucket Management

```bash
# Create bucket
bash scripts/run.sh create-bucket backups

# List all buckets
bash scripts/run.sh list-buckets

# Delete bucket (must be empty)
bash scripts/run.sh delete-bucket old-bucket

# Get bucket info (size, object count)
bash scripts/run.sh bucket-info backups
```

### Workflow 3: File Operations

```bash
# Upload a file
bash scripts/run.sh upload backups /path/to/db-dump.sql.gz

# Upload entire directory
bash scripts/run.sh upload backups /path/to/logs/ --recursive

# Download a file
bash scripts/run.sh download backups/db-dump.sql.gz /tmp/restore.sql.gz

# List files in bucket
bash scripts/run.sh list backups

# Delete a file
bash scripts/run.sh delete backups/old-dump.sql.gz

# Generate presigned URL (expires in 7 days)
bash scripts/run.sh presign backups/db-dump.sql.gz --expires 7d
```

### Workflow 4: Access Policies

```bash
# Set bucket to public-read
bash scripts/run.sh set-policy backups public-read

# Set bucket to private (default)
bash scripts/run.sh set-policy backups private

# Set bucket to public read+write (careful!)
bash scripts/run.sh set-policy backups public-readwrite

# Create custom policy from JSON
bash scripts/run.sh set-policy backups --custom policy.json
```

### Workflow 5: User Management

```bash
# Create a new user
bash scripts/run.sh create-user appuser "SecurePassword123!"

# Assign policy to user
bash scripts/run.sh assign-policy appuser readwrite

# List users
bash scripts/run.sh list-users

# Delete user
bash scripts/run.sh delete-user appuser
```

### Workflow 6: Lifecycle Rules (Auto-Expiry)

```bash
# Delete objects older than 30 days
bash scripts/run.sh lifecycle backups --expire-days 30

# Move to "cold" tier after 7 days, delete after 90
bash scripts/run.sh lifecycle backups --transition-days 7 --expire-days 90

# Show current lifecycle rules
bash scripts/run.sh lifecycle backups --show

# Remove lifecycle rules
bash scripts/run.sh lifecycle backups --remove
```

### Workflow 7: Server Status & Monitoring

```bash
# Check server status
bash scripts/run.sh status

# Show disk usage
bash scripts/run.sh disk-usage

# Show server info (version, uptime, etc.)
bash scripts/run.sh info

# Stop server
bash scripts/run.sh stop
```

## Configuration

### Environment Variables

```bash
# Server config (saved to ~/.minio-creds on first start)
export MINIO_ROOT_USER="minioadmin"
export MINIO_ROOT_PASSWORD="your-secure-password"
export MINIO_DATA_DIR="/data/minio"
export MINIO_PORT=9000
export MINIO_CONSOLE_PORT=9001

# Client alias (set automatically on start)
export MC_ALIAS="local"
```

### Systemd Service (Auto-Start on Boot)

```bash
bash scripts/run.sh install-service

# This creates /etc/systemd/system/minio.service
# MinIO will auto-start on boot
```

### Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/minio
server {
    listen 443 ssl;
    server_name storage.example.com;

    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Advanced Usage

### S3-Compatible API Access

MinIO is 100% S3-compatible. Use any S3 SDK:

```python
import boto3

s3 = boto3.client('s3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='your-password'
)

# Upload
s3.upload_file('local-file.txt', 'my-bucket', 'remote-file.txt')

# List
for obj in s3.list_objects_v2(Bucket='my-bucket')['Contents']:
    print(obj['Key'], obj['Size'])
```

### Mirror to Remote S3

```bash
# Mirror local bucket to AWS S3
bash scripts/run.sh mirror backups s3/my-aws-bucket

# Mirror from AWS S3 to local
bash scripts/run.sh mirror s3/my-aws-bucket backups
```

### Bucket Notifications (Webhooks)

```bash
# Send webhook on file upload
bash scripts/run.sh notify backups \
  --event put \
  --webhook https://your-app.com/api/webhook
```

### Backup MinIO Data

```bash
# Export all buckets + metadata
bash scripts/run.sh export /backups/minio-export-$(date +%Y%m%d).tar.gz

# Restore from export
bash scripts/run.sh import /backups/minio-export-20260225.tar.gz
```

## Troubleshooting

### Issue: "minio: command not found"

**Fix:** Run the install script:
```bash
bash scripts/install.sh
```

### Issue: "Unable to start server: port 9000 already in use"

**Fix:** Use a different port:
```bash
bash scripts/run.sh start --port 9002 --console-port 9003
```

### Issue: Permission denied on data directory

**Fix:**
```bash
sudo mkdir -p /data/minio
sudo chown $(whoami):$(whoami) /data/minio
```

### Issue: "Access Denied" when uploading

**Check:**
1. Credentials are correct: `cat ~/.minio-creds`
2. User has write permission: `bash scripts/run.sh list-users`
3. Bucket policy allows writes: `bash scripts/run.sh get-policy my-bucket`

### Issue: High memory usage

**Fix:** Set memory limit:
```bash
export MINIO_MEMORY_LIMIT=512M
bash scripts/run.sh start
```

## Dependencies

- `bash` (4.0+)
- `curl` or `wget` (for installation)
- `openssl` (for generating credentials)
- Optional: `systemd` (for auto-start service)
- Optional: `nginx` (for reverse proxy)

## Key Principles

1. **S3-compatible** — Works with any S3 SDK, CLI, or tool
2. **Self-hosted** — Your data stays on your server
3. **Fast** — Written in Go, handles thousands of requests/sec
4. **Secure** — TLS, bucket policies, user access control
5. **Lightweight** — Single binary, minimal resource usage
