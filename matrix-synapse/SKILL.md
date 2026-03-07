---
name: matrix-synapse
description: >-
  Install and manage a Matrix Synapse homeserver for self-hosted encrypted chat and messaging.
categories: [communication, home]
dependencies: [docker, curl, jq]
---

# Matrix Synapse Manager

## What This Does

Deploy and manage a self-hosted Matrix Synapse homeserver for private, end-to-end encrypted messaging. Matrix is a decentralized communication protocol — think Slack/Discord but fully under your control, with federation support.

**Example:** "Set up a Matrix server on your VPS, create user accounts, manage rooms, monitor server health, and federate with other Matrix servers."

## Quick Start (10 minutes)

### 1. Check Prerequisites

```bash
# Ensure Docker and Docker Compose are installed
which docker docker-compose || which docker compose
# Ensure ports 8008 (client API) and 8448 (federation) are available
```

### 2. Generate Server Config

```bash
# Set your domain (replace with your actual domain)
export MATRIX_DOMAIN="matrix.example.com"
export MATRIX_DATA_DIR="${MATRIX_DATA_DIR:-$HOME/matrix-synapse}"

mkdir -p "$MATRIX_DATA_DIR"

# Generate initial homeserver config
docker run -it --rm \
  -v "$MATRIX_DATA_DIR:/data" \
  -e SYNAPSE_SERVER_NAME="$MATRIX_DOMAIN" \
  -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse:latest generate
```

### 3. Start the Server

```bash
bash scripts/synapse.sh start
```

### 4. Create Your First User

```bash
bash scripts/synapse.sh register admin YourSecurePassword123 --admin
```

### 5. Verify It's Running

```bash
bash scripts/synapse.sh status
# Output:
# ✅ Synapse is running — https://matrix.example.com
# Version: 1.x.x
# Registered users: 1
# Active rooms: 0
```

## Core Workflows

### Workflow 1: Deploy with Docker Compose

**Use case:** Production-ready deployment with PostgreSQL and Nginx reverse proxy

```bash
# Initialize full deployment (generates docker-compose.yml + configs)
bash scripts/synapse.sh init --domain matrix.example.com --with-postgres --with-nginx

# Start all services
bash scripts/synapse.sh start

# Check logs
bash scripts/synapse.sh logs
```

**Generated docker-compose.yml includes:**
- Synapse homeserver
- PostgreSQL database (instead of default SQLite)
- Nginx reverse proxy with SSL termination
- Auto-restart on failure

### Workflow 2: User Management

**Use case:** Create, list, and manage user accounts

```bash
# Register a new user
bash scripts/synapse.sh register alice SecurePass456

# Register an admin user
bash scripts/synapse.sh register bob AdminPass789 --admin

# List all users
bash scripts/synapse.sh users

# Deactivate a user
bash scripts/synapse.sh deactivate @alice:matrix.example.com

# Reset password
bash scripts/synapse.sh reset-password @alice:matrix.example.com NewPassword123
```

### Workflow 3: Room Management

**Use case:** Create and manage chat rooms

```bash
# Create a public room
bash scripts/synapse.sh create-room "General" --public

# Create a private room
bash scripts/synapse.sh create-room "Team Chat" --private

# List all rooms
bash scripts/synapse.sh rooms

# Delete a room (with all messages)
bash scripts/synapse.sh delete-room '!roomid:matrix.example.com'
```

### Workflow 4: Server Health & Monitoring

**Use case:** Check server status and resource usage

```bash
# Full health check
bash scripts/synapse.sh health

# Output:
# ✅ Synapse v1.x.x running
# 📊 Users: 5 registered, 3 active (30d)
# 💬 Rooms: 12 total, 8 active
# 💾 Database: 245 MB
# 🖥️  Memory: 412 MB RSS
# 🌐 Federation: OK (connected to 23 servers)
# ⏱️  Uptime: 14 days, 3 hours

# Check federation status
bash scripts/synapse.sh federation-test

# Purge old messages (keep last 90 days)
bash scripts/synapse.sh purge-history 90
```

### Workflow 5: Backup & Restore

**Use case:** Backup your Matrix data and restore if needed

```bash
# Create a full backup (database + media + config)
bash scripts/synapse.sh backup /path/to/backup/

# Restore from backup
bash scripts/synapse.sh restore /path/to/backup/matrix-backup-2026-03-07.tar.gz
```

## Configuration

### Environment Variables

```bash
# Required
export MATRIX_DOMAIN="matrix.example.com"       # Your server domain
export MATRIX_DATA_DIR="$HOME/matrix-synapse"    # Data directory

# Optional
export MATRIX_DB_TYPE="postgres"                 # postgres or sqlite (default: sqlite)
export MATRIX_DB_HOST="localhost"                 # PostgreSQL host
export MATRIX_DB_NAME="synapse"                  # Database name
export MATRIX_DB_USER="synapse"                  # Database user
export MATRIX_DB_PASS="dbpassword"               # Database password
export MATRIX_ENABLE_REGISTRATION="false"        # Open registration (default: false)
export MATRIX_FEDERATION="true"                  # Enable federation (default: true)
export MATRIX_MAX_UPLOAD_SIZE="50M"              # Max file upload size
export MATRIX_ADMIN_TOKEN=""                     # Admin API token (auto-generated)
```

### Config File Overrides

Edit `$MATRIX_DATA_DIR/homeserver.yaml` for advanced settings:

```yaml
# Key settings to customize:
server_name: "matrix.example.com"
enable_registration: false
enable_registration_without_verification: false
max_upload_size: "50M"

# Rate limiting
rc_message:
  per_second: 0.2
  burst_count: 10

# Media storage
media_store_path: "/data/media_store"
max_upload_size: "50M"

# Logging
log_config: "/data/log.config"
```

## Advanced Usage

### Enable Email Notifications

```bash
bash scripts/synapse.sh configure-email \
  --smtp-host smtp.gmail.com \
  --smtp-port 587 \
  --smtp-user your@gmail.com \
  --smtp-pass "app-password"
```

### Set Up Federation

```bash
# Test federation connectivity
bash scripts/synapse.sh federation-test

# Check .well-known delegation
curl -s https://example.com/.well-known/matrix/server

# Expected: {"m.server": "matrix.example.com:443"}
```

### Enable Bridges (Connect to Other Platforms)

```bash
# Set up Telegram bridge
bash scripts/synapse.sh bridge telegram

# Set up Discord bridge
bash scripts/synapse.sh bridge discord

# Set up IRC bridge
bash scripts/synapse.sh bridge irc
```

### Monitoring with Prometheus

```bash
# Enable Prometheus metrics endpoint
bash scripts/synapse.sh configure-metrics

# Metrics available at http://localhost:9000/_synapse/metrics
```

## Troubleshooting

### Issue: "Connection refused" on port 8008

**Fix:**
```bash
# Check if Synapse is running
docker ps | grep synapse

# Check logs for errors
bash scripts/synapse.sh logs --tail 50

# Restart
bash scripts/synapse.sh restart
```

### Issue: Federation not working

**Check:**
1. DNS SRV record: `dig _matrix._tcp.example.com SRV`
2. .well-known: `curl https://example.com/.well-known/matrix/server`
3. Port 8448 open: `bash scripts/synapse.sh federation-test`
4. SSL certificate valid

### Issue: High memory usage

**Fix:**
```bash
# Purge old data
bash scripts/synapse.sh purge-history 30

# Compress state tables
bash scripts/synapse.sh compress-state

# Restart with lower cache factor
echo "caches:" >> homeserver.yaml
echo "  global_factor: 0.5" >> homeserver.yaml
bash scripts/synapse.sh restart
```

### Issue: Database too large

**Fix:**
```bash
# Check database size
bash scripts/synapse.sh db-size

# Purge old rooms with no local users
bash scripts/synapse.sh purge-empty-rooms

# Vacuum database (SQLite only)
bash scripts/synapse.sh vacuum
```

## Dependencies

- `docker` (20.10+) and `docker compose`
- `curl` (HTTP requests)
- `jq` (JSON parsing)
- `openssl` (certificate generation, optional)
- Optional: `certbot` (Let's Encrypt SSL)

## Key Principles

1. **Encrypted by default** — E2E encryption for all private rooms
2. **Federation-ready** — Connect with the wider Matrix network
3. **Your data** — All messages and media stored on your server
4. **Backup everything** — Automated backup script included
5. **Monitor health** — Built-in health checks and metrics
