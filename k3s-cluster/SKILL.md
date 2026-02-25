---
name: k3s-cluster
description: >-
  Install, configure, and manage a K3s lightweight Kubernetes cluster. Deploy apps, manage services, monitor health, and scale workloads.
categories: [dev-tools, automation]
dependencies: [bash, curl, kubectl, k3s]
---

# K3s Cluster Manager

## What This Does

Automates K3s (lightweight Kubernetes) installation, app deployment, service management, and cluster health monitoring. Handles the entire lifecycle: install → configure → deploy → monitor → upgrade.

**Example:** "Install K3s on this server, deploy a web app with 3 replicas, set up automatic TLS, and monitor cluster health every 5 minutes."

## Quick Start (5 minutes)

### 1. Install K3s

```bash
# Install K3s server (single-node cluster)
bash scripts/k3s-manager.sh install

# Verify installation
bash scripts/k3s-manager.sh status
```

### 2. Deploy Your First App

```bash
# Deploy nginx with 2 replicas
bash scripts/k3s-manager.sh deploy --name my-app --image nginx:latest --replicas 2 --port 80

# Check deployment
bash scripts/k3s-manager.sh list
```

### 3. Expose a Service

```bash
# Expose via NodePort
bash scripts/k3s-manager.sh expose --name my-app --type NodePort --port 80 --target-port 80

# Expose via LoadBalancer (Traefik included in K3s)
bash scripts/k3s-manager.sh expose --name my-app --type LoadBalancer --port 80
```

## Core Workflows

### Workflow 1: Install K3s Cluster

**Single-node (server + agent):**
```bash
bash scripts/k3s-manager.sh install
```

**Multi-node — add worker:**
```bash
# On the worker node, pass server URL and token
bash scripts/k3s-manager.sh join \
  --server https://SERVER_IP:6443 \
  --token "$(cat /var/lib/rancher/k3s/server/node-token)"
```

**With custom options:**
```bash
bash scripts/k3s-manager.sh install \
  --disable traefik \
  --tls-san my-cluster.example.com \
  --data-dir /mnt/data/k3s
```

### Workflow 2: Deploy Applications

**From image:**
```bash
bash scripts/k3s-manager.sh deploy \
  --name api-server \
  --image myregistry/api:v1.2 \
  --replicas 3 \
  --port 8080 \
  --env "DATABASE_URL=postgres://..." \
  --env "NODE_ENV=production"
```

**From YAML manifest:**
```bash
bash scripts/k3s-manager.sh apply --file deployment.yaml
```

**From Helm chart:**
```bash
bash scripts/k3s-manager.sh helm-install \
  --name monitoring \
  --repo https://prometheus-community.github.io/helm-charts \
  --chart kube-prometheus-stack \
  --namespace monitoring
```

### Workflow 3: Monitor Cluster Health

**Quick status:**
```bash
bash scripts/k3s-manager.sh status
# Output:
# 🟢 K3s Server: running (v1.31.4+k3s1)
# 📊 Nodes: 3 (3 ready)
# 🏃 Pods: 12/12 running
# 💾 CPU: 23% | Memory: 41% | Disk: 55%
# ⏰ Uptime: 14d 3h 22m
```

**Continuous monitoring:**
```bash
bash scripts/k3s-manager.sh monitor --interval 300 --alert telegram
```

**Resource usage per namespace:**
```bash
bash scripts/k3s-manager.sh resources --namespace default
```

### Workflow 4: Scale & Update

**Scale deployment:**
```bash
bash scripts/k3s-manager.sh scale --name api-server --replicas 5
```

**Rolling update:**
```bash
bash scripts/k3s-manager.sh update --name api-server --image myregistry/api:v1.3
```

**Rollback:**
```bash
bash scripts/k3s-manager.sh rollback --name api-server
```

### Workflow 5: Backup & Restore

**Backup etcd (for HA setups):**
```bash
bash scripts/k3s-manager.sh backup --output /backups/k3s-$(date +%Y%m%d).tar.gz
```

**Restore:**
```bash
bash scripts/k3s-manager.sh restore --file /backups/k3s-20260225.tar.gz
```

### Workflow 6: Manage Secrets & ConfigMaps

```bash
# Create secret
bash scripts/k3s-manager.sh secret-create \
  --name db-creds \
  --literal "username=admin" \
  --literal "password=s3cur3"

# Create configmap from file
bash scripts/k3s-manager.sh configmap-create \
  --name app-config \
  --from-file config.yaml
```

## Configuration

### Environment Variables

```bash
# K3s install options
export K3S_TOKEN="your-cluster-token"
export K3S_URL="https://server:6443"          # For worker nodes
export INSTALL_K3S_VERSION="v1.31.4+k3s1"    # Pin version

# Monitoring alerts
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Custom kubeconfig
export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
```

### K3s Server Config

```yaml
# /etc/rancher/k3s/config.yaml
write-kubeconfig-mode: "0644"
tls-san:
  - "my-cluster.example.com"
  - "10.0.0.1"
disable:
  - servicelb       # Use MetalLB instead
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
```

## Advanced Usage

### Install with MetalLB Load Balancer

```bash
bash scripts/k3s-manager.sh install --disable servicelb
bash scripts/k3s-manager.sh helm-install \
  --name metallb \
  --repo https://metallb.github.io/metallb \
  --chart metallb \
  --namespace metallb-system
```

### Set Up Ingress with Let's Encrypt

```bash
# Install cert-manager
bash scripts/k3s-manager.sh helm-install \
  --name cert-manager \
  --repo https://charts.jetstack.io \
  --chart cert-manager \
  --namespace cert-manager \
  --set installCRDs=true

# Apply ClusterIssuer for Let's Encrypt
bash scripts/k3s-manager.sh apply --file examples/letsencrypt-issuer.yaml
```

### Run as Cron Health Check

```bash
# Check cluster health every 5 minutes
*/5 * * * * bash /path/to/scripts/k3s-manager.sh health-check --alert telegram >> /var/log/k3s-health.log 2>&1
```

### Uninstall K3s

```bash
# Server
bash scripts/k3s-manager.sh uninstall

# Agent/worker
bash scripts/k3s-manager.sh uninstall --agent
```

## Troubleshooting

### Issue: "k3s: command not found"

**Fix:**
```bash
# Reinstall
curl -sfL https://get.k3s.io | sh -
# Or use the manager
bash scripts/k3s-manager.sh install
```

### Issue: Node shows NotReady

**Check:**
```bash
bash scripts/k3s-manager.sh diagnose --node worker-1
# Checks: kubelet status, disk pressure, memory pressure, network
```

### Issue: Pod stuck in CrashLoopBackOff

**Debug:**
```bash
bash scripts/k3s-manager.sh logs --name my-app --tail 50
bash scripts/k3s-manager.sh describe --name my-app
```

### Issue: Cannot pull private images

**Fix:**
```bash
bash scripts/k3s-manager.sh registry-login \
  --server registry.example.com \
  --username user \
  --password pass \
  --namespace default
```

## Examples

See `examples/` for:
- `simple-web-app.yaml` — Basic web deployment with service
- `letsencrypt-issuer.yaml` — Automatic TLS certificates
- `monitoring-stack.yaml` — Prometheus + Grafana setup
- `postgres-stateful.yaml` — StatefulSet database deployment

## Key Principles

1. **K3s over K8s** — Half the memory, same API compatibility
2. **Batteries included** — Traefik ingress, CoreDNS, local storage out of the box
3. **Single binary** — Everything in one ~70MB binary
4. **Production-ready** — CNCF certified, used by edge/IoT deployments worldwide
5. **Easy HA** — Embedded etcd for multi-server setups

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `kubectl` (bundled with K3s)
- `helm` (optional, for chart deployments)
- Root/sudo access (K3s requires it)
