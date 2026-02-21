#!/bin/bash
# Docker Manager — Container lifecycle, monitoring, and cleanup
# Requires: docker, bash 4+, jq, curl (for alerts)

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALERT_STATE_FILE="/tmp/docker-manager-alerts.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
MEM_THRESHOLD="${DOCKER_MEM_THRESHOLD:-80}"
CPU_THRESHOLD="${DOCKER_CPU_THRESHOLD:-90}"

# ─── Helpers ───

log_info()  { echo -e "${GREEN}✅${NC} $*"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
log_error() { echo -e "${RED}❌${NC} $*"; }
log_head()  { echo -e "\n${BLUE}🐳 $*${NC}"; }

check_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed. Install: https://docs.docker.com/get-docker/"
        exit 1
    fi
    if ! docker info &>/dev/null; then
        log_error "Cannot connect to Docker daemon. Is it running? Try: sudo systemctl start docker"
        exit 1
    fi
}

send_telegram() {
    local message="$1"
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TELEGRAM_CHAT_ID}" \
            -d text="${message}" \
            -d parse_mode="Markdown" > /dev/null 2>&1 || true
    fi
}

format_bytes() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        echo "$(echo "scale=1; $bytes/1073741824" | bc)GB"
    elif (( bytes >= 1048576 )); then
        echo "$(echo "scale=1; $bytes/1048576" | bc)MB"
    elif (( bytes >= 1024 )); then
        echo "$(echo "scale=0; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# ─── Commands ───

cmd_status() {
    check_docker
    log_head "Docker Manager Status"

    local version
    version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    echo "Docker Version: $version"

    local running stopped
    running=$(docker ps -q | wc -l)
    stopped=$(docker ps -aq --filter "status=exited" | wc -l)
    echo "Containers: $running running, $stopped stopped"

    local image_count
    image_count=$(docker images -q | wc -l)
    local image_size
    image_size=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1 || echo "unknown")
    echo "Images: $image_count ($image_size)"

    local vol_count net_count
    vol_count=$(docker volume ls -q | wc -l)
    net_count=$(docker network ls -q | wc -l)
    echo "Volumes: $vol_count"
    echo "Networks: $net_count"

    local total_size
    total_size=$(docker system df --format '{{.Size}}' 2>/dev/null | tail -1 || echo "unknown")
    echo "Disk Usage: $total_size total"
}

cmd_list() {
    check_docker
    log_head "Running Containers"

    # Header
    printf "%-20s %-25s %-15s %-6s %-8s %s\n" "CONTAINER" "IMAGE" "STATUS" "CPU" "MEM" "PORTS"
    echo "─────────────────────────────────────────────────────────────────────────────────────"

    # Get stats for running containers
    local containers
    containers=$(docker ps --format '{{.Names}}')

    if [[ -z "$containers" ]]; then
        echo "(no running containers)"
        return
    fi

    while IFS= read -r name; do
        local image status ports
        image=$(docker inspect --format '{{.Config.Image}}' "$name" 2>/dev/null | cut -c1-24)
        status=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null)

        # Get uptime
        local started_at uptime_str
        started_at=$(docker inspect --format '{{.State.StartedAt}}' "$name" 2>/dev/null)
        if [[ -n "$started_at" ]]; then
            local start_epoch now_epoch diff_s
            start_epoch=$(date -d "$started_at" +%s 2>/dev/null || echo 0)
            now_epoch=$(date +%s)
            diff_s=$((now_epoch - start_epoch))
            if (( diff_s >= 86400 )); then
                uptime_str="Up $((diff_s/86400))d"
            elif (( diff_s >= 3600 )); then
                uptime_str="Up $((diff_s/3600))h"
            else
                uptime_str="Up $((diff_s/60))m"
            fi
        else
            uptime_str="$status"
        fi

        # Get ports
        ports=$(docker port "$name" 2>/dev/null | awk -F: '{print $NF}' | paste -sd, - || echo "-")
        [[ -z "$ports" ]] && ports="-"

        # Get stats (CPU/MEM) — one-shot
        local cpu mem
        local stats_line
        stats_line=$(docker stats --no-stream --format '{{.CPUPerc}} {{.MemUsage}}' "$name" 2>/dev/null || echo "0% 0B / 0B")
        cpu=$(echo "$stats_line" | awk '{print $1}')
        mem=$(echo "$stats_line" | awk '{print $2}')

        printf "%-20s %-25s %-15s %-6s %-8s %s\n" "$name" "$image" "$uptime_str" "$cpu" "$mem" "$ports"
    done <<< "$containers"
}

cmd_run() {
    check_docker
    local name="" image="" port="" restart="" env_vars=() extra_args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift 2 ;;
            --image) image="$2"; shift 2 ;;
            --port|-p) port="$2"; shift 2 ;;
            --restart) restart="$2"; shift 2 ;;
            --env|-e) env_vars+=("-e" "$2"); shift 2 ;;
            --volume|-v) extra_args+=("-v" "$2"); shift 2 ;;
            --detach|-d) extra_args+=("-d"); shift ;;
            *) extra_args+=("$1"); shift ;;
        esac
    done

    if [[ -z "$image" ]]; then
        log_error "Usage: docker-manager.sh run --name <name> --image <image> [--port host:container] [--restart always]"
        exit 1
    fi

    local cmd=(docker run -d)
    [[ -n "$name" ]] && cmd+=(--name "$name")
    [[ -n "$port" ]] && cmd+=(-p "$port")
    [[ -n "$restart" ]] && cmd+=(--restart "$restart")
    cmd+=("${env_vars[@]}" "${extra_args[@]}" "$image")

    log_info "Starting container${name:+ '$name'} from $image..."
    local cid
    cid=$("${cmd[@]}")
    log_info "Container started: ${cid:0:12}"
}

cmd_stop() {
    check_docker
    local name="$1"
    [[ -z "$name" ]] && { log_error "Usage: docker-manager.sh stop <container>"; exit 1; }
    log_info "Stopping $name..."
    docker stop "$name"
    log_info "$name stopped."
}

cmd_restart() {
    check_docker
    local name="$1"
    [[ -z "$name" ]] && { log_error "Usage: docker-manager.sh restart <container>"; exit 1; }
    log_info "Restarting $name..."
    docker restart "$name"
    log_info "$name restarted."
}

cmd_rm() {
    check_docker
    local name="$1"; shift
    local force=""
    [[ "${1:-}" == "--force" ]] && force="-f"
    [[ -z "$name" ]] && { log_error "Usage: docker-manager.sh rm <container> [--force]"; exit 1; }

    if [[ -z "$force" ]]; then
        local status
        status=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "")
        if [[ "$status" == "running" ]]; then
            log_error "$name is running. Use --force to remove, or stop it first."
            exit 1
        fi
    fi

    docker rm $force "$name"
    log_info "$name removed."
}

cmd_logs() {
    check_docker
    local name="$1"; shift
    local tail="" follow=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tail) tail="$2"; shift 2 ;;
            --follow|-f) follow="--follow"; shift ;;
            *) shift ;;
        esac
    done

    [[ -z "$name" ]] && { log_error "Usage: docker-manager.sh logs <container> [--tail N] [--follow]"; exit 1; }

    docker logs ${tail:+--tail "$tail"} $follow "$name"
}

cmd_exec_container() {
    check_docker
    local name="$1"; shift
    local command="$*"
    [[ -z "$name" || -z "$command" ]] && { log_error "Usage: docker-manager.sh exec <container> \"<command>\""; exit 1; }
    docker exec -it "$name" sh -c "$command"
}

cmd_compose_up() {
    check_docker
    local compose_file="$1"
    [[ -z "$compose_file" ]] && { log_error "Usage: docker-manager.sh compose-up <docker-compose.yml>"; exit 1; }
    [[ ! -f "$compose_file" ]] && { log_error "File not found: $compose_file"; exit 1; }

    log_info "Deploying compose stack from $compose_file..."
    docker compose -f "$compose_file" up -d
    log_info "Stack deployed."
    docker compose -f "$compose_file" ps
}

cmd_compose_down() {
    check_docker
    local compose_file="$1"
    [[ -z "$compose_file" ]] && { log_error "Usage: docker-manager.sh compose-down <docker-compose.yml>"; exit 1; }
    log_info "Bringing down compose stack..."
    docker compose -f "$compose_file" down
    log_info "Stack stopped and removed."
}

cmd_compose_update() {
    check_docker
    local compose_file="$1"
    [[ -z "$compose_file" ]] && { log_error "Usage: docker-manager.sh compose-update <docker-compose.yml>"; exit 1; }
    log_info "Pulling latest images..."
    docker compose -f "$compose_file" pull
    log_info "Redeploying..."
    docker compose -f "$compose_file" up -d
    log_info "Stack updated."
}

cmd_disk() {
    check_docker
    log_head "Docker Disk Usage"
    docker system df -v 2>/dev/null || docker system df
}

cmd_prune() {
    check_docker
    local target="${1:-}"
    local older_than=""
    shift || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --older-than) older_than="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    case "$target" in
        images)
            log_info "Pruning unused images..."
            if [[ -n "$older_than" ]]; then
                docker image prune -a -f --filter "until=$older_than"
            else
                docker image prune -f
            fi
            ;;
        containers)
            log_info "Pruning stopped containers..."
            docker container prune -f
            ;;
        volumes)
            log_warn "This will remove ALL unused volumes. Data may be lost!"
            docker volume prune -f
            ;;
        networks)
            log_info "Pruning unused networks..."
            docker network prune -f
            ;;
        all)
            log_warn "Full cleanup: unused images, containers, volumes, networks..."
            docker system prune -a -f --volumes
            ;;
        *)
            log_error "Usage: docker-manager.sh prune [images|containers|volumes|networks|all] [--older-than 30d]"
            exit 1
            ;;
    esac
    log_info "Prune complete."
}

cmd_health() {
    check_docker
    local alert="${2:-}"
    log_head "Container Health Check"

    local issues=0
    local report=""

    # Check for exited containers
    local exited
    exited=$(docker ps -a --filter "status=exited" --format '{{.Names}} ({{.Status}})' 2>/dev/null)
    if [[ -n "$exited" ]]; then
        report+="⚠️ *Exited containers:*\n"
        while IFS= read -r line; do
            report+="  - $line\n"
            ((issues++))
        done <<< "$exited"
    fi

    # Check for OOMKilled containers
    local containers
    containers=$(docker ps -aq 2>/dev/null)
    if [[ -n "$containers" ]]; then
        while IFS= read -r cid; do
            local name oom
            name=$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null | sed 's/^\///')
            oom=$(docker inspect --format '{{.State.OOMKilled}}' "$cid" 2>/dev/null)
            if [[ "$oom" == "true" ]]; then
                report+="🚨 *OOMKilled:* $name\n"
                ((issues++))
            fi
        done <<< "$containers"
    fi

    # Check resource usage of running containers
    local stats
    stats=$(docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemPerc}}' 2>/dev/null || true)
    if [[ -n "$stats" ]]; then
        while IFS='|' read -r name cpu mem; do
            cpu_val=$(echo "$cpu" | tr -d '%')
            mem_val=$(echo "$mem" | tr -d '%')

            if (( $(echo "$mem_val > $MEM_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
                report+="⚠️ *High memory:* $name at ${mem}%\n"
                ((issues++))
            fi
            if (( $(echo "$cpu_val > $CPU_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
                report+="⚠️ *High CPU:* $name at ${cpu}%\n"
                ((issues++))
            fi
        done <<< "$stats"
    fi

    # Check disk usage
    local disk_reclaimable
    disk_reclaimable=$(docker system df --format '{{.Reclaimable}}' 2>/dev/null | head -1 || echo "0B")
    report+="💾 Reclaimable disk space: $disk_reclaimable\n"

    if (( issues == 0 )); then
        log_info "All containers healthy. No issues detected."
        echo -e "$report"
    else
        log_warn "$issues issue(s) detected:"
        echo -e "$report"

        if [[ "$alert" == "telegram" || "$alert" == "--alert" ]]; then
            send_telegram "🐳 Docker Health Alert — $issues issue(s):\n$report"
        fi
    fi
}

cmd_monitor() {
    check_docker
    local interval=60 alert="" mem_thresh="$MEM_THRESHOLD" containers_filter="" auto_restart=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --interval) interval="$2"; shift 2 ;;
            --alert) alert="$2"; shift 2 ;;
            --mem-threshold) mem_thresh="$2"; shift 2 ;;
            --containers) containers_filter="$2"; shift 2 ;;
            --auto-restart) auto_restart="1"; shift ;;
            --config) shift 2 ;;  # TODO: yaml config parsing
            *) shift ;;
        esac
    done

    MEM_THRESHOLD="$mem_thresh"
    log_info "Monitoring Docker every ${interval}s (Ctrl+C to stop)..."
    [[ -n "$alert" ]] && log_info "Alerts: $alert"

    # Initialize alert state
    echo '{}' > "$ALERT_STATE_FILE"

    while true; do
        echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Checking..."

        # Check for crashed containers
        local exited_containers
        exited_containers=$(docker ps -a --filter "status=exited" --format '{{.Names}}' 2>/dev/null)

        if [[ -n "$exited_containers" ]]; then
            while IFS= read -r name; do
                # Filter if specified
                if [[ -n "$containers_filter" && ! ",$containers_filter," == *",$name,"* ]]; then
                    continue
                fi

                local exit_code
                exit_code=$(docker inspect --format '{{.State.ExitCode}}' "$name" 2>/dev/null || echo "?")
                local oom
                oom=$(docker inspect --format '{{.State.OOMKilled}}' "$name" 2>/dev/null || echo "false")

                local reason="exit code $exit_code"
                [[ "$oom" == "true" ]] && reason="OOMKilled"

                # Check if we already alerted for this
                local alerted
                alerted=$(jq -r ".[\"$name\"] // \"\"" "$ALERT_STATE_FILE" 2>/dev/null || echo "")
                if [[ "$alerted" != "exited" ]]; then
                    local msg="🚨 Container '$name' exited ($reason)"
                    log_error "$msg"

                    # Get last few log lines
                    local last_logs
                    last_logs=$(docker logs --tail 5 "$name" 2>&1 || echo "(no logs)")
                    msg+="\nLast logs:\n$last_logs"

                    [[ -n "$alert" ]] && send_telegram "$msg"

                    # Auto-restart if enabled
                    if [[ -n "$auto_restart" ]]; then
                        log_info "Auto-restarting $name..."
                        docker start "$name" 2>/dev/null && log_info "$name restarted." || log_error "Failed to restart $name"
                    fi

                    # Update alert state
                    jq ".[\"$name\"] = \"exited\"" "$ALERT_STATE_FILE" > "${ALERT_STATE_FILE}.tmp" && mv "${ALERT_STATE_FILE}.tmp" "$ALERT_STATE_FILE"
                fi
            done <<< "$exited_containers"
        fi

        # Check resource usage
        local stats
        stats=$(docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemPerc}}|{{.MemUsage}}' 2>/dev/null || true)
        if [[ -n "$stats" ]]; then
            while IFS='|' read -r name cpu mem mem_usage; do
                if [[ -n "$containers_filter" && ! ",$containers_filter," == *",$name,"* ]]; then
                    continue
                fi

                mem_val=$(echo "$mem" | tr -d '%')
                cpu_val=$(echo "$cpu" | tr -d '%')

                local status_icon="✅"
                if (( $(echo "$mem_val > $MEM_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
                    status_icon="⚠️"
                    local alerted
                    alerted=$(jq -r ".[\"${name}_mem\"] // \"\"" "$ALERT_STATE_FILE" 2>/dev/null || echo "")
                    if [[ "$alerted" != "high" ]]; then
                        local msg="⚠️ High memory: $name at ${mem} ($mem_usage)"
                        log_warn "$msg"
                        [[ -n "$alert" ]] && send_telegram "$msg"
                        jq ".[\"${name}_mem\"] = \"high\"" "$ALERT_STATE_FILE" > "${ALERT_STATE_FILE}.tmp" && mv "${ALERT_STATE_FILE}.tmp" "$ALERT_STATE_FILE"
                    fi
                else
                    # Clear alert state if recovered
                    jq "del(.[\"${name}_mem\"])" "$ALERT_STATE_FILE" > "${ALERT_STATE_FILE}.tmp" && mv "${ALERT_STATE_FILE}.tmp" "$ALERT_STATE_FILE" 2>/dev/null || true
                fi

                echo "  $status_icon $name — CPU: $cpu, Mem: $mem ($mem_usage)"
            done <<< "$stats"
        fi

        sleep "$interval"
    done
}

cmd_images() {
    check_docker
    log_head "Docker Images"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}\t{{.ID}}"
}

cmd_pull() {
    check_docker
    local image="$1"
    [[ -z "$image" ]] && { log_error "Usage: docker-manager.sh pull <image>"; exit 1; }
    log_info "Pulling $image..."
    docker pull "$image"
    log_info "$image pulled."
}

cmd_build() {
    check_docker
    local tag="" path="."
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tag|-t) tag="$2"; shift 2 ;;
            --path) path="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [[ -z "$tag" ]] && { log_error "Usage: docker-manager.sh build --tag <name:tag> [--path <dir>]"; exit 1; }
    log_info "Building $tag from $path..."
    docker build -t "$tag" "$path"
    log_info "$tag built."
}

cmd_networks() {
    check_docker
    log_head "Docker Networks"
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
}

cmd_volumes() {
    check_docker
    log_head "Docker Volumes"
    docker volume ls --format "table {{.Name}}\t{{.Driver}}"
}

cmd_volume_backup() {
    check_docker
    local volume="$1" dest="$2"
    [[ -z "$volume" || -z "$dest" ]] && { log_error "Usage: docker-manager.sh volume-backup <volume> <dest.tar.gz>"; exit 1; }

    log_info "Backing up volume '$volume' to $dest..."
    docker run --rm -v "$volume":/data -v "$(dirname "$dest")":/backup alpine \
        tar czf "/backup/$(basename "$dest")" -C /data .
    log_info "Backup saved to $dest"
}

cmd_report() {
    check_docker
    log_head "Docker Environment Report"
    echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""

    echo "## System"
    docker version --format 'Docker {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})' 2>/dev/null || true
    echo ""

    echo "## Containers"
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    echo ""

    echo "## Resource Usage"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || echo "(no running containers)"
    echo ""

    echo "## Disk Usage"
    docker system df
    echo ""

    echo "## Images"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
}

cmd_check_updates() {
    check_docker
    log_head "Checking for Image Updates"

    local images
    images=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' | sort -u)

    while IFS= read -r image; do
        [[ -z "$image" ]] && continue
        local local_digest remote_digest
        local_digest=$(docker inspect --format '{{index .RepoDigests 0}}' "$image" 2>/dev/null || echo "none")

        echo -n "  Checking $image... "
        if docker pull -q "$image" >/dev/null 2>&1; then
            remote_digest=$(docker inspect --format '{{index .RepoDigests 0}}' "$image" 2>/dev/null || echo "none2")
            if [[ "$local_digest" != "$remote_digest" ]]; then
                echo "🔄 UPDATE AVAILABLE"
            else
                echo "✅ up to date"
            fi
        else
            echo "⚠️ could not check"
        fi
    done <<< "$images"
}

# ─── Main ───

cmd="${1:-help}"
shift || true

case "$cmd" in
    status)          cmd_status ;;
    list|ls|ps)      cmd_list ;;
    run)             cmd_run "$@" ;;
    stop)            cmd_stop "${1:-}" ;;
    restart)         cmd_restart "${1:-}" ;;
    rm|remove)       cmd_rm "${1:-}" "${2:-}" ;;
    logs)            cmd_logs "$@" ;;
    exec)            cmd_exec_container "$@" ;;
    compose-up)      cmd_compose_up "${1:-}" ;;
    compose-down)    cmd_compose_down "${1:-}" ;;
    compose-status)  cmd_compose_up "${1:-}" ;;  # same as up with no changes
    compose-update)  cmd_compose_update "${1:-}" ;;
    disk)            cmd_disk ;;
    prune)           cmd_prune "$@" ;;
    health)          cmd_health "$@" ;;
    monitor)         cmd_monitor "$@" ;;
    images)          cmd_images ;;
    pull)            cmd_pull "${1:-}" ;;
    build)           cmd_build "$@" ;;
    rmi)             check_docker; docker rmi "${1:-}"; log_info "Image removed." ;;
    networks)        cmd_networks ;;
    network-create)  check_docker; docker network create "${@}"; log_info "Network created." ;;
    volumes)         cmd_volumes ;;
    volume-inspect)  check_docker; docker volume inspect "${1:-}" ;;
    volume-backup)   cmd_volume_backup "${1:-}" "${2:-}" ;;
    report)          cmd_report ;;
    check-updates)   cmd_check_updates ;;
    help|--help|-h)
        echo "Docker Manager v${VERSION}"
        echo ""
        echo "Usage: docker-manager.sh <command> [options]"
        echo ""
        echo "Container Commands:"
        echo "  status                    Docker system status"
        echo "  list/ls/ps                List running containers with stats"
        echo "  run --image <img>         Start a new container"
        echo "  stop <name>               Stop a container"
        echo "  restart <name>            Restart a container"
        echo "  rm <name> [--force]       Remove a container"
        echo "  logs <name> [--tail N]    View container logs"
        echo "  exec <name> \"<cmd>\"       Execute command in container"
        echo ""
        echo "Compose Commands:"
        echo "  compose-up <file>         Deploy compose stack"
        echo "  compose-down <file>       Take down compose stack"
        echo "  compose-update <file>     Pull + redeploy compose stack"
        echo ""
        echo "Image Commands:"
        echo "  images                    List images"
        echo "  pull <image>              Pull an image"
        echo "  build --tag <t> [--path]  Build image from Dockerfile"
        echo "  rmi <image>               Remove an image"
        echo "  check-updates             Check for image updates"
        echo ""
        echo "Cleanup Commands:"
        echo "  disk                      Show disk usage"
        echo "  prune <target>            Prune: images|containers|volumes|networks|all"
        echo ""
        echo "Monitoring Commands:"
        echo "  health [--alert telegram] One-shot health check"
        echo "  monitor [--interval N]    Continuous monitoring"
        echo "  report                    Generate full report"
        echo ""
        echo "Volume/Network:"
        echo "  volumes                   List volumes"
        echo "  volume-backup <v> <dest>  Backup volume to tar.gz"
        echo "  networks                  List networks"
        echo "  network-create <name>     Create a network"
        ;;
    *)
        log_error "Unknown command: $cmd (try: docker-manager.sh help)"
        exit 1
        ;;
esac
