#!/bin/bash
# Create a new Dagu DAG from template
# Usage: bash create-dag.sh <name> [--template <type>]

set -euo pipefail

DAGS_DIR="${DAGS_DIR:-$HOME/.config/dagu/dags}"
DAG_NAME="${1:?Usage: create-dag.sh <name> [--template backup|deploy|etl|monitor|cron]}"
TEMPLATE="basic"

shift
while [[ $# -gt 0 ]]; do
  case $1 in
    --template) TEMPLATE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

DAG_FILE="$DAGS_DIR/$DAG_NAME.yaml"

if [ -f "$DAG_FILE" ]; then
  echo "⚠️  DAG already exists: $DAG_FILE"
  read -p "   Overwrite? (y/N) " -n 1 -r
  echo
  [[ ! "$REPLY" =~ ^[Yy]$ ]] && exit 0
fi

mkdir -p "$DAGS_DIR"

case "$TEMPLATE" in
  basic)
    cat > "$DAG_FILE" << 'YAML'
# DAG: Basic Pipeline
# Edit this file, then run: dagu start this-file.yaml

steps:
  - name: step-1
    command: echo "Step 1: Starting..."

  - name: step-2
    command: echo "Step 2: Processing..."
    depends:
      - step-1

  - name: step-3
    command: echo "Step 3: Done!"
    depends:
      - step-2
YAML
    ;;
    
  backup)
    cat > "$DAG_FILE" << 'YAML'
# DAG: Backup Pipeline
# Schedule: Daily at 2 AM
schedule: "0 2 * * *"

params:
  - DB_NAME: mydb
  - BACKUP_DIR: /tmp/backups
  - S3_BUCKET: my-backups

steps:
  - name: create-backup-dir
    command: mkdir -p $BACKUP_DIR/$(date +%Y-%m-%d)

  - name: dump-database
    command: pg_dump $DB_NAME > $BACKUP_DIR/$(date +%Y-%m-%d)/$DB_NAME.sql
    depends:
      - create-backup-dir

  - name: compress
    command: gzip -9 $BACKUP_DIR/$(date +%Y-%m-%d)/$DB_NAME.sql
    depends:
      - dump-database

  - name: upload
    command: |
      aws s3 cp $BACKUP_DIR/$(date +%Y-%m-%d)/$DB_NAME.sql.gz \
        s3://$S3_BUCKET/$(date +%Y-%m-%d)/ \
        --storage-class STANDARD_IA
    depends:
      - compress

  - name: cleanup-old
    command: find $BACKUP_DIR -mtime +7 -delete
    depends:
      - upload

  - name: notify-success
    command: echo "✅ Backup completed at $(date)"
    depends:
      - upload
YAML
    ;;

  deploy)
    cat > "$DAG_FILE" << 'YAML'
# DAG: Deployment Pipeline
params:
  - REPO_DIR: /home/user/myapp
  - BRANCH: main

steps:
  - name: pull
    command: cd $REPO_DIR && git pull origin $BRANCH

  - name: install
    command: cd $REPO_DIR && npm ci
    depends:
      - pull

  - name: test
    command: cd $REPO_DIR && npm test
    depends:
      - install

  - name: build
    command: cd $REPO_DIR && npm run build
    depends:
      - test

  - name: deploy
    command: cd $REPO_DIR && npm run deploy
    depends:
      - build
    retryPolicy:
      limit: 3
      intervalSec: 30

  - name: health-check
    command: |
      for i in $(seq 1 10); do
        curl -sf https://myapp.example.com/health && echo "✅ Healthy" && exit 0
        sleep 5
      done
      echo "❌ Health check failed" && exit 1
    depends:
      - deploy

  - name: notify
    command: echo "🚀 Deployed $BRANCH at $(date)"
    depends:
      - health-check
YAML
    ;;

  etl)
    cat > "$DAG_FILE" << 'YAML'
# DAG: ETL Pipeline (Extract-Transform-Load)
schedule: "*/30 * * * *"

params:
  - API_URL: https://api.example.com/data
  - OUTPUT_DIR: /tmp/etl

steps:
  - name: setup
    command: mkdir -p $OUTPUT_DIR

  - name: extract
    command: curl -sS "$API_URL" > $OUTPUT_DIR/raw.json
    depends:
      - setup

  - name: validate
    command: jq '.' $OUTPUT_DIR/raw.json > /dev/null
    depends:
      - extract

  - name: transform
    command: |
      jq '[.[] | {id, name, value: (.amount * 100 | round / 100), ts: now}]' \
        $OUTPUT_DIR/raw.json > $OUTPUT_DIR/transformed.json
    depends:
      - validate

  - name: load
    command: echo "Loading $(jq length $OUTPUT_DIR/transformed.json) records..."
    depends:
      - transform

  - name: log
    command: echo "$(date +%Y-%m-%dT%H:%M:%S) | ETL complete | $(jq length $OUTPUT_DIR/transformed.json) records" >> $OUTPUT_DIR/etl.log
    depends:
      - load
YAML
    ;;

  monitor)
    cat > "$DAG_FILE" << 'YAML'
# DAG: Health Monitor
schedule: "*/5 * * * *"

steps:
  - name: check-web
    command: curl -sf --max-time 10 https://example.com > /dev/null && echo "✅ Web OK" || echo "❌ Web DOWN"

  - name: check-api
    command: curl -sf --max-time 10 https://api.example.com/health > /dev/null && echo "✅ API OK" || echo "❌ API DOWN"

  - name: check-disk
    command: |
      USAGE=$(df / --output=pcent 2>/dev/null | tail -1 | tr -d ' %')
      if [ "$USAGE" -gt 90 ]; then
        echo "⚠️ Disk usage: ${USAGE}%"
        exit 1
      fi
      echo "✅ Disk OK: ${USAGE}%"

  - name: report
    command: echo "📊 Health check completed at $(date)"
    depends:
      - check-web
      - check-api
      - check-disk
    continueOn:
      failure: true
YAML
    ;;

  cron)
    cat > "$DAG_FILE" << 'YAML'
# DAG: Scheduled Task
# Runs every hour
schedule: "0 * * * *"

steps:
  - name: task
    command: echo "Running scheduled task at $(date)"
YAML
    ;;

  *)
    echo "❌ Unknown template: $TEMPLATE"
    echo "   Available: basic, backup, deploy, etl, monitor, cron"
    exit 1
    ;;
esac

echo "✅ Created DAG: $DAG_FILE"
echo "   Template: $TEMPLATE"
echo ""
echo "   Edit:  nano $DAG_FILE"
echo "   Run:   dagu start $DAG_FILE"
echo "   Test:  dagu dry-run $DAG_FILE"
