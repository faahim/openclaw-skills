#!/bin/bash
# K3s Cluster Manager — Install, deploy, monitor, and manage K3s clusters
# Usage: bash k3s-manager.sh <command> [options]

set -euo pipefail

VERSION="1.0.0"
K3S_CONFIG="/etc/rancher/k3s/config.yaml"
KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
LOG_FILE="${LOG_FILE:-/var/log/k3s-manager.log}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}" >&2; }

usage() {
  cat <<EOF
K3s Cluster Manager v${VERSION}

USAGE: $(basename "$0") <command> [options]

COMMANDS:
  install           Install K3s server
  join              Join as worker node
  uninstall         Remove K3s from this node
  status            Show cluster status
  deploy            Deploy an application
  apply             Apply a YAML manifest
  list              List deployments
  scale             Scale a deployment
  update            Rolling update a deployment
  rollback          Rollback a deployment
  expose            Expose a service
  logs              View pod logs
  describe          Describe a resource
  delete            Delete a deployment
  resources         Show resource usage
  monitor           Continuous health monitoring
  health-check      One-shot health check (for cron)
  backup            Backup cluster data
  restore           Restore from backup
  helm-install      Install a Helm chart
  helm-uninstall    Remove a Helm release
  secret-create     Create a Kubernetes secret
  configmap-create  Create a ConfigMap
  registry-login    Add private registry credentials
  diagnose          Diagnose node issues
  upgrade           Upgrade K3s version
  
OPTIONS:
  --name            Resource name
  --image           Container image
  --replicas        Number of replicas (default: 1)
  --port            Container port
  --target-port     Service target port
  --type            Service type (ClusterIP|NodePort|LoadBalancer)
  --namespace       Kubernetes namespace (default: default)
  --env             Environment variable (KEY=VALUE, repeatable)
  --file            Path to YAML manifest
  --output          Output path (for backups)
  --server          K3s server URL (for join)
  --token           Cluster token (for join)
  --interval        Monitoring interval in seconds
  --alert           Alert channel (telegram)
  --tail            Number of log lines to show
  --disable         Disable K3s component (repeatable)
  --tls-san         Additional TLS SAN (repeatable)
  --data-dir        Custom data directory
  --repo            Helm chart repository URL
  --chart           Helm chart name
  --set             Helm values (KEY=VALUE, repeatable)
  --literal         Secret literal (KEY=VALUE, repeatable)
  --from-file       ConfigMap source file
  --agent           Uninstall agent (not server)
  --node            Target node name

EOF
  exit 0
}

# Parse arguments
COMMAND="${1:-help}"
shift 2>/dev/null || true

NAME="" IMAGE="" REPLICAS="1" PORT="" TARGET_PORT="" SVC_TYPE="ClusterIP"
NAMESPACE="default" FILE="" OUTPUT="" SERVER="" TOKEN="" INTERVAL="300"
ALERT="" TAIL="100" DISABLE=() TLS_SAN=() DATA_DIR="" REPO="" CHART=""
HELM_SET=() LITERALS=() FROM_FILE="" IS_AGENT=false NODE="" ENVS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --image) IMAGE="$2"; shift 2 ;;
    --replicas) REPLICAS="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --target-port) TARGET_PORT="$2"; shift 2 ;;
    --type) SVC_TYPE="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --env) ENVS+=("$2"); shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --server) SERVER="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --alert) ALERT="$2"; shift 2 ;;
    --tail) TAIL="$2"; shift 2 ;;
    --disable) DISABLE+=("$2"); shift 2 ;;
    --tls-san) TLS_SAN+=("$2"); shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --chart) CHART="$2"; shift 2 ;;
    --set) HELM_SET+=("$2"); shift 2 ;;
    --literal) LITERALS+=("$2"); shift 2 ;;
    --from-file) FROM_FILE="$2"; shift 2 ;;
    --agent) IS_AGENT=true; shift ;;
    --node) NODE="$2"; shift 2 ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This command requires root/sudo privileges"
    exit 1
  fi
}

ensure_k3s() {
  if ! command -v k3s &>/dev/null; then
    error "K3s is not installed. Run: $(basename "$0") install"
    exit 1
  fi
}

ensure_kubectl() {
  if ! command -v kubectl &>/dev/null && ! k3s kubectl version --client &>/dev/null 2>&1; then
    error "kubectl not available"
    exit 1
  fi
}

kctl() {
  if command -v kubectl &>/dev/null; then
    kubectl "$@"
  else
    k3s kubectl "$@"
  fi
}

send_alert() {
  local msg="$1"
  if [[ "$ALERT" == "telegram" ]]; then
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
      curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${msg}" \
        -d "parse_mode=Markdown" >/dev/null 2>&1
    else
      warn "Telegram credentials not set (TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID)"
    fi
  fi
}

cmd_install() {
  ensure_root
  log "Installing K3s..."
  
  local INSTALL_ARGS=""
  for d in "${DISABLE[@]}"; do
    INSTALL_ARGS+=" --disable $d"
  done
  for s in "${TLS_SAN[@]}"; do
    INSTALL_ARGS+=" --tls-san $s"
  done
  if [[ -n "$DATA_DIR" ]]; then
    INSTALL_ARGS+=" --data-dir $DATA_DIR"
  fi
  if [[ -n "${INSTALL_K3S_VERSION:-}" ]]; then
    export INSTALL_K3S_VERSION
  fi
  
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server $INSTALL_ARGS" sh -
  
  # Wait for node ready
  log "Waiting for node to be ready..."
  local retries=30
  while [[ $retries -gt 0 ]]; do
    if k3s kubectl get nodes 2>/dev/null | grep -q " Ready"; then
      break
    fi
    sleep 2
    retries=$((retries - 1))
  done
  
  # Install Helm if not present
  if ! command -v helm &>/dev/null; then
    log "Installing Helm..."
    curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi
  
  # Make kubeconfig accessible
  chmod 644 /etc/rancher/k3s/k3s.yaml 2>/dev/null || true
  
  success "K3s installed successfully!"
  echo ""
  k3s kubectl get nodes
  echo ""
  log "Node token: $(cat /var/lib/rancher/k3s/server/node-token)"
}

cmd_join() {
  ensure_root
  if [[ -z "$SERVER" || -z "$TOKEN" ]]; then
    error "Both --server and --token are required"
    exit 1
  fi
  
  log "Joining K3s cluster at $SERVER..."
  curl -sfL https://get.k3s.io | K3S_URL="$SERVER" K3S_TOKEN="$TOKEN" sh -
  success "Joined cluster as worker node!"
}

cmd_uninstall() {
  ensure_root
  if [[ "$IS_AGENT" == true ]]; then
    log "Uninstalling K3s agent..."
    /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || error "Agent uninstall script not found"
  else
    log "Uninstalling K3s server..."
    /usr/local/bin/k3s-uninstall.sh 2>/dev/null || error "Server uninstall script not found"
  fi
  success "K3s uninstalled"
}

cmd_status() {
  ensure_k3s
  
  local k3s_version
  k3s_version=$(k3s --version 2>/dev/null | head -1 | awk '{print $3}') || k3s_version="unknown"
  
  # Server status
  if systemctl is-active k3s &>/dev/null; then
    echo -e "🟢 K3s Server: ${GREEN}running${NC} ($k3s_version)"
  elif systemctl is-active k3s-agent &>/dev/null; then
    echo -e "🟢 K3s Agent: ${GREEN}running${NC} ($k3s_version)"
  else
    echo -e "🔴 K3s: ${RED}stopped${NC}"
    return 1
  fi
  
  # Nodes
  local total_nodes ready_nodes
  total_nodes=$(kctl get nodes --no-headers 2>/dev/null | wc -l)
  ready_nodes=$(kctl get nodes --no-headers 2>/dev/null | grep -c " Ready" || echo 0)
  echo "📊 Nodes: $total_nodes ($ready_nodes ready)"
  
  # Pods
  local total_pods running_pods
  total_pods=$(kctl get pods --all-namespaces --no-headers 2>/dev/null | wc -l)
  running_pods=$(kctl get pods --all-namespaces --no-headers 2>/dev/null | grep -c "Running" || echo 0)
  echo "🏃 Pods: $running_pods/$total_pods running"
  
  # Resource usage
  if kctl top nodes &>/dev/null 2>&1; then
    local cpu_pct mem_pct
    cpu_pct=$(kctl top nodes --no-headers 2>/dev/null | awk '{gsub(/%/,"",$3); sum+=$3; n++} END{if(n>0) printf "%.0f", sum/n; else print "N/A"}')
    mem_pct=$(kctl top nodes --no-headers 2>/dev/null | awk '{gsub(/%/,"",$5); sum+=$5; n++} END{if(n>0) printf "%.0f", sum/n; else print "N/A"}')
    echo "💾 CPU: ${cpu_pct}% | Memory: ${mem_pct}%"
  fi
  
  # Uptime
  local uptime_str
  uptime_str=$(systemctl show k3s --property=ActiveEnterTimestamp 2>/dev/null | cut -d= -f2)
  if [[ -n "$uptime_str" ]]; then
    echo "⏰ Since: $uptime_str"
  fi
  
  echo ""
  kctl get nodes -o wide 2>/dev/null
}

cmd_deploy() {
  ensure_k3s
  if [[ -z "$NAME" || -z "$IMAGE" ]]; then
    error "Both --name and --image are required"
    exit 1
  fi
  
  log "Deploying $NAME ($IMAGE) with $REPLICAS replicas..."
  
  local env_args=""
  for e in "${ENVS[@]}"; do
    env_args+="            - name: ${e%%=*}
              value: \"${e#*=}\"
"
  done
  
  local port_block=""
  if [[ -n "$PORT" ]]; then
    port_block="          ports:
            - containerPort: $PORT"
  fi
  
  cat <<YAML | kctl apply -n "$NAMESPACE" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $NAME
  labels:
    app: $NAME
spec:
  replicas: $REPLICAS
  selector:
    matchLabels:
      app: $NAME
  template:
    metadata:
      labels:
        app: $NAME
    spec:
      containers:
        - name: $NAME
          image: $IMAGE
${port_block}
$(if [[ -n "$env_args" ]]; then echo "          env:"; echo "$env_args"; fi)
YAML
  
  success "Deployment $NAME created"
  kctl rollout status deployment/"$NAME" -n "$NAMESPACE" --timeout=120s 2>/dev/null || warn "Rollout still in progress"
}

cmd_apply() {
  ensure_k3s
  if [[ -z "$FILE" ]]; then
    error "--file is required"
    exit 1
  fi
  kctl apply -n "$NAMESPACE" -f "$FILE"
  success "Applied $FILE"
}

cmd_list() {
  ensure_k3s
  echo "=== Deployments (namespace: $NAMESPACE) ==="
  kctl get deployments -n "$NAMESPACE" -o wide 2>/dev/null
  echo ""
  echo "=== Services ==="
  kctl get services -n "$NAMESPACE" -o wide 2>/dev/null
  echo ""
  echo "=== Pods ==="
  kctl get pods -n "$NAMESPACE" -o wide 2>/dev/null
}

cmd_scale() {
  ensure_k3s
  if [[ -z "$NAME" ]]; then error "--name is required"; exit 1; fi
  kctl scale deployment/"$NAME" --replicas="$REPLICAS" -n "$NAMESPACE"
  success "Scaled $NAME to $REPLICAS replicas"
}

cmd_update() {
  ensure_k3s
  if [[ -z "$NAME" || -z "$IMAGE" ]]; then
    error "Both --name and --image are required"
    exit 1
  fi
  kctl set image deployment/"$NAME" "$NAME=$IMAGE" -n "$NAMESPACE"
  success "Rolling update started: $NAME → $IMAGE"
  kctl rollout status deployment/"$NAME" -n "$NAMESPACE" --timeout=180s
}

cmd_rollback() {
  ensure_k3s
  if [[ -z "$NAME" ]]; then error "--name is required"; exit 1; fi
  kctl rollout undo deployment/"$NAME" -n "$NAMESPACE"
  success "Rolled back $NAME"
}

cmd_expose() {
  ensure_k3s
  if [[ -z "$NAME" || -z "$PORT" ]]; then
    error "Both --name and --port are required"
    exit 1
  fi
  TARGET_PORT="${TARGET_PORT:-$PORT}"
  kctl expose deployment "$NAME" \
    --type="$SVC_TYPE" \
    --port="$PORT" \
    --target-port="$TARGET_PORT" \
    -n "$NAMESPACE" 2>/dev/null || \
  kctl patch svc "$NAME" -n "$NAMESPACE" -p "{\"spec\":{\"type\":\"$SVC_TYPE\",\"ports\":[{\"port\":$PORT,\"targetPort\":$TARGET_PORT}]}}"
  success "Service $NAME exposed ($SVC_TYPE:$PORT→$TARGET_PORT)"
}

cmd_logs() {
  ensure_k3s
  if [[ -z "$NAME" ]]; then error "--name is required"; exit 1; fi
  kctl logs -l app="$NAME" -n "$NAMESPACE" --tail="$TAIL" --all-containers
}

cmd_describe() {
  ensure_k3s
  if [[ -z "$NAME" ]]; then error "--name is required"; exit 1; fi
  kctl describe deployment "$NAME" -n "$NAMESPACE"
}

cmd_delete() {
  ensure_k3s
  if [[ -z "$NAME" ]]; then error "--name is required"; exit 1; fi
  kctl delete deployment "$NAME" -n "$NAMESPACE"
  kctl delete service "$NAME" -n "$NAMESPACE" 2>/dev/null || true
  success "Deleted $NAME"
}

cmd_resources() {
  ensure_k3s
  echo "=== Node Resources ==="
  kctl top nodes 2>/dev/null || warn "Metrics server not available (install via: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml)"
  echo ""
  echo "=== Pod Resources (namespace: $NAMESPACE) ==="
  kctl top pods -n "$NAMESPACE" 2>/dev/null || true
}

cmd_health_check() {
  ensure_k3s
  local issues=()
  
  # Check node readiness
  local not_ready
  not_ready=$(kctl get nodes --no-headers 2>/dev/null | grep -v " Ready" | awk '{print $1}')
  if [[ -n "$not_ready" ]]; then
    issues+=("🔴 Nodes not ready: $not_ready")
  fi
  
  # Check failing pods
  local failing
  failing=$(kctl get pods --all-namespaces --no-headers 2>/dev/null | grep -vE "Running|Completed" | head -5)
  if [[ -n "$failing" ]]; then
    issues+=("🔴 Failing pods detected")
  fi
  
  # Check disk pressure
  local pressure
  pressure=$(kctl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="DiskPressure")].status}' 2>/dev/null)
  if echo "$pressure" | grep -q "True"; then
    issues+=("🔴 Disk pressure detected")
  fi
  
  if [[ ${#issues[@]} -gt 0 ]]; then
    local msg="⚠️ *K3s Cluster Alert*"$'\n'
    for issue in "${issues[@]}"; do
      msg+="$issue"$'\n'
    done
    echo "$msg"
    if [[ -n "$ALERT" ]]; then
      send_alert "$msg"
    fi
    return 1
  else
    echo -e "${GREEN}✅ Cluster healthy${NC}"
    return 0
  fi
}

cmd_monitor() {
  ensure_k3s
  log "Monitoring cluster every ${INTERVAL}s..."
  while true; do
    cmd_health_check || true
    sleep "$INTERVAL"
  done
}

cmd_backup() {
  ensure_k3s
  ensure_root
  OUTPUT="${OUTPUT:-/tmp/k3s-backup-$(date +%Y%m%d-%H%M%S).tar.gz}"
  
  log "Backing up K3s data..."
  
  # Stop k3s briefly for consistent snapshot
  local tmpdir
  tmpdir=$(mktemp -d)
  
  # Export all resources
  for ns in $(kctl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
    mkdir -p "$tmpdir/manifests/$ns"
    kctl get all -n "$ns" -o yaml > "$tmpdir/manifests/$ns/all.yaml" 2>/dev/null || true
    kctl get secrets -n "$ns" -o yaml > "$tmpdir/manifests/$ns/secrets.yaml" 2>/dev/null || true
    kctl get configmaps -n "$ns" -o yaml > "$tmpdir/manifests/$ns/configmaps.yaml" 2>/dev/null || true
  done
  
  # Copy K3s data
  if [[ -d /var/lib/rancher/k3s/server ]]; then
    cp -r /var/lib/rancher/k3s/server/token "$tmpdir/" 2>/dev/null || true
    # Snapshot etcd if using embedded
    if [[ -d /var/lib/rancher/k3s/server/db/etcd ]]; then
      k3s etcd-snapshot save --name backup-$(date +%Y%m%d) 2>/dev/null || true
      cp /var/lib/rancher/k3s/server/db/snapshots/* "$tmpdir/" 2>/dev/null || true
    fi
  fi
  
  tar -czf "$OUTPUT" -C "$tmpdir" .
  rm -rf "$tmpdir"
  
  success "Backup saved to $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
}

cmd_restore() {
  ensure_root
  if [[ -z "$FILE" ]]; then error "--file is required"; exit 1; fi
  if [[ ! -f "$FILE" ]]; then error "File not found: $FILE"; exit 1; fi
  
  log "Restoring from $FILE..."
  local tmpdir
  tmpdir=$(mktemp -d)
  tar -xzf "$FILE" -C "$tmpdir"
  
  # Restore manifests
  if [[ -d "$tmpdir/manifests" ]]; then
    for ns_dir in "$tmpdir/manifests"/*/; do
      local ns=$(basename "$ns_dir")
      kctl create namespace "$ns" 2>/dev/null || true
      kctl apply -f "$ns_dir/all.yaml" -n "$ns" 2>/dev/null || true
    done
  fi
  
  rm -rf "$tmpdir"
  success "Restore complete"
}

cmd_helm_install() {
  ensure_k3s
  if ! command -v helm &>/dev/null; then
    log "Installing Helm..."
    curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi
  
  if [[ -z "$NAME" || -z "$CHART" ]]; then
    error "Both --name and --chart are required"
    exit 1
  fi
  
  kctl create namespace "$NAMESPACE" 2>/dev/null || true
  
  local helm_args=()
  if [[ -n "$REPO" ]]; then
    helm repo add "$NAME" "$REPO" 2>/dev/null || true
    helm repo update
    helm_args+=("$NAME/$CHART")
  else
    helm_args+=("$CHART")
  fi
  
  for s in "${HELM_SET[@]}"; do
    helm_args+=(--set "$s")
  done
  
  helm install "$NAME" "${helm_args[@]}" -n "$NAMESPACE" --create-namespace
  success "Helm release $NAME installed"
}

cmd_helm_uninstall() {
  if [[ -z "$NAME" ]]; then error "--name is required"; exit 1; fi
  helm uninstall "$NAME" -n "$NAMESPACE"
  success "Helm release $NAME removed"
}

cmd_secret_create() {
  ensure_k3s
  if [[ -z "$NAME" ]]; then error "--name is required"; exit 1; fi
  
  local args=()
  for lit in "${LITERALS[@]}"; do
    args+=(--from-literal="$lit")
  done
  
  kctl create secret generic "$NAME" "${args[@]}" -n "$NAMESPACE"
  success "Secret $NAME created"
}

cmd_configmap_create() {
  ensure_k3s
  if [[ -z "$NAME" ]]; then error "--name is required"; exit 1; fi
  
  if [[ -n "$FROM_FILE" ]]; then
    kctl create configmap "$NAME" --from-file="$FROM_FILE" -n "$NAMESPACE"
  else
    error "Either --from-file or --literal required"
    exit 1
  fi
  success "ConfigMap $NAME created"
}

cmd_registry_login() {
  ensure_k3s
  if [[ -z "$SERVER" ]]; then error "--server is required"; exit 1; fi
  kctl create secret docker-registry regcred \
    --docker-server="$SERVER" \
    --docker-username="${NAME:-}" \
    --docker-password="${TOKEN:-}" \
    -n "$NAMESPACE" 2>/dev/null || \
  kctl patch secret regcred -n "$NAMESPACE" \
    -p "{\"data\":{\".dockerconfigjson\":\"$(echo -n "{\"auths\":{\"$SERVER\":{\"username\":\"$NAME\",\"password\":\"$TOKEN\"}}}" | base64 -w0)\"}}"
  success "Registry credentials saved for $SERVER"
}

cmd_diagnose() {
  ensure_k3s
  local target="${NODE:-$(kctl get nodes --no-headers | head -1 | awk '{print $1}')}"
  
  echo "=== Diagnosing node: $target ==="
  echo ""
  
  echo "--- Node Status ---"
  kctl describe node "$target" | grep -A5 "Conditions:" || true
  echo ""
  
  echo "--- System Info ---"
  kctl get node "$target" -o jsonpath='{.status.nodeInfo}' 2>/dev/null | python3 -m json.tool 2>/dev/null || true
  echo ""
  
  echo "--- Resource Pressure ---"
  kctl get node "$target" -o jsonpath='{range .status.conditions[*]}{.type}: {.status} ({.message}){"\n"}{end}' 2>/dev/null
  echo ""
  
  echo "--- Pods on Node ---"
  kctl get pods --all-namespaces --field-selector "spec.nodeName=$target" -o wide 2>/dev/null
  echo ""
  
  echo "--- K3s Service Status ---"
  systemctl status k3s --no-pager -l 2>/dev/null | head -20 || \
  systemctl status k3s-agent --no-pager -l 2>/dev/null | head -20 || \
  warn "Could not check systemd status"
}

cmd_upgrade() {
  ensure_root
  log "Upgrading K3s..."
  curl -sfL https://get.k3s.io | sh -
  success "K3s upgraded to $(k3s --version | head -1 | awk '{print $3}')"
  log "Restarting K3s..."
  systemctl restart k3s
  success "K3s restarted"
}

# Route commands
case "$COMMAND" in
  install)          cmd_install ;;
  join)             cmd_join ;;
  uninstall)        cmd_uninstall ;;
  status)           cmd_status ;;
  deploy)           cmd_deploy ;;
  apply)            cmd_apply ;;
  list)             cmd_list ;;
  scale)            cmd_scale ;;
  update)           cmd_update ;;
  rollback)         cmd_rollback ;;
  expose)           cmd_expose ;;
  logs)             cmd_logs ;;
  describe)         cmd_describe ;;
  delete)           cmd_delete ;;
  resources)        cmd_resources ;;
  monitor)          cmd_monitor ;;
  health-check)     cmd_health_check ;;
  backup)           cmd_backup ;;
  restore)          cmd_restore ;;
  helm-install)     cmd_helm_install ;;
  helm-uninstall)   cmd_helm_uninstall ;;
  secret-create)    cmd_secret_create ;;
  configmap-create) cmd_configmap_create ;;
  registry-login)   cmd_registry_login ;;
  diagnose)         cmd_diagnose ;;
  upgrade)          cmd_upgrade ;;
  help|--help|-h)   usage ;;
  *)                error "Unknown command: $COMMAND"; usage ;;
esac
