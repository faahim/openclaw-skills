---
name: dagu-workflow-engine
description: >-
  Install and manage Dagu — a powerful DAG-based workflow engine with web UI for scheduling, monitoring, and orchestrating complex task pipelines.
categories: [automation, dev-tools]
dependencies: [bash, curl]
---

# Dagu Workflow Engine Manager

## What This Does

Dagu is a modern, lightweight workflow engine that runs DAGs (Directed Acyclic Graphs) — complex multi-step pipelines defined in simple YAML. Think Airflow, but without the Python overhead. This skill installs Dagu, configures workflows, sets up scheduling, and manages the web dashboard.

**Example:** "Run a backup pipeline every night: dump database → compress → upload to S3 → send Slack notification — with retry logic and dependency chains."

## Quick Start (5 minutes)

### 1. Install Dagu

```bash
bash scripts/install.sh
```

This installs the Dagu binary, creates config directories, and sets up a systemd service.

### 2. Start the Dashboard

```bash
bash scripts/manage.sh start

# Dashboard available at http://localhost:8080
# Default: no auth (see Configuration to enable)
```

### 3. Create Your First Workflow

```bash
bash scripts/create-dag.sh my-first-pipeline

# Edit the generated DAG file:
cat ~/.config/dagu/dags/my-first-pipeline.yaml
```

### 4. Run It

```bash
# Run from CLI
dagu start ~/.config/dagu/dags/my-first-pipeline.yaml

# Or trigger from dashboard at http://localhost:8080
```

## Core Workflows

### Workflow 1: Backup Pipeline

**Use case:** Automated database backup with compression and cloud upload

```bash
bash scripts/create-dag.sh backup-pipeline --template backup
```

Generated DAG (`~/.config/dagu/dags/backup-pipeline.yaml`):

```yaml
schedule: "0 2 * * *"  # Run at 2 AM daily
params:
  - DB_NAME: mydb
  - S3_BUCKET: my-backups

steps:
  - name: dump-database
    command: pg_dump $DB_NAME > /tmp/backup-$DB_NAME.sql
    
  - name: compress
    command: gzip -9 /tmp/backup-$DB_NAME.sql
    depends:
      - dump-database

  - name: upload-s3
    command: aws s3 cp /tmp/backup-$DB_NAME.sql.gz s3://$S3_BUCKET/$(date +%Y-%m-%d)/
    depends:
      - compress

  - name: notify
    command: |
      curl -s -X POST "$SLACK_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d '{"text":"✅ Backup completed: '$DB_NAME' uploaded to S3"}'
    depends:
      - upload-s3

  - name: cleanup
    command: rm -f /tmp/backup-$DB_NAME.sql.gz
    depends:
      - upload-s3
```

### Workflow 2: Deployment Pipeline

**Use case:** Build, test, and deploy an application

```bash
bash scripts/create-dag.sh deploy-pipeline --template deploy
```

```yaml
params:
  - REPO_DIR: /home/user/myapp
  - BRANCH: main

steps:
  - name: pull-latest
    command: cd $REPO_DIR && git pull origin $BRANCH
    
  - name: install-deps
    command: cd $REPO_DIR && npm ci
    depends:
      - pull-latest

  - name: run-tests
    command: cd $REPO_DIR && npm test
    depends:
      - install-deps

  - name: build
    command: cd $REPO_DIR && npm run build
    depends:
      - run-tests

  - name: deploy
    command: cd $REPO_DIR && npm run deploy
    depends:
      - build
    retryPolicy:
      limit: 3
      intervalSec: 30

  - name: health-check
    command: |
      for i in {1..10}; do
        curl -sf https://myapp.example.com/health && exit 0
        sleep 5
      done
      exit 1
    depends:
      - deploy
```

### Workflow 3: Data Processing Pipeline

**Use case:** ETL pipeline — extract, transform, load

```bash
bash scripts/create-dag.sh etl-pipeline --template etl
```

```yaml
schedule: "*/30 * * * *"  # Every 30 minutes

steps:
  - name: extract-api
    command: curl -s https://api.example.com/data > /tmp/raw-data.json
    
  - name: extract-db
    command: psql -c "COPY (SELECT * FROM events WHERE ts > NOW() - interval '30 min') TO '/tmp/events.csv' CSV"

  - name: transform
    command: python3 scripts/transform.py /tmp/raw-data.json /tmp/events.csv > /tmp/processed.json
    depends:
      - extract-api
      - extract-db

  - name: load
    command: |
      curl -X POST https://warehouse.example.com/ingest \
        -H "Authorization: Bearer $WAREHOUSE_TOKEN" \
        -d @/tmp/processed.json
    depends:
      - transform

  - name: log-metrics
    command: echo "$(date +%Y-%m-%dT%H:%M:%S) | processed $(jq length /tmp/processed.json) records" >> /var/log/etl.log
    depends:
      - load
```

### Workflow 4: Monitoring & Alerting

**Use case:** Multi-service health check with cascading alerts

```bash
bash scripts/create-dag.sh health-monitor --template monitor
```

```yaml
schedule: "*/5 * * * *"  # Every 5 minutes

steps:
  - name: check-web
    command: curl -sf --max-time 10 https://mysite.com || exit 1

  - name: check-api
    command: curl -sf --max-time 10 https://api.mysite.com/health || exit 1

  - name: check-db
    command: pg_isready -h localhost -p 5432 || exit 1

  - name: alert-on-failure
    command: |
      curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=🚨 Service health check failed at $(date)"
    depends:
      - check-web
      - check-api
      - check-db
    continueOn:
      failure: true
```

## Configuration

### Enable Authentication

```bash
bash scripts/configure.sh --auth --user admin --pass your-secure-password
```

This updates `~/.config/dagu/admin.yaml`:

```yaml
host: 0.0.0.0
port: 8080
isBasicAuth: true
basicAuthUsername: admin
basicAuthPassword: your-secure-password
```

### Change Port

```bash
bash scripts/configure.sh --port 9090
```

### Set DAGs Directory

```bash
bash scripts/configure.sh --dags-dir /path/to/your/dags
```

### Environment Variables

Set global env vars for all DAGs in `~/.config/dagu/admin.yaml`:

```yaml
env:
  - SLACK_WEBHOOK: https://hooks.slack.com/services/...
  - TELEGRAM_BOT_TOKEN: your-bot-token
  - TELEGRAM_CHAT_ID: your-chat-id
  - AWS_ACCESS_KEY_ID: ...
  - AWS_SECRET_ACCESS_KEY: ...
```

## Advanced Usage

### Retry Logic

```yaml
steps:
  - name: flaky-api-call
    command: curl -sf https://api.example.com/data
    retryPolicy:
      limit: 5
      intervalSec: 10
```

### Conditional Steps

```yaml
steps:
  - name: check-disk
    command: |
      USAGE=$(df / --output=pcent | tail -1 | tr -d ' %')
      echo $USAGE
      
  - name: cleanup-if-full
    command: bash scripts/disk-cleanup.sh
    depends:
      - check-disk
    preconditions:
      - condition: "$1"
        expected: "re:^[89][0-9]$|^100$"
```

### Parallel Execution

Steps without `depends` run in parallel:

```yaml
steps:
  - name: task-a
    command: echo "A" && sleep 5
  - name: task-b
    command: echo "B" && sleep 5
  - name: task-c
    command: echo "C" && sleep 5
  # All 3 run simultaneously (~5 sec total, not 15)
  
  - name: aggregate
    command: echo "All done"
    depends:
      - task-a
      - task-b
      - task-c
```

### Sub-DAGs (Compose Workflows)

```yaml
steps:
  - name: run-sub-workflow
    command: dagu start /path/to/sub-workflow.yaml
    depends:
      - setup
```

### Email Notifications

```yaml
mailOn:
  failure: true
  success: false

smtp:
  host: smtp.gmail.com
  port: 587
  username: you@gmail.com
  password: app-password
```

## Management Commands

```bash
# Start/stop dashboard service
bash scripts/manage.sh start
bash scripts/manage.sh stop
bash scripts/manage.sh restart
bash scripts/manage.sh status

# List all DAGs
bash scripts/manage.sh list

# Run a specific DAG
bash scripts/manage.sh run <dag-name>

# Check DAG status
bash scripts/manage.sh status <dag-name>

# View execution history
bash scripts/manage.sh history <dag-name>

# Dry run (validate without executing)
bash scripts/manage.sh dry-run <dag-name>

# Export all DAGs for backup
bash scripts/manage.sh export /path/to/backup/

# Import DAGs from backup
bash scripts/manage.sh import /path/to/backup/
```

## Troubleshooting

### Issue: "dagu: command not found"

**Fix:**
```bash
# Re-run install
bash scripts/install.sh

# Or manually add to PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Issue: Dashboard not accessible remotely

**Fix:** Update bind address:
```bash
bash scripts/configure.sh --host 0.0.0.0
```

### Issue: DAG stuck in "running" state

**Fix:**
```bash
# Force stop
dagu stop ~/.config/dagu/dags/<dag-name>.yaml

# Check for zombie processes
ps aux | grep dagu
```

### Issue: Scheduled DAGs not running

**Fix:**
```bash
# Ensure dagu server is running (not just the UI)
bash scripts/manage.sh status

# Check cron expression syntax
dagu dry-run ~/.config/dagu/dags/<dag-name>.yaml
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation and HTTP-based steps)
- `systemd` (optional, for service management)
- Dagu binary (auto-installed by `scripts/install.sh`)
