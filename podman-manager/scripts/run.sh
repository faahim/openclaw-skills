#!/bin/bash
# Podman Container Manager — Main Script
# Manages containers, pods, images, systemd services, and auto-updates

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[podman]${NC} $1"; }
warn() { echo -e "${YELLOW}[podman]${NC} $1"; }
error() { echo -e "${RED}[podman]${NC} $1" >&2; }
info() { echo -e "${CYAN}[podman]${NC} $1"; }

# Check podman is available
check_podman() {
    if ! command -v podman &>/dev/null; then
        error "Podman is not installed. Run: bash scripts/install.sh"
        exit 1
    fi
}

# Parse key=value args into associative arrays
declare -A ARGS
declare -a ENVS=()
declare -a VOLUMES=()
declare -a LABELS=()
declare -a EXTRA_ARGS=()
COMMAND=""
PASSTHROUGH=""

parse_args() {
    COMMAND="${1:-help}"
    shift || true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name) ARGS[name]="$2"; shift 2 ;;
            --image) ARGS[image]="$2"; shift 2 ;;
            --port) ARGS[port]="${ARGS[port]:-}${ARGS[port]:+ }-p $2"; shift 2 ;;
            --env) ENVS+=("-e" "$2"); shift 2 ;;
            --volume) VOLUMES+=("-v" "$2"); shift 2 ;;
            --label) LABELS+=("-l" "$2"); shift 2 ;;
            --pod) ARGS[pod]="$2"; shift 2 ;;
            --output) ARGS[output]="$2"; shift 2 ;;
            --input) ARGS[input]="$2"; shift 2 ;;
            --tail) ARGS[tail]="$2"; shift 2 ;;
            --memory) ARGS[memory]="$2"; shift 2 ;;
            --cpus) ARGS[cpus]="$2"; shift 2 ;;
            --dns) EXTRA_ARGS+=("--dns" "$2"); shift 2 ;;
            --network) ARGS[network]="$2"; shift 2 ;;
            --healthcheck) ARGS[healthcheck]="$2"; shift 2 ;;
            --healthcheck-interval) ARGS[hc_interval]="$2"; shift 2 ;;
            --healthcheck-retries) ARGS[hc_retries]="$2"; shift 2 ;;
            --images) ARGS[images]="true"; shift ;;
            --all) ARGS[all]="true"; shift ;;
            --) shift; PASSTHROUGH="$*"; break ;;
            *) EXTRA_ARGS+=("$1"); shift ;;
        esac
    done
}

cmd_run() {
    local name="${ARGS[name]:-}"
    local image="${ARGS[image]:-}"
    
    if [[ -z "$image" ]]; then
        error "Usage: run --name <name> --image <image> [--port host:container] [--env KEY=VAL] [--volume name:/path]"
        exit 1
    fi
    
    local cmd="podman run -d"
    [[ -n "$name" ]] && cmd+=" --name $name"
    [[ -n "${ARGS[port]:-}" ]] && cmd+=" ${ARGS[port]}"
    [[ -n "${ARGS[pod]:-}" ]] && cmd+=" --pod ${ARGS[pod]}"
    [[ -n "${ARGS[memory]:-}" ]] && cmd+=" --memory ${ARGS[memory]}"
    [[ -n "${ARGS[cpus]:-}" ]] && cmd+=" --cpus ${ARGS[cpus]}"
    [[ -n "${ARGS[network]:-}" ]] && cmd+=" --network ${ARGS[network]}"
    
    # Health check
    if [[ -n "${ARGS[healthcheck]:-}" ]]; then
        cmd+=" --health-cmd '${ARGS[healthcheck]}'"
        cmd+=" --health-interval ${ARGS[hc_interval]:-30s}"
        cmd+=" --health-retries ${ARGS[hc_retries]:-3}"
    fi
    
    # Add env vars, volumes, labels
    for e in "${ENVS[@]+"${ENVS[@]}"}"; do cmd+=" $e"; done
    for v in "${VOLUMES[@]+"${VOLUMES[@]}"}"; do cmd+=" $v"; done
    for l in "${LABELS[@]+"${LABELS[@]}"}"; do cmd+=" $l"; done
    for a in "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"; do cmd+=" $a"; done
    
    cmd+=" $image"
    
    info "Running: $cmd"
    CONTAINER_ID=$(eval "$cmd")
    
    log "✅ Container '${name:-$CONTAINER_ID}' started"
    [[ -n "${ARGS[port]:-}" ]] && log "   Ports: ${ARGS[port]//-p /}"
    log "   Image: $image"
    log "   ID: ${CONTAINER_ID:0:12}"
}

cmd_list() {
    if [[ "${ARGS[all]:-}" == "true" ]]; then
        podman ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Created}}"
    else
        podman ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    fi
}

cmd_stop() {
    local name="${ARGS[name]:-}"
    [[ -z "$name" ]] && { error "Usage: stop --name <container>"; exit 1; }
    podman stop "$name"
    log "✅ Container '$name' stopped"
}

cmd_rm() {
    local name="${ARGS[name]:-}"
    [[ -z "$name" ]] && { error "Usage: rm --name <container>"; exit 1; }
    podman rm -f "$name" 2>/dev/null || podman rm "$name"
    log "✅ Container '$name' removed"
}

cmd_logs() {
    local name="${ARGS[name]:-}"
    local tail="${ARGS[tail]:-100}"
    [[ -z "$name" ]] && { error "Usage: logs --name <container> [--tail N]"; exit 1; }
    podman logs --tail "$tail" "$name"
}

cmd_exec() {
    local name="${ARGS[name]:-}"
    [[ -z "$name" ]] && { error "Usage: exec --name <container> -- <command>"; exit 1; }
    podman exec -it "$name" $PASSTHROUGH
}

cmd_pull() {
    local image="${ARGS[image]:-}"
    [[ -z "$image" ]] && { error "Usage: pull --image <image>"; exit 1; }
    podman pull "$image"
    log "✅ Image '$image' pulled"
}

cmd_images() {
    podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.Created}}"
}

cmd_prune() {
    if [[ "${ARGS[all]:-}" == "true" ]]; then
        log "Pruning all unused resources..."
        podman system prune -af --volumes
        log "✅ System pruned (containers + images + volumes)"
    elif [[ "${ARGS[images]:-}" == "true" ]]; then
        podman image prune -af
        log "✅ Unused images pruned"
    else
        podman container prune -f
        log "✅ Stopped containers pruned"
    fi
}

cmd_generate_service() {
    local name="${ARGS[name]:-}"
    [[ -z "$name" ]] && { error "Usage: generate-service --name <container>"; exit 1; }
    
    local service_dir="$HOME/.config/systemd/user"
    mkdir -p "$service_dir"
    
    # Generate systemd unit file
    podman generate systemd --name "$name" --new --restart-policy=on-failure \
        --restart-sec=10 > "$service_dir/container-${name}.service"
    
    # Reload systemd
    systemctl --user daemon-reload
    systemctl --user enable "container-${name}.service"
    
    # Enable lingering
    loginctl enable-linger "$USER" 2>/dev/null || true
    
    log "✅ Systemd service created: $service_dir/container-${name}.service"
    log "   Auto-restart: on-failure"
    log "   Start on boot: enabled"
    log ""
    log "   Start:   systemctl --user start container-${name}.service"
    log "   Stop:    systemctl --user stop container-${name}.service"
    log "   Status:  systemctl --user status container-${name}.service"
    log "   Logs:    journalctl --user -u container-${name}.service"
}

cmd_setup_autoupdate() {
    local service_dir="$HOME/.config/systemd/user"
    mkdir -p "$service_dir"
    
    # Create auto-update timer
    cat > "$service_dir/podman-auto-update.timer" <<'EOF'
[Unit]
Description=Podman auto-update timer

[Timer]
OnCalendar=weekly
RandomizedDelaySec=900
Persistent=true

[Install]
WantedBy=timers.target
EOF

    cat > "$service_dir/podman-auto-update.service" <<'EOF'
[Unit]
Description=Podman auto-update service

[Service]
Type=oneshot
ExecStart=/usr/bin/podman auto-update
ExecStartPost=/usr/bin/podman image prune -f

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now podman-auto-update.timer
    
    log "✅ Auto-update timer enabled (weekly)"
    log "   Check schedule: systemctl --user list-timers"
    log "   Dry run: podman auto-update --dry-run"
    log ""
    log "   Label containers for auto-update:"
    log "   --label io.containers.autoupdate=registry"
}

cmd_create_pod() {
    local name="${ARGS[name]:-}"
    [[ -z "$name" ]] && { error "Usage: create-pod --name <pod-name> [--port host:container]"; exit 1; }
    
    local cmd="podman pod create --name $name"
    [[ -n "${ARGS[port]:-}" ]] && cmd+=" ${ARGS[port]}"
    
    eval "$cmd"
    log "✅ Pod '$name' created"
    log "   Add containers: bash scripts/run.sh run --pod $name --name <name> --image <image>"
}

cmd_backup() {
    local name="${ARGS[name]:-}"
    local output="${ARGS[output]:-${name:-container}.tar}"
    [[ -z "$name" ]] && { error "Usage: backup --name <container> [--output /path/file.tar]"; exit 1; }
    
    podman export "$name" -o "$output"
    local size=$(du -h "$output" | cut -f1)
    log "✅ Container '$name' exported to $output ($size)"
}

cmd_restore() {
    local name="${ARGS[name]:-}"
    local input="${ARGS[input]:-}"
    [[ -z "$input" ]] && { error "Usage: restore --name <name> --input /path/file.tar"; exit 1; }
    
    podman import "$input" "${name:-restored}"
    log "✅ Image imported from $input as '${name:-restored}'"
}

cmd_backup_volume() {
    local volume="${EXTRA_ARGS[0]:-}"
    local output="${ARGS[output]:-${volume:-volume}.tar.gz}"
    
    # Get volume path
    local vol_path
    vol_path=$(podman volume inspect "$volume" --format '{{.Mountpoint}}')
    
    tar czf "$output" -C "$vol_path" .
    local size=$(du -h "$output" | cut -f1)
    log "✅ Volume '$volume' backed up to $output ($size)"
}

cmd_help() {
    cat <<'EOF'
Podman Container Manager

USAGE:
    bash scripts/run.sh <command> [options]

COMMANDS:
    run                 Run a new container
    list                List containers (--all for stopped too)
    stop                Stop a container
    rm                  Remove a container
    logs                View container logs
    exec                Execute command in container
    pull                Pull an image
    images              List images
    prune               Remove unused resources
    generate-service    Create systemd service for container
    setup-autoupdate    Enable weekly auto-updates
    create-pod          Create a pod for grouped containers
    backup              Export container to tarball
    restore             Import container from tarball
    backup-volume       Backup a named volume
    help                Show this help

EXAMPLES:
    # Run nginx on port 8080
    bash scripts/run.sh run --name web --image nginx:alpine --port 8080:80

    # Run with environment and volume
    bash scripts/run.sh run --name db --image postgres:16 \
        --port 5432:5432 --env POSTGRES_PASSWORD=secret --volume pgdata:/var/lib/postgresql/data

    # Make it a systemd service
    bash scripts/run.sh generate-service --name db

    # Auto-update labeled containers
    bash scripts/run.sh run --name app --image myapp:latest \
        --label io.containers.autoupdate=registry --port 3000:3000
    bash scripts/run.sh setup-autoupdate
EOF
}

# Main
check_podman
parse_args "$@"

case $COMMAND in
    run) cmd_run ;;
    list|ls|ps) cmd_list ;;
    stop) cmd_stop ;;
    rm|remove) cmd_rm ;;
    logs) cmd_logs ;;
    exec) cmd_exec ;;
    pull) cmd_pull ;;
    images) cmd_images ;;
    prune) cmd_prune ;;
    generate-service) cmd_generate_service ;;
    setup-autoupdate) cmd_setup_autoupdate ;;
    create-pod) cmd_create_pod ;;
    backup) cmd_backup ;;
    restore) cmd_restore ;;
    backup-volume) cmd_backup_volume ;;
    help|--help|-h) cmd_help ;;
    *) error "Unknown command: $COMMAND"; cmd_help; exit 1 ;;
esac
