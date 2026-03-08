---
name: podman-manager
description: >-
  Install and manage Podman containers — rootless, daemonless Docker alternative with systemd integration and auto-updates.
categories: [dev-tools, automation]
dependencies: [bash, curl, podman]
---

# Podman Container Manager

## What This Does

Manage containers without Docker — Podman runs rootless (no daemon, no root), integrates natively with systemd, and supports auto-updates. This skill installs Podman, manages containers/pods/images, generates systemd unit files, and configures automatic container updates.

**Example:** "Run a Postgres container as a systemd service that auto-restarts and auto-updates its image weekly."

## Quick Start (5 minutes)

### 1. Install Podman

```bash
bash scripts/install.sh
```

This detects your OS (Debian/Ubuntu/Fedora/Arch/macOS) and installs Podman + dependencies.

### 2. Run Your First Container

```bash
bash scripts/run.sh run --name my-nginx --image docker.io/library/nginx:alpine --port 8080:80
```

### 3. Make It a Systemd Service

```bash
bash scripts/run.sh generate-service --name my-nginx
# Creates ~/.config/systemd/user/container-my-nginx.service
# Auto-starts on boot, auto-restarts on failure
```

## Core Workflows

### Workflow 1: Run a Container

```bash
bash scripts/run.sh run \
  --name postgres-db \
  --image docker.io/library/postgres:16 \
  --port 5432:5432 \
  --env POSTGRES_PASSWORD=mysecret \
  --env POSTGRES_DB=myapp \
  --volume pgdata:/var/lib/postgresql/data
```

**Output:**
```
✅ Container 'postgres-db' started
   Image: docker.io/library/postgres:16
   Ports: 5432 → 5432
   Volume: pgdata → /var/lib/postgresql/data
```

### Workflow 2: List & Manage Containers

```bash
# List running containers
bash scripts/run.sh list

# Stop a container
bash scripts/run.sh stop --name postgres-db

# Remove a container
bash scripts/run.sh rm --name postgres-db

# View logs
bash scripts/run.sh logs --name postgres-db --tail 50

# Execute command in container
bash scripts/run.sh exec --name postgres-db -- psql -U postgres -c "SELECT 1"
```

### Workflow 3: Generate Systemd Service

```bash
bash scripts/run.sh generate-service --name postgres-db

# Enable auto-start on login
systemctl --user enable container-postgres-db.service

# Start/stop via systemd
systemctl --user start container-postgres-db.service
systemctl --user stop container-postgres-db.service

# Enable lingering (keeps services running after logout)
loginctl enable-linger $USER
```

**Output:**
```
✅ Systemd service created: ~/.config/systemd/user/container-postgres-db.service
   Auto-restart: on-failure (max 3 retries)
   Start on boot: enabled
   Lingering: enabled
```

### Workflow 4: Auto-Update Containers

```bash
# Label a container for auto-update
bash scripts/run.sh run \
  --name my-app \
  --image docker.io/myuser/myapp:latest \
  --label io.containers.autoupdate=registry \
  --port 3000:3000

# Generate service + timer for auto-updates
bash scripts/run.sh setup-autoupdate

# Check what would update (dry run)
podman auto-update --dry-run

# Force update now
podman auto-update
```

### Workflow 5: Create a Pod (Multi-Container)

```bash
# Create a pod (shared network namespace)
bash scripts/run.sh create-pod --name my-stack --port 8080:80 --port 5432:5432

# Add containers to the pod
bash scripts/run.sh run --pod my-stack --name web --image docker.io/library/nginx:alpine
bash scripts/run.sh run --pod my-stack --name db --image docker.io/library/postgres:16 \
  --env POSTGRES_PASSWORD=secret

# Containers in the pod share localhost
# web can reach db at localhost:5432
```

### Workflow 6: Image Management

```bash
# Pull an image
bash scripts/run.sh pull --image docker.io/library/redis:7

# List images
bash scripts/run.sh images

# Prune unused images
bash scripts/run.sh prune --images

# Prune everything (stopped containers + unused images + volumes)
bash scripts/run.sh prune --all
```

### Workflow 7: Backup & Restore

```bash
# Export a container as tarball
bash scripts/run.sh backup --name postgres-db --output /backups/postgres-db.tar

# Import/restore
bash scripts/run.sh restore --name postgres-db --input /backups/postgres-db.tar

# Backup a volume
bash scripts/run.sh backup-volume --volume pgdata --output /backups/pgdata.tar.gz
```

## Configuration

### Environment Variables

```bash
# Custom registries (optional)
export PODMAN_REGISTRIES="docker.io,quay.io,ghcr.io"

# Default network mode
export PODMAN_NETWORK="bridge"

# Storage driver (default: overlay)
export PODMAN_STORAGE_DRIVER="overlay"
```

### Registry Configuration

```bash
# Login to a registry
podman login docker.io

# Login to GitHub Container Registry
podman login ghcr.io -u USERNAME --password-stdin <<< "$GITHUB_TOKEN"

# Use registries.conf for custom mirrors
cat > ~/.config/containers/registries.conf <<'EOF'
unqualified-search-registries = ["docker.io", "quay.io", "ghcr.io"]

[[registry]]
location = "docker.io"
EOF
```

## Advanced Usage

### Docker Compose Compatibility

```bash
# Podman supports docker-compose via podman-compose
pip install podman-compose

# Run docker-compose files with Podman
podman-compose -f docker-compose.yml up -d
podman-compose -f docker-compose.yml down
```

### Rootless Networking

```bash
# Podman rootless uses slirp4netns by default
# For better performance, use pasta (if available)
bash scripts/run.sh run \
  --name my-app \
  --image docker.io/myuser/myapp \
  --network pasta \
  --port 8080:8080
```

### Health Checks

```bash
bash scripts/run.sh run \
  --name my-api \
  --image docker.io/myuser/myapi \
  --port 3000:3000 \
  --healthcheck "curl -f http://localhost:3000/health || exit 1" \
  --healthcheck-interval 30s \
  --healthcheck-retries 3
```

### Resource Limits

```bash
bash scripts/run.sh run \
  --name my-app \
  --image docker.io/myuser/myapp \
  --memory 512m \
  --cpus 1.5
```

## Troubleshooting

### Issue: "permission denied" on rootless

**Fix:**
```bash
# Ensure user namespaces are enabled
sudo sysctl -w kernel.unprivileged_userns_clone=1
echo "kernel.unprivileged_userns_clone=1" | sudo tee /etc/sysctl.d/99-podman.conf

# Set up subuid/subgid
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
podman system migrate
```

### Issue: Port binding fails on rootless (< 1024)

**Fix:**
```bash
# Allow binding to low ports
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee -a /etc/sysctl.d/99-podman.conf
```

### Issue: Container can't resolve DNS

**Fix:**
```bash
# Check /etc/resolv.conf inside container
podman exec my-container cat /etc/resolv.conf

# Override DNS
bash scripts/run.sh run --name my-app --image myapp --dns 8.8.8.8 --dns 1.1.1.1
```

### Issue: Systemd service won't start after reboot

**Fix:**
```bash
# Enable lingering for your user
loginctl enable-linger $USER

# Verify
loginctl show-user $USER | grep Linger
```

## Migration from Docker

```bash
# Podman is CLI-compatible with Docker
# Most docker commands work by replacing 'docker' with 'podman'
alias docker=podman

# Import Docker images
podman pull docker.io/library/nginx:alpine
# or from a Docker save
docker save myimage:latest | podman load
```

## Key Principles

1. **Rootless by default** — No daemon, no root required
2. **Systemd-native** — Generate proper service files, not hacks
3. **Auto-update** — Label containers, Podman handles the rest
4. **OCI-compatible** — Same images as Docker, interchangeable
5. **Pod support** — Group containers with shared networking
