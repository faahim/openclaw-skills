# PocketBase Manager — Example Usage

## Example 1: Deploy a SaaS Backend

```bash
# Full deployment with domain and backups
bash scripts/deploy.sh \
  --name my-saas \
  --port 8090 \
  --domain api.mysaas.com \
  --with-caddy \
  --backup-dest /backups/pocketbase
```

## Example 2: Multi-Environment Setup

```bash
# Production
bash scripts/manage.sh init --name prod --port 8090
bash scripts/manage.sh service --name prod --enable

# Staging
bash scripts/manage.sh init --name staging --port 8091
bash scripts/manage.sh service --name staging --enable

# Sync schema from staging to prod
bash scripts/api.sh collections export --url http://localhost:8091 --output schema.json
bash scripts/api.sh collections import --url http://localhost:8090 --input schema.json
```

## Example 3: OpenClaw Cron Integration

Set up health checks and backups via OpenClaw cron:

```bash
# Health check every 5 minutes
bash scripts/health.sh --all

# Daily backup at 2am
bash scripts/backup.sh --name prod --dest /backups --s3 s3://mybucket/pb-backups
```
