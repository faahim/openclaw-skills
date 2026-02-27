---
name: litestream-replication
description: >-
  Continuously replicate SQLite databases to S3-compatible storage with automatic restore and disaster recovery.
categories: [data, automation]
dependencies: [litestream, sqlite3, curl]
---

# Litestream Replication

## What This Does

Continuously replicate your SQLite databases to S3-compatible storage (AWS S3, Backblaze B2, MinIO, DigitalOcean Spaces) in real-time. No cron jobs, no manual backups — every write is streamed to your cloud storage within seconds.

**Example:** "Replicate my production SQLite database to S3 every second, restore to any point in time, get alerted if replication falls behind."

## Quick Start (5 minutes)

### 1. Install Litestream

```bash
# Detect OS and install
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="arm7" ;;
esac

VERSION="v0.3.13"

if command -v litestream &>/dev/null; then
  echo "✅ Litestream already installed: $(litestream version)"
else
  echo "📦 Installing Litestream $VERSION..."
  
  if [ "$OS" = "linux" ]; then
    # Debian/Ubuntu
    if command -v apt-get &>/dev/null; then
      wget -q "https://github.com/benbjohnson/litestream/releases/download/${VERSION}/litestream-${VERSION}-${OS}-${ARCH}.deb" -O /tmp/litestream.deb
      sudo dpkg -i /tmp/litestream.deb
      rm /tmp/litestream.deb
    else
      # Generic Linux
      wget -q "https://github.com/benbjohnson/litestream/releases/download/${VERSION}/litestream-${VERSION}-${OS}-${ARCH}.tar.gz" -O /tmp/litestream.tar.gz
      sudo tar -xzf /tmp/litestream.tar.gz -C /usr/local/bin/
      rm /tmp/litestream.tar.gz
    fi
  elif [ "$OS" = "darwin" ]; then
    brew install benbjohnson/litestream/litestream
  fi
  
  echo "✅ Installed: $(litestream version)"
fi
```

### 2. Configure Replication

```bash
# Set your S3 credentials
export LITESTREAM_ACCESS_KEY_ID="your-access-key"
export LITESTREAM_SECRET_ACCESS_KEY="your-secret-key"

# Create config
cat > /etc/litestream.yml << 'EOF'
dbs:
  - path: /path/to/your/database.db
    replicas:
      - type: s3
        bucket: your-bucket-name
        path: backups/database
        region: us-east-1
        # For non-AWS S3 (Backblaze B2, MinIO, etc.):
        # endpoint: https://s3.us-west-002.backblazeb2.com
        retention: 168h        # Keep 7 days of WAL files
        validation-interval: 6h  # Verify replica every 6 hours
EOF
```

### 3. Start Replication

```bash
# Start continuous replication (foreground)
litestream replicate -config /etc/litestream.yml

# Or run as systemd service
sudo systemctl enable litestream
sudo systemctl start litestream

# Check status
sudo systemctl status litestream
```

## Core Workflows

### Workflow 1: Replicate to AWS S3

**Use case:** Continuously back up a production SQLite database to S3

```bash
cat > /etc/litestream.yml << 'EOF'
access-key-id: ${LITESTREAM_ACCESS_KEY_ID}
secret-access-key: ${LITESTREAM_SECRET_ACCESS_KEY}

dbs:
  - path: /var/lib/myapp/production.db
    replicas:
      - type: s3
        bucket: myapp-backups
        path: production/db
        region: us-east-1
        retention: 720h  # 30 days
        sync-interval: 1s
EOF

litestream replicate -config /etc/litestream.yml
```

**Output:**
```
level=INFO msg="initialized db" path=/var/lib/myapp/production.db
level=INFO msg="replicating to" name=s3 type=s3 bucket=myapp-backups path=production/db
level=INFO msg="write wal segment" path=/var/lib/myapp/production.db index=0000000000000001 offset=0 size=4152
```

### Workflow 2: Replicate to Backblaze B2

**Use case:** Cheap cloud backup with Backblaze ($0.005/GB/month)

```bash
cat > /etc/litestream.yml << 'EOF'
dbs:
  - path: /data/app.db
    replicas:
      - type: s3
        bucket: my-b2-bucket
        path: app-backup
        endpoint: https://s3.us-west-002.backblazeb2.com
        region: us-west-002
        retention: 168h
EOF

export LITESTREAM_ACCESS_KEY_ID="your-b2-key-id"
export LITESTREAM_SECRET_ACCESS_KEY="your-b2-application-key"

litestream replicate -config /etc/litestream.yml
```

### Workflow 3: Restore from Backup

**Use case:** Disaster recovery — restore database from S3

```bash
# Restore latest snapshot
litestream restore -config /etc/litestream.yml /var/lib/myapp/production.db

# Restore to a specific point in time
litestream restore -config /etc/litestream.yml -timestamp "2026-02-27T12:00:00Z" /var/lib/myapp/production.db

# Restore to a different path (safe — doesn't overwrite)
litestream restore -config /etc/litestream.yml -o /tmp/restored.db /var/lib/myapp/production.db

# Verify restored database
sqlite3 /tmp/restored.db "PRAGMA integrity_check;"
```

### Workflow 4: Multiple Databases + Multiple Replicas

**Use case:** Replicate several databases to multiple destinations

```bash
cat > /etc/litestream.yml << 'EOF'
dbs:
  - path: /data/users.db
    replicas:
      - type: s3
        bucket: primary-backups
        path: users
        region: us-east-1
      - type: s3
        bucket: secondary-backups
        path: users
        region: eu-west-1
        
  - path: /data/analytics.db
    replicas:
      - type: s3
        bucket: primary-backups
        path: analytics
        region: us-east-1
        retention: 48h  # Less retention for analytics
EOF
```

### Workflow 5: Run App with Automatic Restore + Replicate

**Use case:** Container/deployment that auto-restores on start, then replicates

```bash
#!/bin/bash
# scripts/run-with-litestream.sh

DB_PATH="/data/app.db"

# Restore if database doesn't exist
if [ ! -f "$DB_PATH" ]; then
  echo "🔄 Restoring database from S3..."
  litestream restore -config /etc/litestream.yml -if-replica-exists "$DB_PATH"
  
  if [ -f "$DB_PATH" ]; then
    echo "✅ Database restored successfully"
  else
    echo "⚠️ No backup found, starting fresh"
  fi
fi

# Start app with litestream wrapping it
exec litestream replicate -exec "node /app/server.js" -config /etc/litestream.yml
```

### Workflow 6: MinIO (Self-Hosted S3)

**Use case:** Replicate to your own MinIO instance (air-gapped / on-prem)

```bash
cat > /etc/litestream.yml << 'EOF'
dbs:
  - path: /data/app.db
    replicas:
      - type: s3
        bucket: db-backups
        path: app
        endpoint: http://minio.local:9000
        region: us-east-1
        force-path-style: true
EOF

export LITESTREAM_ACCESS_KEY_ID="minioadmin"
export LITESTREAM_SECRET_ACCESS_KEY="minioadmin"

litestream replicate -config /etc/litestream.yml
```

## Configuration

### Full Config Reference (YAML)

```yaml
# /etc/litestream.yml

# Global S3 credentials (can be overridden per-replica)
access-key-id: ${LITESTREAM_ACCESS_KEY_ID}
secret-access-key: ${LITESTREAM_SECRET_ACCESS_KEY}

dbs:
  - path: /path/to/database.db
    replicas:
      - type: s3                    # s3, abs (Azure), gcs (Google), sftp
        bucket: bucket-name
        path: prefix/path           # Path within bucket
        region: us-east-1
        endpoint: ""                # Custom S3 endpoint (B2, MinIO, etc.)
        force-path-style: false     # true for MinIO
        retention: 168h             # How long to keep WAL segments (default: 24h)
        retention-check-interval: 1h
        validation-interval: 12h    # How often to verify replica integrity
        sync-interval: 1s           # How often to sync WAL to replica
        snapshot-interval: 24h      # How often to create full snapshots
```

### Environment Variables

```bash
# S3 credentials
export LITESTREAM_ACCESS_KEY_ID="your-key"
export LITESTREAM_SECRET_ACCESS_KEY="your-secret"

# Or use AWS credential chain (instance roles, ~/.aws/credentials, etc.)
```

### Systemd Service

```bash
# Install systemd service
sudo bash scripts/install-service.sh

# Or manually:
cat > /etc/systemd/system/litestream.service << 'EOF'
[Unit]
Description=Litestream SQLite Replication
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/litestream replicate -config /etc/litestream.yml
Restart=always
RestartSec=5
Environment=LITESTREAM_ACCESS_KEY_ID=your-key
Environment=LITESTREAM_SECRET_ACCESS_KEY=your-secret

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now litestream
```

## Advanced Usage

### Docker Integration

```dockerfile
# Dockerfile
FROM litestream/litestream:latest AS litestream
FROM node:20-slim

COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream
COPY litestream.yml /etc/litestream.yml
COPY scripts/run-with-litestream.sh /run.sh

RUN chmod +x /run.sh
CMD ["/run.sh"]
```

### Monitor Replication Lag

```bash
# Check generations (replication history)
litestream generations -config /etc/litestream.yml /path/to/db.db

# Check WAL position
litestream wal -config /etc/litestream.yml /path/to/db.db

# Health check script
bash scripts/health-check.sh /path/to/db.db
```

### Scheduled Integrity Verification

```bash
# Add to crontab — verify replica integrity daily
0 3 * * * /usr/local/bin/litestream restore -config /etc/litestream.yml -o /tmp/verify.db /path/to/db.db && sqlite3 /tmp/verify.db "PRAGMA integrity_check;" && rm /tmp/verify.db
```

## Troubleshooting

### Issue: "no durability" — WAL mode not enabled

**Fix:**
```bash
sqlite3 /path/to/db.db "PRAGMA journal_mode=WAL;"
# Output should be: wal
```

### Issue: "access denied" to S3 bucket

**Check:**
1. Credentials: `echo $LITESTREAM_ACCESS_KEY_ID`
2. Bucket policy allows PutObject, GetObject, ListBucket, DeleteObject
3. Region matches: `aws s3 ls s3://your-bucket --region us-east-1`

### Issue: Replication not starting

**Check:**
```bash
# Verify config
litestream replicate -config /etc/litestream.yml -validate

# Check if database exists
ls -la /path/to/db.db

# Check if another litestream instance is running
pgrep -a litestream
```

### Issue: Restore fails with "no backups found"

**Check:**
```bash
# List available generations
litestream generations -config /etc/litestream.yml /path/to/db.db

# Check S3 bucket directly
aws s3 ls s3://your-bucket/path/ --recursive
```

## Key Principles

1. **WAL mode required** — SQLite must be in WAL journal mode
2. **Sub-second replication** — Changes stream to S3 within ~1 second
3. **Point-in-time restore** — Recover to any moment in your retention window
4. **Zero downtime** — Replication runs alongside your app, no locks
5. **Lightweight** — Single binary, ~10MB, minimal CPU/memory overhead
6. **Multiple replicas** — Send to multiple S3 buckets for redundancy

## Dependencies

- `litestream` (v0.3.13+)
- `sqlite3` (for verification)
- S3-compatible storage (AWS S3, Backblaze B2, MinIO, DigitalOcean Spaces, etc.)
