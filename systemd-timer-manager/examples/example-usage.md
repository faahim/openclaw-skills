# Example usage

```bash
# Every 30 minutes health ping
bash scripts/create_timer.sh \
  --name heartbeat-ping \
  --command 'curl -fsS https://example.com/health >/dev/null' \
  --on-calendar '*/30 * * * *'

# Check
bash scripts/list_timers.sh heartbeat-ping

# Remove
bash scripts/remove_timer.sh heartbeat-ping
```
