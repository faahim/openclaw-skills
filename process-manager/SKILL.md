---
name: process-manager
description: >-
  Manage long-running processes with auto-restart, log rotation, startup persistence, and monitoring using PM2.
categories: [dev-tools, automation]
dependencies: [node, npm]
---

# Process Manager

## What This Does

Manage any long-running process (Node.js, Python, Bash, Go binaries) with automatic restart on crash, log rotation, startup persistence across reboots, and real-time monitoring. Uses PM2 under the hood — the industry-standard process manager used in production by millions of servers.

**Example:** "Run 3 API servers, auto-restart on crash, rotate logs daily, survive reboots, monitor CPU/memory."

## Quick Start (3 minutes)

### 1. Install PM2

```bash
bash scripts/install.sh
```

This installs PM2 globally and configures startup persistence.

### 2. Start Your First Process

```bash
# Start any command as a managed process
bash scripts/run.sh start --name "my-api" --cmd "node server.js" --cwd /path/to/project

# Start a Python script
bash scripts/run.sh start --name "worker" --cmd "python3 worker.py" --cwd /home/user/app

# Start a plain bash script
bash scripts/run.sh start --name "watcher" --cmd "bash watch.sh"
```

### 3. Check Status

```bash
bash scripts/run.sh status

# Output:
# ┌─────┬──────────┬─────┬──────┬───────┬────────┬─────────┐
# │ id  │ name     │ pid │ mode │ ↺     │ status │ cpu/mem  │
# ├─────┼──────────┼─────┼──────┼───────┼────────┼─────────┤
# │ 0   │ my-api   │ 1234│ fork │ 0     │ online │ 0.1/25M │
# │ 1   │ worker   │ 1235│ fork │ 0     │ online │ 0.3/40M │
# └─────┴──────────┴─────┴──────┴───────┴────────┴─────────┘
```

## Core Workflows

### Workflow 1: Start a Process

```bash
# Basic start
bash scripts/run.sh start --name "api" --cmd "node index.js" --cwd /app

# With environment variables
bash scripts/run.sh start --name "api" --cmd "node index.js" --cwd /app --env "PORT=3000,NODE_ENV=production"

# With max memory restart (restart if exceeds 500MB)
bash scripts/run.sh start --name "api" --cmd "node index.js" --max-memory 500

# With cluster mode (4 instances for load balancing)
bash scripts/run.sh start --name "api" --cmd "node index.js" --instances 4
```

### Workflow 2: Manage Processes

```bash
# Stop a process
bash scripts/run.sh stop my-api

# Restart a process
bash scripts/run.sh restart my-api

# Restart all processes
bash scripts/run.sh restart all

# Delete a process from PM2
bash scripts/run.sh delete my-api

# Reload with zero downtime (cluster mode)
bash scripts/run.sh reload my-api
```

### Workflow 3: View Logs

```bash
# Stream all logs
bash scripts/run.sh logs

# Stream logs for specific process
bash scripts/run.sh logs my-api

# Last 100 lines
bash scripts/run.sh logs my-api --lines 100

# Flush (clear) logs
bash scripts/run.sh flush my-api
```

### Workflow 4: Monitor Resources

```bash
# Real-time dashboard
bash scripts/run.sh monit

# JSON status with CPU/memory details
bash scripts/run.sh describe my-api
```

### Workflow 5: Ecosystem File (Multiple Processes)

```bash
# Generate ecosystem config from template
cp scripts/ecosystem-template.config.js ecosystem.config.js

# Edit ecosystem.config.js, then:
bash scripts/run.sh ecosystem ecosystem.config.js
```

### Workflow 6: Startup Persistence

```bash
# Save current process list (survives reboot)
bash scripts/run.sh save

# Generate startup script (auto-start on boot)
bash scripts/run.sh startup
```

### Workflow 7: Log Rotation

```bash
# Install log rotation module
bash scripts/setup-logrotate.sh

# Logs auto-rotate daily, keep 30 days, max 10MB per file
```

## Configuration

### Ecosystem File Format

```javascript
// ecosystem.config.js
module.exports = {
  apps: [
    {
      name: "api-server",
      script: "node",
      args: "server.js",
      cwd: "/home/user/api",
      instances: 2,
      exec_mode: "cluster",
      max_memory_restart: "500M",
      env: {
        NODE_ENV: "production",
        PORT: 3000
      },
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      error_file: "/var/log/pm2/api-error.log",
      out_file: "/var/log/pm2/api-out.log",
      merge_logs: true,
      autorestart: true,
      watch: false,
      max_restarts: 10,
      restart_delay: 5000
    },
    {
      name: "background-worker",
      script: "python3",
      args: "worker.py",
      cwd: "/home/user/workers",
      autorestart: true,
      max_restarts: 5,
      restart_delay: 10000
    },
    {
      name: "cron-runner",
      script: "bash",
      args: "cron.sh",
      cwd: "/home/user/scripts",
      cron_restart: "0 */6 * * *",
      autorestart: false
    }
  ]
};
```

### Environment Variables

```bash
# PM2 home directory (default: ~/.pm2)
export PM2_HOME="/var/lib/pm2"

# Log directory
export PM2_LOG_DIR="/var/log/pm2"
```

## Advanced Usage

### Watch Mode (Auto-Restart on File Change)

```bash
bash scripts/run.sh start --name "dev-server" --cmd "node app.js" --cwd /app --watch
```

### Cron-Based Restart

```bash
# Restart every 6 hours
bash scripts/run.sh start --name "cache-warmer" --cmd "node warm.js" --cron "0 */6 * * *"
```

### Deploy with PM2

```bash
# Setup deployment (pulls from git, installs deps, restarts)
pm2 deploy ecosystem.config.js production setup
pm2 deploy ecosystem.config.js production
```

### Health Check Endpoint

```bash
# Add to ecosystem — PM2 pings this URL, restarts if unhealthy
# In ecosystem.config.js:
# health_check: { url: "http://localhost:3000/health", interval: 30000 }
```

## Troubleshooting

### Issue: "pm2: command not found"

```bash
# Reinstall
npm install -g pm2
# Or use npx
npx pm2 status
```

### Issue: Processes don't survive reboot

```bash
# Run both commands:
pm2 save          # Save current process list
pm2 startup       # Generate startup script
# Then run the command PM2 outputs (may need sudo)
```

### Issue: Process keeps restarting (crash loop)

```bash
# Check logs
pm2 logs <name> --lines 200

# Check restart count
pm2 describe <name> | grep restarts

# Set max restarts to prevent infinite loop
# In ecosystem: max_restarts: 10, min_uptime: 5000
```

### Issue: High memory usage

```bash
# Set max memory restart
pm2 start app.js --max-memory-restart 300M

# Check current memory
pm2 monit
```

### Issue: Logs growing too large

```bash
# Install log rotation
bash scripts/setup-logrotate.sh

# Or manually flush
pm2 flush
```

## Dependencies

- `node` (14+) and `npm`
- `pm2` (installed by install.sh)
- Optional: `pm2-logrotate` (installed by setup-logrotate.sh)
