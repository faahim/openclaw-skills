#!/bin/bash
# Podman Manager — Container Operations
# Manages containers, pods, images, and systemd integration
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }
info() { echo -e "${CYAN}[i]${NC} $*"; }

check_podman() {
  command -v podman &>/dev/null || { err "Podman not installed. Run: bash scripts/install.sh"; exit 1; }
}

# Run a container
cmd_run() {
  local image="$1"; shift
  local name="" ports=() envs=() volumes=() detach=false interactive=false
  local extra_args=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --port|-p) ports+=("-p" "$2"); shift 2 ;;
      --env|-e) envs+=("-e" "$2"); shift 2 ;;
      --volume|-v) volumes+=("-v" "$2"); shift 2 ;;
      --detach|-d) detach=true; shift ;;
      --interactive|-it) interactive=true; shift ;;
      *) extra_args+=("$1"); shift ;;
    esac
  done

  local args=()
  [[ -n "$name" ]] && args+=(--name "$name")
  [[ "$detach" == true ]] && args+=(-d)
  [[ "$interactive" == true ]] && args+=(-it)
  args+=("${ports[@]}" "${envs[@]}" "${volumes[@]}" "${extra_args[@]}")

  # Default to detached if not interactive
  if [[ "$detach" == false && "$interactive" == false ]]; then
    args+=(-d)
  fi

  log "Starting container: $image"
  podman run "${args[@]}" "$image"
}

# List containers
cmd_list() {
  echo -e "${CYAN}📦 Running Containers${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  podman ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
  echo ""
  local total
  total=$(podman ps -q | wc -l)
  local stopped
  stopped=$(podman ps -aq --filter status=exited | wc -l)
  info "Running: $total | Stopped: $stopped"
}

# Stop container
cmd_stop() {
  local name="$1"
  log "Stopping container: $name"
  podman stop "$name"
  log "Stopped"
}

# Remove container
cmd_rm() {
  local name="$1"
  local force=""
  [[ "${2:-}" == "--force" || "${2:-}" == "-f" ]] && force="--force"
  log "Removing container: $name"
  podman rm $force "$name"
  log "Removed"
}

# View logs
cmd_logs() {
  local name="$1"; shift
  local follow=""
  [[ "${1:-}" == "--follow" || "${1:-}" == "-f" ]] && follow="--follow"
  podman logs $follow "$name"
}

# Execute in container
cmd_exec() {
  local name="$1"; shift
  podman exec -it "$name" "$@"
}

# Pull image
cmd_pull() {
  local image="$1"
  log "Pulling image: $image"
  podman pull "$image"
  log "Pull complete"
}

# Build image
cmd_build() {
  local args=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --tag|-t) args+=(-t "$2"); shift 2 ;;
      --file|-f) args+=(-f "$2"); shift 2 ;;
      --target) args+=(--target "$2"); shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  log "Building image..."
  podman build "${args[@]}"
  log "Build complete"
}

# List images
cmd_images() {
  echo -e "${CYAN}🖼️  Images${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.Created}}"
  echo ""
  local total_size
  total_size=$(podman system df --format '{{.TotalSize}}' 2>/dev/null | head -1)
  info "Total disk usage: ${total_size:-unknown}"
}

# Prune unused images
cmd_prune_images() {
  warn "This will remove all unused images"
  read -rp "Continue? [y/N] " ans
  [[ "$ans" =~ ^[Yy] ]] || { info "Cancelled"; return; }
  podman image prune -af
  log "Pruned unused images"
}

# Save image
cmd_save() {
  local image="$1"; shift
  local output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      -o|--output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$output" ]] && output="${image//[:\/]/_}.tar"
  log "Saving $image → $output"
  podman save -o "$output" "$image"
  log "Saved ($(du -sh "$output" | cut -f1))"
}

# Load image
cmd_load() {
  local input=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      -i|--input) input="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$input" ]] && { err "Usage: run.sh load -i <file>"; exit 1; }
  log "Loading image from $input"
  podman load -i "$input"
  log "Loaded"
}

# Create pod
cmd_pod_create() {
  local name="$1"; shift
  local ports=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --port|-p) ports+=("-p" "$2"); shift 2 ;;
      *) shift ;;
    esac
  done
  log "Creating pod: $name"
  podman pod create --name "$name" "${ports[@]}"
  log "Pod created"
}

# Add container to pod
cmd_pod_add() {
  local pod="$1" image="$2"; shift 2
  local envs=() extra=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --env|-e) envs+=("-e" "$2"); shift 2 ;;
      *) extra+=("$1"); shift ;;
    esac
  done
  log "Adding $image to pod $pod"
  podman run -d --pod "$pod" "${envs[@]}" "${extra[@]}" "$image"
  log "Added"
}

# List pods
cmd_pod_list() {
  echo -e "${CYAN}🔗 Pods${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  podman pod ps --format "table {{.Name}}\t{{.Status}}\t{{.NumberOfContainers}}\t{{.InfraId}}"
}

# Stop/start pod
cmd_pod_stop()  { podman pod stop "$1";  log "Pod $1 stopped"; }
cmd_pod_start() { podman pod start "$1"; log "Pod $1 started"; }

# Generate systemd service
cmd_systemd() {
  local name="$1"
  local dir="${HOME}/.config/systemd/user"
  mkdir -p "$dir"
  
  log "Generating systemd unit for container: $name"
  podman generate systemd --new --name "$name" --files --restart-policy=always 2>/dev/null \
    || podman generate systemd --name "$name" --files --restart-policy=always
  
  # Move generated files
  mv container-"${name}".service "$dir/" 2>/dev/null || true
  
  systemctl --user daemon-reload
  log "Service created: $dir/container-${name}.service"
  info "Enable with: systemctl --user enable container-${name}.service"
  info "Start with:  systemctl --user start container-${name}.service"
}

# Generate systemd for pod
cmd_systemd_pod() {
  local pod="$1"
  local dir="${HOME}/.config/systemd/user"
  mkdir -p "$dir"
  
  log "Generating systemd units for pod: $pod"
  cd "$dir"
  podman generate systemd --new --name "$pod" --files --restart-policy=always 2>/dev/null \
    || podman generate systemd --name "$pod" --files --restart-policy=always
  
  systemctl --user daemon-reload
  log "Pod services created in $dir/"
  info "Enable with: systemctl --user enable pod-${pod}.service"
}

# Docker compose compatibility
cmd_compose_up() {
  local file="${1:-docker-compose.yml}"
  if command -v podman-compose &>/dev/null; then
    podman-compose -f "$file" up -d
  else
    warn "podman-compose not found. Install with: pip install podman-compose"
    warn "Or use: bash scripts/install-compose.sh"
    exit 1
  fi
}

# Security check
cmd_security_check() {
  echo -e "${CYAN}🔐 Podman Security Report${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  local rootless
  rootless=$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)
  [[ "$rootless" == "true" ]] && echo -e "├── Rootless: ${GREEN}✅ Enabled${NC}" \
                               || echo -e "├── Rootless: ${RED}❌ Disabled${NC}"
  
  # Check user namespaces
  if grep -q "^$(whoami):" /etc/subuid 2>/dev/null; then
    local range
    range=$(grep "^$(whoami):" /etc/subuid | cut -d: -f3)
    echo -e "├── User namespace: ${GREEN}✅ Configured ($range UIDs)${NC}"
  else
    echo -e "├── User namespace: ${RED}❌ Not configured${NC}"
  fi
  
  # Network backend
  local net_backend
  net_backend=$(podman info --format '{{.Host.NetworkBackend}}' 2>/dev/null || echo "unknown")
  echo -e "├── Network backend: ${GREEN}$net_backend${NC}"
  
  # Seccomp
  local seccomp
  seccomp=$(podman info --format '{{.Host.Security.SECCOMPEnabled}}' 2>/dev/null || echo "unknown")
  [[ "$seccomp" == "true" ]] && echo -e "├── Seccomp: ${GREEN}✅ Enabled${NC}" \
                              || echo -e "├── Seccomp: ${YELLOW}⚠ $seccomp${NC}"
  
  # Storage driver
  local driver
  driver=$(podman info --format '{{.Store.GraphDriverName}}' 2>/dev/null)
  echo -e "└── Storage driver: ${GREEN}$driver${NC}"
  echo ""
}

# Configure rootless
cmd_configure_rootless() {
  log "Configuring rootless Podman..."
  
  # subuid/subgid
  if ! grep -q "^$(whoami):" /etc/subuid 2>/dev/null; then
    sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$(whoami)"
    log "Added subuid/subgid ranges"
  else
    log "subuid/subgid already configured"
  fi
  
  # Enable linger
  loginctl enable-linger "$(whoami)" 2>/dev/null && log "Enabled systemd linger" || true
  
  # Migrate storage
  podman system migrate 2>/dev/null && log "Storage migrated" || true
  
  log "Rootless configuration complete"
}

# Setup user namespaces
cmd_setup_userns() {
  cmd_configure_rootless
}

# Docker compat check
cmd_docker_compat_check() {
  echo -e "${CYAN}🐳 Docker Compatibility Check${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  echo -e "Podman version: $(podman --version | awk '{print $NF}')"
  
  if command -v docker &>/dev/null; then
    echo -e "Docker installed: ${YELLOW}Yes (may conflict)${NC}"
  else
    echo -e "Docker installed: ${GREEN}No (clean setup)${NC}"
  fi
  
  # Check if docker socket emulation is available
  if [ -S "/run/user/$(id -u)/podman/podman.sock" ]; then
    echo -e "Podman socket: ${GREEN}✅ Active${NC}"
    info "Docker clients can connect to: unix:///run/user/$(id -u)/podman/podman.sock"
  else
    echo -e "Podman socket: ${YELLOW}Not active${NC}"
    info "Start with: systemctl --user start podman.socket"
  fi
}

# Setup docker alias
cmd_setup_docker_alias() {
  local shell_rc=""
  if [ -f "$HOME/.zshrc" ]; then
    shell_rc="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    shell_rc="$HOME/.bashrc"
  fi
  
  if [ -n "$shell_rc" ]; then
    if ! grep -q "alias docker=podman" "$shell_rc" 2>/dev/null; then
      echo 'alias docker=podman' >> "$shell_rc"
      log "Added 'alias docker=podman' to $shell_rc"
      info "Run: source $shell_rc"
    else
      log "Alias already exists in $shell_rc"
    fi
  fi
  
  # Also enable podman socket for Docker API compat
  systemctl --user enable --now podman.socket 2>/dev/null && \
    log "Enabled Podman socket (Docker API compatible)" || true
}

# Import Docker images
cmd_import_docker_images() {
  if ! command -v docker &>/dev/null; then
    err "Docker not found — nothing to import"
    exit 1
  fi
  
  log "Importing Docker images to Podman..."
  docker images --format '{{.Repository}}:{{.Tag}}' | while read -r img; do
    [[ "$img" == *"<none>"* ]] && continue
    info "Importing: $img"
    docker save "$img" | podman load
  done
  log "Import complete"
}

# Main dispatcher
main() {
  check_podman
  
  local cmd="${1:-help}"; shift 2>/dev/null || true
  
  case "$cmd" in
    list|ls|ps)           cmd_list "$@" ;;
    stop)                 cmd_stop "$@" ;;
    rm|remove)            cmd_rm "$@" ;;
    logs)                 cmd_logs "$@" ;;
    exec)                 cmd_exec "$@" ;;
    pull)                 cmd_pull "$@" ;;
    build)                cmd_build "$@" ;;
    images)               cmd_images "$@" ;;
    prune-images)         cmd_prune_images "$@" ;;
    save)                 cmd_save "$@" ;;
    load)                 cmd_load "$@" ;;
    pod-create)           cmd_pod_create "$@" ;;
    pod-add)              cmd_pod_add "$@" ;;
    pod-list|pods)        cmd_pod_list "$@" ;;
    pod-stop)             cmd_pod_stop "$@" ;;
    pod-start)            cmd_pod_start "$@" ;;
    systemd)              cmd_systemd "$@" ;;
    systemd-pod)          cmd_systemd_pod "$@" ;;
    compose-up)           cmd_compose_up "$@" ;;
    security-check)       cmd_security_check "$@" ;;
    configure-rootless)   cmd_configure_rootless "$@" ;;
    setup-userns)         cmd_setup_userns "$@" ;;
    docker-compat-check)  cmd_docker_compat_check "$@" ;;
    setup-docker-alias)   cmd_setup_docker_alias "$@" ;;
    import-docker-images) cmd_import_docker_images "$@" ;;
    help|--help|-h)
      echo "Podman Manager — Container Operations"
      echo ""
      echo "Usage: bash run.sh <command> [args]"
      echo ""
      echo "Container commands:"
      echo "  <image> [opts]      Run a container (--name, --port, --env, --volume, --detach)"
      echo "  list                List running containers"
      echo "  stop <name>         Stop a container"
      echo "  rm <name>           Remove a container"
      echo "  logs <name>         View container logs (--follow)"
      echo "  exec <name> <cmd>   Execute command in container"
      echo ""
      echo "Image commands:"
      echo "  pull <image>        Pull an image"
      echo "  build [opts] <dir>  Build image (--tag, --file, --target)"
      echo "  images              List images"
      echo "  prune-images        Remove unused images"
      echo "  save <img> -o <f>   Export image to tar"
      echo "  load -i <file>      Import image from tar"
      echo ""
      echo "Pod commands:"
      echo "  pod-create <name>   Create pod (--port)"
      echo "  pod-add <pod> <img> Add container to pod"
      echo "  pod-list            List pods"
      echo "  pod-stop <name>     Stop pod"
      echo "  pod-start <name>    Start pod"
      echo ""
      echo "System commands:"
      echo "  systemd <name>      Generate systemd service for container"
      echo "  systemd-pod <name>  Generate systemd services for pod"
      echo "  compose-up [file]   Run docker-compose.yml with podman-compose"
      echo "  security-check      Show security configuration"
      echo "  configure-rootless  Set up rootless mode"
      echo "  docker-compat-check Check Docker compatibility"
      echo "  setup-docker-alias  Create 'docker' → 'podman' alias"
      echo "  import-docker-images Import all Docker images to Podman"
      ;;
    *)
      # Default: treat as image name to run
      cmd_run "$cmd" "$@"
      ;;
  esac
}

main "$@"
