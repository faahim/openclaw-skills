# Listing Copy: Podman Manager

## Metadata
- **Type:** Skill
- **Name:** podman-manager
- **Display Name:** Podman Manager
- **Categories:** [dev-tools, automation]
- **Icon:** 🐙
- **Dependencies:** [bash, curl]

## Tagline

Manage rootless containers with Podman — the daemonless Docker alternative

## Description

Running containers shouldn't require a root daemon eating resources in the background. Podman gives you Docker-compatible container management without the daemon, running everything rootless by default.

Podman Manager handles the full lifecycle: install Podman on any Linux distro or macOS, run containers with Docker-identical syntax, group them into pods, and generate systemd services so they auto-start on boot — no daemon needed.

**What it does:**
- 🐙 Install Podman on Ubuntu/Debian/Fedora/RHEL/Arch/macOS
- 📦 Run containers with Docker-compatible CLI (same images, same Dockerfiles)
- 🔗 Create pods to group related containers (like docker-compose, but native)
- ⚙️ Generate systemd services for auto-start without a daemon
- 🔐 Configure rootless mode with user namespaces
- 🐳 Migrate from Docker (import images, set up aliases, socket compatibility)
- 🧹 Manage images, volumes, and storage with simple commands

Perfect for developers and sysadmins who want container management without the overhead of Docker's daemon, or anyone moving to rootless containers for better security.

## Quick Start Preview

```bash
# Install Podman
bash scripts/install.sh

# Run a container (same as Docker!)
bash scripts/run.sh nginx --name web --port 8080:80

# Auto-start on boot via systemd
bash scripts/run.sh systemd web
```

## Core Capabilities

1. One-command install — Detects distro, installs Podman + dependencies
2. Container management — Run, stop, remove, logs, exec (Docker-identical syntax)
3. Pod management — Group containers, shared networking, lifecycle control
4. Systemd integration — Generate service units, auto-start without daemon
5. Rootless by default — User namespace isolation, no root required
6. Docker migration — Import images, alias docker→podman, socket compatibility
7. Image management — Pull, build, save, load, prune across registries
8. Security auditing — Check rootless status, namespaces, seccomp, storage
9. Compose support — Run docker-compose.yml via podman-compose
10. Multi-registry — Docker Hub, GitHub Container Registry, Quay.io
