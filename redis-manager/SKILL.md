---
name: redis-manager
description: >-
  Install, configure, monitor, and backup Redis instances from the command line.
categories: [dev-tools, data]
dependencies: [bash, curl, redis-server, redis-cli]
---

# Redis Manager

## What This Does

Install Redis, configure instances, monitor memory/performance, manage keys, and automate backups — all from your OpenClaw agent. No more SSH-ing in to check Redis health or manually dumping RDB files.

**Example:** "Install Redis, set max memory to 256MB with LRU eviction, monitor key count and memory usage, backup to S3 every 6 hours."

## Quick Start (5 minutes)

### 1. Install Redis

```bash
bash scripts/install.sh
```

This detects your OS (Ubuntu/Debian, RHEL/CentOS, macOS) and installs Redis server + CLI tools.

### 2. Check Status

```bash
bash scripts/redis-manager.sh status
```

**Output:**
```
Redis Status
════════════════════════════════════════
  Version:      7.2.4
  Uptime:       3 days, 14:22:05
  Mode:         standalone
  Port:         6379
  PID:          1234
  Memory Used:  12.45 MB / 256.00 MB (4.9%)
  Keys:         1,847
  Clients:      5 connected
  Ops/sec:      142
  Hit Rate:     94.3%
  RDB Status:   Last save 2 min ago (OK)
  AOF Status:   disabled
════════════════════════════════════════
```

### 3. Configure Memory Limit

```bash
bash scripts/redis-manager.sh config --maxmemory 256mb --eviction allkeys-lru
```

## Core Workflows

### Workflow 1: Install & Harden Redis

**Use case:** Fresh server setup with security best practices

```bash
# Install Redis
bash scripts/install.sh

# Harden: set password, disable dangerous commands, bind to localhost
bash scripts/redis-manager.sh harden \
  --password "$(openssl rand -base64 32)" \
  --bind 127.0.0.1 \
  --disable-commands "FLUSHALL FLUSHDB DEBUG KEYS"
```

**Output:**
```
✅ Password set (saved to ~/.redis-manager/credentials)
✅ Bound to 127.0.0.1
✅ Disabled commands: FLUSHALL, FLUSHDB, DEBUG, KEYS
✅ Redis restarted with new config
```

### Workflow 2: Monitor Performance

**Use case:** Check Redis health and get alerts on issues

```bash
# One-shot health check
bash scripts/redis-manager.sh health

# Continuous monitoring (every 30 seconds)
bash scripts/redis-manager.sh monitor --interval 30

# Alert if memory exceeds 80%
bash scripts/redis-manager.sh monitor --interval 60 \
  --alert-memory 80 \
  --alert-cmd 'curl -s "https://api.telegram.org/bot$TG_TOKEN/sendMessage?chat_id=$TG_CHAT&text=Redis memory at $MEMORY_PCT%"'
```

**Output:**
```
[2026-02-22 12:00:00] ✅ Memory: 45.2 MB / 256 MB (17.7%) | Keys: 12,341 | Ops/s: 230 | Hit: 96.1%
[2026-02-22 12:00:30] ✅ Memory: 45.8 MB / 256 MB (17.9%) | Keys: 12,389 | Ops/s: 245 | Hit: 96.0%
[2026-02-22 12:01:00] ⚠️ Memory: 205.3 MB / 256 MB (80.2%) | Keys: 98,412 | Ops/s: 1,203 | Hit: 72.4%
🚨 Alert sent: Redis memory at 80.2%
```

### Workflow 3: Backup & Restore

**Use case:** Automated RDB snapshots with optional upload to S3

```bash
# Create backup (RDB dump)
bash scripts/redis-manager.sh backup --output /backups/redis/

# Backup with S3 upload
bash scripts/redis-manager.sh backup \
  --output /tmp/redis-backup/ \
  --s3-bucket my-backups \
  --s3-prefix redis/

# Restore from backup
bash scripts/redis-manager.sh restore --file /backups/redis/dump-2026-02-22T120000.rdb

# List available backups
bash scripts/redis-manager.sh backup --list --output /backups/redis/
```

**Output:**
```
[2026-02-22 12:00:00] Triggering BGSAVE...
[2026-02-22 12:00:02] ✅ RDB saved: /backups/redis/dump-2026-02-22T120000.rdb (4.2 MB)
[2026-02-22 12:00:05] ✅ Uploaded to s3://my-backups/redis/dump-2026-02-22T120000.rdb
```

### Workflow 4: Key Management

**Use case:** Inspect, search, and clean up keys

```bash
# Count keys by pattern
bash scripts/redis-manager.sh keys --count "session:*"

# Find large keys (top 20 by memory)
bash scripts/redis-manager.sh keys --big 20

# Delete keys matching pattern (with confirmation)
bash scripts/redis-manager.sh keys --delete "cache:expired:*"

# Export keys matching pattern to JSON
bash scripts/redis-manager.sh keys --export "user:*" --output users.json

# Get key TTL report
bash scripts/redis-manager.sh keys --ttl-report
```

**Output:**
```
Key Pattern Analysis: session:*
════════════════════════════════════
  Matching Keys:  4,231
  Total Memory:   18.3 MB
  Avg TTL:        3,600s (1 hour)
  Types:          string: 4,012 | hash: 219
════════════════════════════════════
```

### Workflow 5: Slow Query Analysis

**Use case:** Find and fix slow Redis commands

```bash
# Show slowlog (last 25 entries)
bash scripts/redis-manager.sh slowlog

# Set slow query threshold
bash scripts/redis-manager.sh config --slowlog-threshold 10000  # 10ms
```

**Output:**
```
Slow Queries (last 25)
═══════════════════════════════════════════════════════
  #1  32ms  KEYS *              (2026-02-22 11:45:12)
  #2  18ms  SMEMBERS bigset     (2026-02-22 11:42:03)
  #3  12ms  LRANGE mylist 0 -1  (2026-02-22 11:38:55)
═══════════════════════════════════════════════════════
⚠️ KEYS * detected — use SCAN instead for production
```

## Configuration

### Environment Variables

```bash
# Redis connection (defaults shown)
export REDIS_HOST="127.0.0.1"
export REDIS_PORT="6379"
export REDIS_PASSWORD=""          # or read from ~/.redis-manager/credentials

# S3 backup (optional)
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"

# Telegram alerts (optional)
export TG_TOKEN="<bot-token>"
export TG_CHAT="<chat-id>"
```

### Config File

```yaml
# ~/.redis-manager/config.yaml
connection:
  host: 127.0.0.1
  port: 6379
  password: ""  # or path to credentials file

monitoring:
  interval: 30          # seconds
  alert_memory_pct: 80
  alert_clients: 100
  alert_ops_sec: 5000

backup:
  output: /var/backups/redis
  retention_days: 30
  s3_bucket: ""
  s3_prefix: "redis/"

security:
  disable_commands: [FLUSHALL, FLUSHDB, DEBUG]
  bind: 127.0.0.1
```

## Advanced Usage

### Run as Cron Job

```bash
# Health check every 5 minutes
*/5 * * * * bash /path/to/scripts/redis-manager.sh health --quiet --alert-memory 80 >> /var/log/redis-monitor.log 2>&1

# Backup every 6 hours
0 */6 * * * bash /path/to/scripts/redis-manager.sh backup --output /var/backups/redis/ --s3-bucket my-backups >> /var/log/redis-backup.log 2>&1

# Weekly key analysis
0 2 * * 0 bash /path/to/scripts/redis-manager.sh keys --big 50 --ttl-report >> /var/log/redis-keys.log 2>&1
```

### Multi-Instance Management

```bash
# Check status of multiple instances
for port in 6379 6380 6381; do
  echo "=== Redis :$port ==="
  REDIS_PORT=$port bash scripts/redis-manager.sh status
done
```

### Replication Setup

```bash
# Configure as replica
bash scripts/redis-manager.sh replicate --master-host 10.0.0.1 --master-port 6379

# Check replication status
bash scripts/redis-manager.sh replication-status
```

## Troubleshooting

### Issue: "Could not connect to Redis"

```bash
# Check if Redis is running
systemctl status redis-server 2>/dev/null || brew services info redis 2>/dev/null

# Check if port is open
ss -tlnp | grep 6379

# Test connection
redis-cli -h $REDIS_HOST -p $REDIS_PORT ping
```

### Issue: "OOM command not allowed"

Redis is out of memory. Fix:
```bash
# Check current memory
bash scripts/redis-manager.sh status

# Increase limit
bash scripts/redis-manager.sh config --maxmemory 512mb --eviction allkeys-lru

# Or find and remove large keys
bash scripts/redis-manager.sh keys --big 20
```

### Issue: High latency

```bash
# Check slowlog
bash scripts/redis-manager.sh slowlog

# Check if persistence is causing issues
bash scripts/redis-manager.sh health --verbose

# Common fix: switch from KEYS to SCAN
```

## Dependencies

- `bash` (4.0+)
- `redis-server` + `redis-cli` (installed by scripts/install.sh)
- `jq` (JSON parsing)
- `aws` CLI (optional, for S3 backups)
- `curl` (optional, for alerts)
