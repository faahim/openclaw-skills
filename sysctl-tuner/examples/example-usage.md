# Sysctl Tuner — Example Usage

## Web Server (Nginx/Apache handling 10k+ connections)

```bash
# Preview what changes
bash scripts/sysctl-tuner.sh --profile webserver --dry-run

# Apply + security hardening
sudo bash scripts/sysctl-tuner.sh --profile webserver --profile security --apply --persist
```

## PostgreSQL Database Server

```bash
sudo bash scripts/sysctl-tuner.sh --profile database --apply --persist
```

## Docker Host

```bash
sudo bash scripts/sysctl-tuner.sh --profile container --profile security --apply --persist
```

## Developer Workstation

```bash
sudo bash scripts/sysctl-tuner.sh --profile desktop --apply --persist
```

## Custom Config

```yaml
# my-server.yaml
parameters:
  net.core.somaxconn: 32768
  vm.swappiness: 5
  fs.file-max: 2097152
  net.ipv4.tcp_fin_timeout: 10
```

```bash
sudo bash scripts/sysctl-tuner.sh --config my-server.yaml --apply --persist
```

## Drift Detection (Cron)

```bash
# Add to crontab — alerts if settings drift
*/30 * * * * bash /path/to/scripts/sysctl-tuner.sh --profile webserver --audit --alert-drift || echo "DRIFT DETECTED" | mail -s "Sysctl Drift Alert" admin@example.com
```
