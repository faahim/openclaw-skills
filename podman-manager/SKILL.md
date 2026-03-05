---
name: podman-manager
description: >-
  Install, configure, and manage Podman containers — the daemonless Docker alternative with rootless support.
categories: [dev-tools, automation]
dependencies: [bash, curl, podman]
---

# Podman Manager

## What This Does

Manages Podman — a daemonless, rootless container engine that's a drop-in Docker replacement. Install Podman, run containers, build images, manage pods, set up systemd services, and migrate from Docker — all without a daemon running as root.

**Example:** "Install Podman, run a Postgres container rootless, generate a systemd service so it auto-starts on boot."

## Quick Start (5 minutes)

### 1. Install Podman

```bash
bash scripts/install.sh
```

### 2. Run Your First Container

```bash
bash scripts/run.sh nginx --name my-web --port 8080:80
```

### 3. Check Running Containers

```bash
bash scripts/run.sh list
```

## Core Workflows

### Workflow 1: Install Podman

**Use case:** Fresh installation on Ubuntu/Debian/Fedora/RHEL/Arch

```bash
bash scripts/install.sh

# Verify installation
podman --version
podman info --format '{{.Host.Security.Rootless}}'
```

**Output:**
```
podman version 5.x.x
true
```

### Workflow 2: Run Containers

**Use case:** Start containers (same syntax as Docker)

```bash
# Run detached container with port mapping
bash scripts/run.sh redis --name my-redis --port 6379:6379 --detach

# Run with volume mount
bash scripts/run.sh postgres:16 --name my-db \
  --port 5432:5432 \
  --env POSTGRES_PASSWORD=secret \
  --volume pgdata:/var/lib/postgresql/data

# Run interactive
bash scripts/run.sh ubuntu:24.04 --interactive
```

### Workflow 3: Manage Containers

```bash
# List all containers
bash scripts/run.sh list

# Stop a container
bash scripts/run.sh stop my-redis

# Remove a container
bash scripts/run.sh rm my-redis

# View logs
bash scripts/run.sh logs my-db --follow

# Execute command in running container
bash scripts/run.sh exec my-db psql -U postgres
```

**Output:**
```
CONTAINER ID  IMAGE                  STATUS         PORTS                   NAMES
a1b2c3d4e5f6  docker.io/library/pg   Up 2 minutes   0.0.0.0:5432->5432/tcp  my-db
f6e5d4c3b2a1  docker.io/library/red  Up 5 minutes   0.0.0.0:6379->6379/tcp  my-redis
```

### Workflow 4: Build Images

```bash
# Build from Dockerfile/Containerfile
bash scripts/run.sh build --tag myapp:latest --file Containerfile .

# Build multi-stage
bash scripts/run.sh build --tag myapp:prod --target production .

# List images
bash scripts/run.sh images
```

### Workflow 5: Pod Management

**Use case:** Group related containers (like docker-compose but native)

```bash
# Create a pod with port mappings
bash scripts/run.sh pod-create my-stack --port 8080:80 --port 5432:5432

# Add containers to pod
bash scripts/run.sh pod-add my-stack nginx
bash scripts/run.sh pod-add my-stack postgres:16 \
  --env POSTGRES_PASSWORD=secret

# List pods
bash scripts/run.sh pod-list

# Stop/start pod (all containers together)
bash scripts/run.sh pod-stop my-stack
bash scripts/run.sh pod-start my-stack
```

### Workflow 6: Generate Systemd Services

**Use case:** Auto-start containers on boot without a daemon

```bash
# Generate systemd unit for a container
bash scripts/run.sh systemd my-db

# Output: ~/.config/systemd/user/container-my-db.service
# Enable auto-start:
systemctl --user enable container-my-db.service
systemctl --user start container-my-db.service

# Generate for a pod (all containers)
bash scripts/run.sh systemd-pod my-stack
```

### Workflow 7: Docker Compose Compatibility

**Use case:** Run existing docker-compose.yml files with Podman

```bash
# Install podman-compose if needed
bash scripts/install-compose.sh

# Run compose file
podman-compose up -d

# Or use podman's built-in kube play
bash scripts/run.sh compose-up docker-compose.yml
```

### Workflow 8: Rootless Setup & Security

```bash
# Check rootless status
bash scripts/run.sh security-check

# Configure rootless networking (slirp4netns/pasta)
bash scripts/run.sh configure-rootless

# Set up subuid/subgid ranges
bash scripts/run.sh setup-userns
```

**Output:**
```
🔐 Podman Security Report
├── Rootless: ✅ Enabled
├── User namespace: ✅ /etc/subuid configured (65536 UIDs)
├── Network: ✅ pasta (recommended)
├── Seccomp: ✅ Default profile active
└── SELinux/AppArmor: ✅ Enforcing
```

### Workflow 9: Image Management

```bash
# Pull from multiple registries
bash scripts/run.sh pull docker.io/library/nginx
bash scripts/run.sh pull ghcr.io/owner/image:tag
bash scripts/run.sh pull quay.io/org/image

# Prune unused images
bash scripts/run.sh prune-images

# Export/import images
bash scripts/run.sh save myapp:latest -o myapp.tar
bash scripts/run.sh load -i myapp.tar
```

### Workflow 10: Migrate from Docker

```bash
# Check Docker compatibility
bash scripts/run.sh docker-compat-check

# Create alias (docker → podman)
bash scripts/run.sh setup-docker-alias

# Import Docker images
bash scripts/run.sh import-docker-images
```

## Configuration

### Registries Configuration

```bash
# Edit registries.conf
cat > ~/.config/containers/registries.conf << 'EOF'
unqualified-search-registries = ["docker.io", "ghcr.io", "quay.io"]

[[registry]]
location = "docker.io"

[[registry]]
location = "ghcr.io"

[[registry]]
location = "quay.io"
EOF
```

### Storage Configuration

```bash
# Set custom storage location (rootless)
cat > ~/.config/containers/storage.conf << 'EOF'
[storage]
driver = "overlay"
rootless_storage_path = "$HOME/.local/share/containers/storage"

[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
EOF
```

## Troubleshooting

### Issue: "WARN[0000] "/" is not a shared mount"

**Fix:**
```bash
sudo mount --make-rshared /
# Make permanent:
echo '/ / none rshared 0 0' | sudo tee -a /etc/fstab
```

### Issue: "permission denied" on rootless

**Fix:**
```bash
# Ensure subuid/subgid is configured
grep $(whoami) /etc/subuid || sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $(whoami)
podman system migrate
```

### Issue: Port < 1024 in rootless mode

**Fix:**
```bash
# Allow unprivileged port binding
sudo sysctl net.ipv4.ip_unprivileged_port_start=80
# Make permanent
echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee /etc/sysctl.d/podman-ports.conf
```

### Issue: Slow image pulls

**Fix:** Configure registry mirrors in `~/.config/containers/registries.conf`

## Key Principles

1. **Rootless by default** — No daemon, no root. Containers run as your user.
2. **Docker-compatible** — Same CLI syntax, same images, same Dockerfiles.
3. **Systemd-native** — Generate proper service units, no daemon needed.
4. **Pod support** — Group containers like Kubernetes pods.
5. **OCI-compliant** — Standard container images, no lock-in.

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `podman` (installed by skill)
- `fuse-overlayfs` (for rootless storage, auto-installed)
- Optional: `podman-compose` (for docker-compose compatibility)
- Optional: `buildah` (for advanced image building)
