# vnstat-traffic Examples

## 1. VPS Bandwidth Monitoring

Monitor a VPS with a 1 TB monthly cap:

```bash
# Install
bash scripts/install.sh

# Set up 1 TB cap alert
bash scripts/traffic.sh alert --interface eth0 --monthly-limit 1024 --unit GiB --notify telegram

# Add hourly cron check
bash scripts/traffic.sh setup-cron

# View monthly usage
bash scripts/traffic.sh monthly
```

## 2. Multi-Interface Server

Track traffic across eth0 (public), docker0 (containers), and wg0 (VPN):

```bash
bash scripts/traffic.sh status eth0
bash scripts/traffic.sh status docker0
bash scripts/traffic.sh status wg0
bash scripts/traffic.sh top  # See ranking
```

## 3. Automated Daily Reports

Add to crontab for daily 8 AM reports:

```bash
0 8 * * * bash /path/to/scripts/traffic.sh daily >> /var/log/traffic-daily.log
```

## 4. JSON Pipeline

Export to JSON for dashboards:

```bash
bash scripts/traffic.sh export eth0 monthly | jq '.total_bytes'
```

## 5. OpenClaw Integration

Use with OpenClaw cron to get Telegram reports:

```
Schedule: every day at 8am
Command: bash scripts/traffic.sh daily eth0
```
