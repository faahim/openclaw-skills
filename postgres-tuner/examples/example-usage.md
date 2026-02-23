# PostgreSQL Tuner — Examples

## Example 1: Tune a 4GB Web Server

```bash
bash scripts/tune.sh --workload web --ram 4096 --cpus 2 --disk ssd
```

Output:
```
shared_buffers = 1GB
effective_cache_size = 3GB
work_mem = 5MB
maintenance_work_mem = 256MB
max_connections = 200
```

## Example 2: Tune a 32GB Analytics Server

```bash
bash scripts/tune.sh --workload dw --ram 32768 --cpus 16 --disk ssd
```

Output:
```
shared_buffers = 8GB
effective_cache_size = 24GB
work_mem = 838MB
maintenance_work_mem = 2GB
max_connections = 20
max_parallel_workers_per_gather = 4
```

## Example 3: Diff Against Current Config

```bash
bash scripts/tune.sh --workload oltp --diff
```

## Example 4: Apply with Auto-Backup

```bash
sudo bash scripts/tune.sh --workload web --apply
```

## Example 5: Docker/Container Override

```bash
bash scripts/tune.sh --workload web --ram 2048 --cpus 2 --output /docker/pg/postgresql.conf
```

## Example 6: Use with OpenClaw Cron

Schedule weekly re-tuning check:
```
Every Sunday at 3am: bash /path/to/scripts/tune.sh --workload web --diff
```
