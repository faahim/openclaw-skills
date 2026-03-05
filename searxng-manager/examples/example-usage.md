# SearXNG Manager — Example Usage

## 1. Quick Deploy for Personal Use

```bash
# Install and run on port 8080
bash scripts/install.sh --method docker --port 8080

# Verify
bash scripts/manage.sh status

# Search
bash scripts/manage.sh search "best linux distro 2026"
```

## 2. Public Instance Behind Nginx

```bash
# Install
bash scripts/install.sh --method docker --port 8080 --base-url https://search.example.com

# Generate Nginx config
bash scripts/manage.sh proxy-config nginx --domain search.example.com

# Copy and enable
sudo cp /tmp/searxng-nginx.conf /etc/nginx/sites-available/searxng
sudo ln -s /etc/nginx/sites-available/searxng /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## 3. Use as API for Scripts

```bash
# Get JSON results
curl -s "http://localhost:8080/search?q=rust+programming&format=json" | jq '.results[:5]'

# In a script
RESULTS=$(bash scripts/manage.sh search --format json "docker best practices")
echo "$RESULTS" | jq '.results[0].url'
```

## 4. Customize Search Engines

```bash
# Enable science-focused engines
bash scripts/manage.sh engines enable arxiv pubmed semantic_scholar

# Disable general engines you don't need
bash scripts/manage.sh engines disable yahoo aol brave

# Restart to apply
bash scripts/manage.sh restart

# Test
bash scripts/manage.sh engines test
```

## 5. Set Up Auto-Updates

```bash
# Weekly updates (Sunday 3am)
bash scripts/manage.sh auto-update weekly

# Check update log
cat /tmp/searxng-update.log
```

## 6. OpenClaw Cron Integration

Use OpenClaw's cron to periodically check SearXNG health:

```
Schedule: every 30 minutes
Command: bash /path/to/scripts/manage.sh status
Alert: if status returns non-zero, send Telegram notification
```
