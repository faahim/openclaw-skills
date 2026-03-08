# Listing Copy: Podman Container Manager

## Metadata
- **Type:** Skill
- **Name:** podman-manager
- **Display Name:** Podman Container Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [bash, curl, podman]
- **Icon:** 🐙

## Tagline

Rootless container management — Run Docker images without Docker, with systemd integration and auto-updates

## Description

Running containers shouldn't require root access or a background daemon eating your resources. Podman is the rootless, daemonless alternative to Docker — and this skill makes your OpenClaw agent a container management expert.

**Podman Manager** installs Podman on any Linux distro or macOS, runs containers with a single command, generates systemd service files for auto-restart on boot, and configures automatic image updates. It's fully Docker-compatible — same images, same CLI patterns, no migration headaches.

**What it does:**
- 🐙 Install Podman (auto-detects Debian/Ubuntu/Fedora/Arch/macOS)
- 🚀 Run containers with ports, volumes, env vars, and health checks
- ⚙️ Generate systemd services — containers survive reboots
- 🔄 Auto-update containers on a weekly schedule
- 📦 Create pods for multi-container stacks (shared networking)
- 💾 Backup/restore containers and volumes
- 🧹 Prune unused images, containers, and volumes
- 🔒 Rootless by default — no sudo needed for daily operations

Perfect for developers, sysadmins, and homelabbers who want container management without Docker Desktop's overhead or licensing concerns.

## Quick Start Preview

```bash
# Install Podman
bash scripts/install.sh

# Run a container
bash scripts/run.sh run --name web --image nginx:alpine --port 8080:80

# Make it a persistent systemd service
bash scripts/run.sh generate-service --name web
```

## Core Capabilities

1. **Auto-install** — Detects OS, installs Podman + dependencies in one command
2. **Container lifecycle** — Run, stop, remove, exec, logs — all via scripts
3. **Systemd integration** — Generate service files, enable on boot, auto-restart on failure
4. **Auto-updates** — Label containers, schedule weekly image pulls + restarts
5. **Pod management** — Group containers with shared networking (like docker-compose)
6. **Rootless** — No daemon, no root — secure by default
7. **Docker-compatible** — Same images, same registries, drop-in replacement
8. **Backup & restore** — Export containers and volumes as tarballs
9. **Health checks** — Monitor container health with custom commands
10. **Resource limits** — Set memory and CPU caps per container

## Dependencies
- `bash` (4.0+)
- `curl` (for installation)
- `podman` (installed by skill)
- `systemd` (for service generation, optional on macOS)
