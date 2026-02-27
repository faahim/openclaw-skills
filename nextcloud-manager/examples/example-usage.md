# Nextcloud Manager — Example Usage

## Example 1: Home Lab Setup

```bash
# Install for local network access
bash scripts/nextcloud-manager.sh install \
  --domain 192.168.1.50 \
  --port 8080 \
  --db postgres \
  --cache redis

# Create family accounts
bash scripts/nextcloud-manager.sh user create --username alice --quota 50G --groups family
bash scripts/nextcloud-manager.sh user create --username bob --quota 50G --groups family

# Install useful apps
bash scripts/nextcloud-manager.sh app install calendar contacts tasks notes photos

# Schedule nightly backups (keep 14 days)
bash scripts/nextcloud-manager.sh backup schedule --cron "0 3 * * *" --keep 14 --compress
```

## Example 2: Small Team / Startup

```bash
# Production install with domain + SSL
bash scripts/nextcloud-manager.sh install \
  --domain cloud.startup.io \
  --db postgres \
  --cache redis \
  --ssl letsencrypt

# Create team with groups
for user in alice bob carol dave; do
  bash scripts/nextcloud-manager.sh user create \
    --username "$user" \
    --email "${user}@startup.io" \
    --quota 100G \
    --groups "team,engineering"
done

# Install collaboration apps
bash scripts/nextcloud-manager.sh app install deck talk onlyoffice

# S3 backups
bash scripts/nextcloud-manager.sh backup schedule \
  --cron "0 2 * * *" \
  --output s3://startup-backups/nextcloud \
  --keep 30 \
  --compress

# Performance tune
bash scripts/nextcloud-manager.sh tune --upload-limit 16G
```

## Example 3: OpenClaw Cron Integration

Set up Nextcloud monitoring as an OpenClaw cron job:

```
Schedule: every 30 minutes
Task: "Run nextcloud health check. If issues found, alert via Telegram."
Command: bash /path/to/scripts/nextcloud-manager.sh health
```
