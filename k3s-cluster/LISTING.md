# Listing Copy: K3s Cluster Manager

## Metadata
- **Type:** Skill
- **Name:** k3s-cluster
- **Display Name:** K3s Cluster Manager
- **Categories:** [dev-tools, automation]
- **Price:** $15
- **Dependencies:** [bash, curl]
- **Icon:** ☸️

## Tagline

Lightweight Kubernetes in one command — deploy, scale, and monitor apps with K3s

## Description

Running Kubernetes shouldn't require a PhD in YAML. K3s Cluster Manager wraps the entire K3s lifecycle into simple, executable commands your OpenClaw agent can run directly.

Install a production-ready Kubernetes cluster with a single command. Deploy containers, scale replicas, manage Helm charts, handle secrets, monitor health, and backup your cluster — all through a unified CLI that your agent understands natively.

**What it does:**
- ☸️ Install K3s server or join workers with one command
- 🚀 Deploy apps from images, YAML manifests, or Helm charts
- 📈 Scale deployments and perform rolling updates with rollback
- 🔍 Monitor cluster health with Telegram alerts on failures
- 💾 Backup and restore cluster state and etcd snapshots
- 🔐 Manage secrets, configmaps, and private registries
- 🏥 Diagnose node issues with comprehensive health checks
- ⬆️ Upgrade K3s with zero-downtime rolling restarts

**Who it's for:** Developers, indie hackers, and homelab enthusiasts who want Kubernetes power without the complexity. Perfect for edge deployments, CI/CD environments, and self-hosted infrastructure.

## Quick Start Preview

```bash
# Install K3s (takes ~30 seconds)
bash scripts/k3s-manager.sh install

# Deploy an app
bash scripts/k3s-manager.sh deploy --name my-api --image node:20-alpine --replicas 3 --port 3000

# Monitor cluster health
bash scripts/k3s-manager.sh status
# 🟢 K3s Server: running (v1.31.4+k3s1)
# 📊 Nodes: 1 (1 ready)
# 🏃 Pods: 5/5 running
```

## Core Capabilities

1. One-command install — K3s server + Helm in ~30 seconds
2. Multi-node clusters — Add workers with join command + token
3. App deployment — From Docker images, YAML, or Helm charts
4. Rolling updates — Zero-downtime deploys with instant rollback
5. Health monitoring — Cron-ready checks with Telegram/webhook alerts
6. Cluster backup — Export manifests + etcd snapshots
7. Secret management — Create/update Kubernetes secrets securely
8. Helm integration — Install any chart from any repository
9. Resource monitoring — CPU/memory usage per node and pod
10. Node diagnostics — Deep-dive into failing nodes with one command

## Dependencies
- `bash` (4.0+)
- `curl`
- Root/sudo access
- Optional: `helm` (auto-installed)

## Installation Time
**2 minutes** — Run install command, start deploying

## Pricing Justification

**Why $15:**
- K3s management tools like Rancher Desktop are free but complex
- Managed Kubernetes: $72+/month (EKS, GKE, AKS)
- This: One-time $15, runs on any Linux box, agent-native automation
- Complexity tier: High (cluster management, multi-node, Helm, monitoring)
