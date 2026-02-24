# Listing Copy: Traefik Reverse Proxy Manager

## Metadata
- **Type:** Skill
- **Name:** traefik-manager
- **Display Name:** Traefik Reverse Proxy Manager
- **Categories:** [dev-tools, automation]
- **Icon:** 🔀
- **Dependencies:** [docker, docker-compose, bash, curl]

## Tagline

Deploy Traefik reverse proxy with Docker auto-discovery and automatic SSL certificates

## Description

Setting up a reverse proxy with Docker is tedious — writing Nginx configs, managing SSL certs, restarting services every time you add a container. Traefik solves this but has a steep learning curve with YAML configs, entrypoints, routers, and middleware.

Traefik Manager handles the entire setup: generates production-ready Traefik configuration, enables automatic Let's Encrypt SSL, and configures Docker container auto-discovery. Add labels to any Docker container and Traefik instantly routes traffic to it — no config editing, no restarts.

**What it does:**
- 🐳 Docker auto-discovery — label containers, Traefik finds them
- 🔐 Automatic SSL via Let's Encrypt (HTTP or DNS challenge)
- 📊 Dashboard for monitoring routes, services, and certs
- 🛡️ Built-in middleware: auth, rate limiting, security headers
- ⚡ Zero-downtime config reloads
- 🔄 Load balancing across container replicas
- 📁 File provider for non-Docker services
- 🔍 Status checks, cert monitoring, log filtering

Perfect for developers and self-hosters running Docker who need reliable reverse proxying without the Nginx config sprawl.

## Core Capabilities

1. One-command Traefik deployment — generates traefik.yml + docker-compose.yml
2. Auto-SSL certificates — Let's Encrypt with HTTP or DNS challenge (Cloudflare, Route53, DigitalOcean)
3. Docker auto-discovery — containers get routes via labels, no config files
4. File provider — route non-Docker services via YAML
5. Middleware management — basic auth, rate limiting, security headers, redirects
6. Wildcard certificates — DNS challenge for *.example.com
7. Dashboard with auth — monitor all routes and services
8. Certificate monitoring — check expiry dates, get warnings
9. Log filtering — view access logs, filter errors
10. TCP/UDP routing — databases, game servers, any protocol
11. Load balancing — automatic across container replicas
12. HTTP→HTTPS redirect — enabled by default
