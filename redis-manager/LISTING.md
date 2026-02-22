# Listing Copy: Redis Manager

## Metadata
- **Type:** Skill
- **Name:** redis-manager
- **Display Name:** Redis Manager
- **Categories:** [dev-tools, data]
- **Icon:** 🔴
- **Price:** $12
- **Dependencies:** [bash, redis-server, redis-cli, jq]

## Tagline

"Install, monitor, and backup Redis — full instance management from your agent"

## Description

Redis is everywhere — caching, sessions, queues, pub/sub — but managing it means SSH-ing into servers, memorizing CLI commands, and hoping you remember to set up backups. Your agent can handle all of this.

Redis Manager installs Redis on any Linux/macOS system, configures memory limits and eviction policies, monitors performance with alerting, manages keys (find large ones, clean up patterns, check TTLs), and automates RDB backups with optional S3 upload. One SKILL.md, zero manual SSH.

**What it does:**
- 🔧 One-command install (Ubuntu, Debian, CentOS, RHEL, macOS, Alpine, Arch)
- 📊 Real-time status dashboard (memory, keys, ops/sec, hit rate, replication)
- 🔔 Continuous monitoring with Telegram/webhook alerts on memory thresholds
- 💾 Automated RDB backups with S3 upload and retention management
- 🔑 Key management — count by pattern, find large keys, bulk delete, TTL reports
- 🔒 Security hardening — passwords, bind address, command disabling
- 🐢 Slow query analysis with optimization suggestions
- 🔄 Replication setup and monitoring
- ⏰ Cron-ready for scheduled health checks and backups

Perfect for developers and sysadmins running Redis in production who want their agent to handle monitoring, backups, and troubleshooting automatically.

## Quick Start Preview

```bash
# Install Redis
bash scripts/install.sh

# Check status
bash scripts/redis-manager.sh status
# → Redis 7.2.4 | Memory: 12.4 MB / 256 MB (4.9%) | Keys: 1,847 | Hit: 94.3%

# Monitor with alerts
bash scripts/redis-manager.sh monitor --interval 30 --alert-memory 80
```

## Core Capabilities

1. Auto-install — Detects OS, installs Redis + tools, enables service
2. Status dashboard — Memory, keys, clients, ops/sec, hit rate, persistence status
3. Performance monitoring — Continuous checks with configurable alerts
4. RDB backups — Trigger BGSAVE, copy dump, upload to S3
5. Key analysis — Count by pattern, find memory hogs, TTL reports
6. Bulk operations — Delete keys by pattern with SCAN (not KEYS)
7. Security hardening — Password, bind address, disable dangerous commands
8. Slow query log — Surface expensive operations, suggest fixes
9. Config management — Set maxmemory, eviction policy, persistence settings
10. Replication — Configure replicas, monitor sync status
