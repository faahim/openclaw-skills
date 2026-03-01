#!/bin/bash
# Portainer Manager — Install, configure, and manage Portainer CE via CLI
# Requires: docker, curl, jq

set -euo pipefail

# Configuration
CONFIG_DIR="${HOME}/.config/portainer"
CONFIG_FILE="${CONFIG_DIR}/config.json"
PORTAINER_HTTPS_PORT="${PORTAINER_HTTPS_PORT:-9443}"
PORTAINER_EDGE_PORT="${PORTAINER_EDGE_PORT:-8000}"
PORTAINER_IMAGE="portainer/portainer-ce:latest"
PORTAINER_CONTAINER="portainer"
PORTAINER_VOLUME="portainer_data"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}✅${NC} $*"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC} $*"; }
log_error() { echo -e "${RED}❌${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}→${NC} $*"; }

# Load config if exists
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        PORTAINER_URL=$(jq -r '.url // empty' "$CONFIG_FILE" 2>/dev/null || echo "")
        PORTAINER_API_KEY=$(jq -r '.api_key // empty' "$CONFIG_FILE" 2>/dev/null || echo "")
        ENDPOINT_ID=$(jq -r '.endpoint_id // 1' "$CONFIG_FILE" 2>/dev/null || echo "1")
    fi
    PORTAINER_URL="${PORTAINER_URL:-https://localhost:${PORTAINER_HTTPS_PORT}}"
    PORTAINER_API_KEY="${PORTAINER_API_KEY:-}"
    ENDPOINT_ID="${ENDPOINT_ID:-1}"
}

save_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
{
    "url": "${PORTAINER_URL}",
    "api_key": "${PORTAINER_API_KEY}",
    "username": "${PORTAINER_USERNAME:-admin}",
    "endpoint_id": ${ENDPOINT_ID}
}
EOF
    chmod 600 "$CONFIG_FILE"
}

# API helper
api() {
    local method="$1"
    local path="$2"
    shift 2
    local url="${PORTAINER_URL}/api${path}"

    local args=(-s -k -X "$method")
    if [[ -n "$PORTAINER_API_KEY" ]]; then
        args+=(-H "X-API-Key: ${PORTAINER_API_KEY}")
    fi
    args+=("$@" "$url")

    curl "${args[@]}" 2>/dev/null
}

api_auth() {
    local method="$1"
    local path="$2"
    shift 2

    if [[ -z "$PORTAINER_API_KEY" ]]; then
        log_error "Not authenticated. Run: portainer.sh init --password <password>"
        exit 1
    fi
    api "$method" "$path" "$@"
}

# Check prerequisites
check_deps() {
    local missing=()
    for cmd in docker curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        echo "Install them:"
        echo "  Ubuntu/Debian: sudo apt-get install ${missing[*]}"
        echo "  Mac: brew install ${missing[*]}"
        [[ " ${missing[*]} " =~ " docker " ]] && echo "  Docker: curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
}

# Commands
cmd_install() {
    check_deps
    log_step "Installing Portainer CE..."

    # Check if already running
    if docker ps --format '{{.Names}}' | grep -q "^${PORTAINER_CONTAINER}$"; then
        log_warn "Portainer is already running"
        docker ps --filter "name=${PORTAINER_CONTAINER}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        return 0
    fi

    # Remove stopped container if exists
    docker rm -f "$PORTAINER_CONTAINER" 2>/dev/null || true

    # Create volume
    docker volume create "$PORTAINER_VOLUME" 2>/dev/null || true
    log_step "Created volume: ${PORTAINER_VOLUME}"

    # Pull latest image
    log_step "Pulling ${PORTAINER_IMAGE}..."
    docker pull "$PORTAINER_IMAGE"

    # Run Portainer
    docker run -d \
        --name "$PORTAINER_CONTAINER" \
        --restart=always \
        -p "${PORTAINER_HTTPS_PORT}:9443" \
        -p "${PORTAINER_EDGE_PORT}:8000" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "${PORTAINER_VOLUME}:/data" \
        "$PORTAINER_IMAGE"

    log_info "Portainer CE installed and running!"
    echo ""
    echo "  HTTPS URL: https://localhost:${PORTAINER_HTTPS_PORT}"
    echo ""
    echo "  Next step: Initialize admin account:"
    echo "  bash scripts/portainer.sh init --password \"YourSecurePassword\""
}

cmd_init() {
    local password=""
    local username="admin"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --password) password="$2"; shift 2 ;;
            --username) username="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$password" ]]; then
        log_error "Password required: --password <password>"
        exit 1
    fi

    if [[ ${#password} -lt 12 ]]; then
        log_error "Password must be at least 12 characters"
        exit 1
    fi

    PORTAINER_URL="https://localhost:${PORTAINER_HTTPS_PORT}"

    # Wait for Portainer to be ready
    log_step "Waiting for Portainer to be ready..."
    for i in $(seq 1 30); do
        if curl -sk "${PORTAINER_URL}/api/status" &>/dev/null; then
            break
        fi
        sleep 1
    done

    # Check if admin already exists
    local status
    status=$(curl -sk -o /dev/null -w "%{http_code}" "${PORTAINER_URL}/api/users/admin/check")

    if [[ "$status" == "404" ]]; then
        # Create admin user
        log_step "Creating admin user..."
        local resp
        resp=$(curl -sk -X POST "${PORTAINER_URL}/api/users/admin/init" \
            -H "Content-Type: application/json" \
            -d "{\"Username\":\"${username}\",\"Password\":\"${password}\"}")

        if echo "$resp" | jq -e '.Id' &>/dev/null; then
            log_info "Admin user created"
        else
            log_error "Failed to create admin user: $resp"
            exit 1
        fi
    else
        log_info "Admin user already exists"
    fi

    # Authenticate and get JWT
    log_step "Authenticating..."
    local auth_resp
    auth_resp=$(curl -sk -X POST "${PORTAINER_URL}/api/auth" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"${username}\",\"Password\":\"${password}\"}")

    local jwt
    jwt=$(echo "$auth_resp" | jq -r '.jwt // empty')

    if [[ -z "$jwt" ]]; then
        log_error "Authentication failed: $auth_resp"
        exit 1
    fi

    # Generate API key
    log_step "Generating API key..."
    local key_resp
    key_resp=$(curl -sk -X POST "${PORTAINER_URL}/api/users/1/tokens" \
        -H "Authorization: Bearer ${jwt}" \
        -H "Content-Type: application/json" \
        -d '{"description":"OpenClaw Portainer Manager"}')

    PORTAINER_API_KEY=$(echo "$key_resp" | jq -r '.rawAPIKey // empty')

    if [[ -z "$PORTAINER_API_KEY" ]]; then
        log_warn "Could not generate API key, using JWT token instead"
        PORTAINER_API_KEY="$jwt"
    fi

    PORTAINER_USERNAME="$username"
    ENDPOINT_ID=1
    save_config

    log_info "Portainer initialized!"
    echo "  Config saved to: ${CONFIG_FILE}"
    echo "  API URL: ${PORTAINER_URL}"
}

cmd_status() {
    load_config

    # Check container
    if ! docker ps --format '{{.Names}}' | grep -q "^${PORTAINER_CONTAINER}$"; then
        log_error "Portainer is not running"
        echo "  Start with: bash scripts/portainer.sh install"
        return 1
    fi

    # Get version
    local version
    version=$(api GET "/status" | jq -r '.Version // "unknown"')

    echo "Portainer CE v${version}"
    echo "Status: running"
    echo "URL: ${PORTAINER_URL}"

    if [[ -n "$PORTAINER_API_KEY" ]]; then
        # Get endpoint info
        local endpoints
        endpoints=$(api_auth GET "/endpoints" | jq 'length')
        echo "Endpoints: ${endpoints:-0}"

        # Get container summary
        local containers
        containers=$(api_auth GET "/endpoints/${ENDPOINT_ID}/docker/containers/json?all=true")
        local running stopped
        running=$(echo "$containers" | jq '[.[] | select(.State == "running")] | length')
        stopped=$(echo "$containers" | jq '[.[] | select(.State != "running")] | length')
        echo "Containers: ${running} running, ${stopped} stopped"

        # Get image count
        local images
        images=$(api_auth GET "/endpoints/${ENDPOINT_ID}/docker/images/json" | jq 'length')
        echo "Images: ${images}"

        # Get stack count
        local stacks
        stacks=$(api_auth GET "/stacks" | jq 'length' 2>/dev/null || echo "0")
        echo "Stacks: ${stacks}"
    else
        log_warn "Not authenticated — run: portainer.sh init --password <password>"
    fi
}

cmd_containers() {
    load_config
    local action="${1:-list}"
    shift || true

    case "$action" in
        list)
            local containers
            containers=$(api_auth GET "/endpoints/${ENDPOINT_ID}/docker/containers/json?all=true")
            printf "%-12s %-20s %-30s %-12s %s\n" "ID" "NAME" "IMAGE" "STATUS" "PORTS"
            echo "$containers" | jq -r '.[] | [
                .Id[:12],
                (.Names[0] // "" | ltrimstr("/")),
                (.Image // ""),
                (.State // ""),
                ([.Ports[]? | select(.PublicPort) | "\(.PublicPort)/\(.Type)"] | join(", "))
            ] | @tsv' | while IFS=$'\t' read -r id name image state ports; do
                printf "%-12s %-20s %-30s %-12s %s\n" "$id" "$name" "$image" "$state" "$ports"
            done
            ;;
        stop|start|restart)
            local name="$1"
            if [[ -z "$name" ]]; then
                log_error "Container name required"
                exit 1
            fi
            # Find container ID by name
            local cid
            cid=$(api_auth GET "/endpoints/${ENDPOINT_ID}/docker/containers/json?all=true" | \
                jq -r ".[] | select(.Names[] | test(\"/${name}$\")) | .Id")
            if [[ -z "$cid" ]]; then
                log_error "Container '${name}' not found"
                exit 1
            fi
            api_auth POST "/endpoints/${ENDPOINT_ID}/docker/containers/${cid}/${action}" > /dev/null
            log_info "Container '${name}' ${action}ed"
            ;;
        logs)
            local name="$1"; shift || true
            local tail="100"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --tail) tail="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            local cid
            cid=$(api_auth GET "/endpoints/${ENDPOINT_ID}/docker/containers/json?all=true" | \
                jq -r ".[] | select(.Names[] | test(\"/${name}$\")) | .Id")
            if [[ -z "$cid" ]]; then
                log_error "Container '${name}' not found"
                exit 1
            fi
            api_auth GET "/endpoints/${ENDPOINT_ID}/docker/containers/${cid}/logs?stdout=true&stderr=true&tail=${tail}"
            echo ""
            ;;
        inspect)
            local name="$1"
            local cid
            cid=$(api_auth GET "/endpoints/${ENDPOINT_ID}/docker/containers/json?all=true" | \
                jq -r ".[] | select(.Names[] | test(\"/${name}$\")) | .Id")
            if [[ -z "$cid" ]]; then
                log_error "Container '${name}' not found"
                exit 1
            fi
            api_auth GET "/endpoints/${ENDPOINT_ID}/docker/containers/${cid}/json" | jq '{
                Name: .Name,
                Image: .Config.Image,
                State: .State.Status,
                Started: .State.StartedAt,
                RestartCount: .RestartCount,
                Ports: [.NetworkSettings.Ports | to_entries[] | select(.value) | "\(.key) -> \(.value[0].HostPort)"],
                Mounts: [.Mounts[] | "\(.Type): \(.Source) -> \(.Destination)"],
                Env: [.Config.Env[] | select(startswith("PATH") | not)]
            }'
            ;;
        *)
            log_error "Unknown containers action: ${action}"
            echo "Usage: portainer.sh containers [list|stop|start|restart|logs|inspect] [name]"
            ;;
    esac
}

cmd_stacks() {
    load_config
    local action="${1:-list}"
    shift || true

    case "$action" in
        list)
            local stacks
            stacks=$(api_auth GET "/stacks")
            printf "%-5s %-20s %-10s %s\n" "ID" "NAME" "STATUS" "TYPE"
            echo "$stacks" | jq -r '.[] | [
                (.Id | tostring),
                .Name,
                (if .Status == 1 then "active" else "inactive" end),
                (if .Type == 1 then "swarm" elif .Type == 2 then "compose" else "unknown" end)
            ] | @tsv' | while IFS=$'\t' read -r id name status type; do
                printf "%-5s %-20s %-10s %s\n" "$id" "$name" "$status" "$type"
            done
            ;;
        deploy)
            local name="" file="" git_url="" git_ref="main" compose_path="docker-compose.yml"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name) name="$2"; shift 2 ;;
                    --file) file="$2"; shift 2 ;;
                    --git-url) git_url="$2"; shift 2 ;;
                    --git-ref) git_ref="$2"; shift 2 ;;
                    --compose-path) compose_path="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            if [[ -z "$name" ]]; then
                log_error "Stack name required: --name <name>"
                exit 1
            fi
            if [[ -n "$file" ]]; then
                # File-based deploy
                if [[ ! -f "$file" ]]; then
                    log_error "File not found: ${file}"
                    exit 1
                fi
                local content
                content=$(cat "$file")
                log_step "Deploying stack '${name}' from ${file}..."
                local resp
                resp=$(api_auth POST "/stacks/create/standalone/string?endpointId=${ENDPOINT_ID}" \
                    -H "Content-Type: application/json" \
                    -d "$(jq -n --arg name "$name" --arg content "$content" \
                        '{Name: $name, StackFileContent: $content}')")
                if echo "$resp" | jq -e '.Id' &>/dev/null; then
                    log_info "Stack '${name}' deployed (ID: $(echo "$resp" | jq '.Id'))"
                else
                    log_error "Deploy failed: $(echo "$resp" | jq -r '.message // .details // .')"
                fi
            elif [[ -n "$git_url" ]]; then
                # Git-based deploy
                log_step "Deploying stack '${name}' from ${git_url}..."
                local resp
                resp=$(api_auth POST "/stacks/create/standalone/repository?endpointId=${ENDPOINT_ID}" \
                    -H "Content-Type: application/json" \
                    -d "$(jq -n --arg name "$name" --arg url "$git_url" \
                        --arg ref "$git_ref" --arg path "$compose_path" \
                        '{Name: $name, RepositoryURL: $url, RepositoryReferenceName: ("refs/heads/" + $ref), ComposeFile: $path}')")
                if echo "$resp" | jq -e '.Id' &>/dev/null; then
                    log_info "Stack '${name}' deployed from git"
                else
                    log_error "Deploy failed: $(echo "$resp" | jq -r '.message // .details // .')"
                fi
            else
                log_error "Provide --file <compose.yml> or --git-url <repo>"
                exit 1
            fi
            ;;
        update)
            local name="" file=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name) name="$2"; shift 2 ;;
                    --file) file="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            if [[ -z "$name" || -z "$file" ]]; then
                log_error "Required: --name <stack-name> --file <compose.yml>"
                exit 1
            fi
            local stack_id
            stack_id=$(api_auth GET "/stacks" | jq -r ".[] | select(.Name == \"${name}\") | .Id")
            if [[ -z "$stack_id" ]]; then
                log_error "Stack '${name}' not found"
                exit 1
            fi
            local content env_vars
            content=$(cat "$file")
            env_vars=$(api_auth GET "/stacks/${stack_id}" | jq '.Env // []')
            log_step "Updating stack '${name}'..."
            api_auth PUT "/stacks/${stack_id}?endpointId=${ENDPOINT_ID}" \
                -H "Content-Type: application/json" \
                -d "$(jq -n --arg content "$content" --argjson env "$env_vars" \
                    '{StackFileContent: $content, Env: $env, Prune: true}')" > /dev/null
            log_info "Stack '${name}' updated"
            ;;
        remove)
            local name=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name) name="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            local stack_id
            stack_id=$(api_auth GET "/stacks" | jq -r ".[] | select(.Name == \"${name}\") | .Id")
            if [[ -z "$stack_id" ]]; then
                log_error "Stack '${name}' not found"
                exit 1
            fi
            api_auth DELETE "/stacks/${stack_id}?endpointId=${ENDPOINT_ID}" > /dev/null
            log_info "Stack '${name}' removed"
            ;;
        webhook)
            local name=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name) name="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            local stack_id
            stack_id=$(api_auth GET "/stacks" | jq -r ".[] | select(.Name == \"${name}\") | .Id")
            if [[ -z "$stack_id" ]]; then
                log_error "Stack '${name}' not found"
                exit 1
            fi
            local resp
            resp=$(api_auth POST "/webhooks" \
                -H "Content-Type: application/json" \
                -d "{\"ResourceID\":\"${stack_id}\",\"WebhookType\":1}")
            local token
            token=$(echo "$resp" | jq -r '.Token // empty')
            if [[ -n "$token" ]]; then
                echo "Webhook URL: ${PORTAINER_URL}/api/stacks/webhooks/${token}"
                echo "Trigger: curl -X POST ${PORTAINER_URL}/api/stacks/webhooks/${token}"
            else
                log_error "Failed to create webhook: $resp"
            fi
            ;;
        *)
            log_error "Unknown stacks action: ${action}"
            echo "Usage: portainer.sh stacks [list|deploy|update|remove|webhook]"
            ;;
    esac
}

cmd_images() {
    load_config
    local action="${1:-list}"
    shift || true

    case "$action" in
        list)
            api_auth GET "/endpoints/${ENDPOINT_ID}/docker/images/json" | \
                jq -r '.[] | [
                    (.RepoTags[0] // "<none>"),
                    (.Id[:19]),
                    ((.Size / 1048576 | floor | tostring) + "MB"),
                    (.Created | strftime("%Y-%m-%d"))
                ] | @tsv' | sort | \
                while IFS=$'\t' read -r tag id size created; do
                    printf "%-40s %-19s %-10s %s\n" "$tag" "$id" "$size" "$created"
                done
            ;;
        pull)
            local image="${1:-}"
            if [[ -z "$image" ]]; then
                log_error "Image name required"
                exit 1
            fi
            log_step "Pulling ${image}..."
            local tag="latest"
            local repo="$image"
            if [[ "$image" == *":"* ]]; then
                repo="${image%%:*}"
                tag="${image##*:}"
            fi
            api_auth POST "/endpoints/${ENDPOINT_ID}/docker/images/create?fromImage=${repo}&tag=${tag}" > /dev/null
            log_info "Pulled ${image}"
            ;;
        prune)
            log_step "Pruning unused images..."
            local resp
            resp=$(api_auth POST "/endpoints/${ENDPOINT_ID}/docker/images/prune")
            local count space
            count=$(echo "$resp" | jq '.ImagesDeleted | length // 0')
            space=$(echo "$resp" | jq '(.SpaceReclaimed // 0) / 1048576 | floor')
            log_info "Removed ${count} unused images, reclaimed ${space}MB"
            ;;
        *)
            log_error "Unknown images action: ${action}"
            echo "Usage: portainer.sh images [list|pull|prune]"
            ;;
    esac
}

cmd_stats() {
    load_config
    printf "%-20s %-8s %-22s %-8s %s\n" "NAME" "CPU%" "MEM USAGE / LIMIT" "MEM%" "NET I/O"
    local containers
    containers=$(api_auth GET "/endpoints/${ENDPOINT_ID}/docker/containers/json")
    echo "$containers" | jq -r '.[].Id' | while read -r cid; do
        local name
        name=$(echo "$containers" | jq -r ".[] | select(.Id == \"${cid}\") | .Names[0] | ltrimstr(\"/\")")
        local stats
        stats=$(api_auth GET "/endpoints/${ENDPOINT_ID}/docker/containers/${cid}/stats?stream=false" 2>/dev/null || echo "{}")
        
        local cpu_pct mem_usage mem_limit mem_pct net_in net_out
        cpu_pct=$(echo "$stats" | jq '
            ((.cpu_stats.cpu_usage.total_usage - .precpu_stats.cpu_usage.total_usage) /
            (.cpu_stats.system_cpu_usage - .precpu_stats.system_cpu_usage) *
            (.cpu_stats.online_cpus // 1) * 100) | . * 100 | floor / 100
        ' 2>/dev/null || echo "0")
        mem_usage=$(echo "$stats" | jq '(.memory_stats.usage // 0) / 1048576 | floor' 2>/dev/null || echo "0")
        mem_limit=$(echo "$stats" | jq '(.memory_stats.limit // 0) / 1073741824 | . * 10 | floor / 10' 2>/dev/null || echo "0")
        mem_pct=$(echo "$stats" | jq '((.memory_stats.usage // 0) / (.memory_stats.limit // 1) * 100) | . * 100 | floor / 100' 2>/dev/null || echo "0")
        net_in=$(echo "$stats" | jq '[.networks // {} | to_entries[] | .value.rx_bytes] | add // 0 | . / 1048576 | floor' 2>/dev/null || echo "0")
        net_out=$(echo "$stats" | jq '[.networks // {} | to_entries[] | .value.tx_bytes] | add // 0 | . / 1048576 | floor' 2>/dev/null || echo "0")

        printf "%-20s %-8s %-22s %-8s %s\n" \
            "$name" "${cpu_pct}%" "${mem_usage}MB / ${mem_limit}GB" "${mem_pct}%" "${net_in}MB / ${net_out}MB"
    done
}

cmd_volumes() {
    load_config
    local action="${1:-list}"
    shift || true

    case "$action" in
        list)
            api_auth GET "/endpoints/${ENDPOINT_ID}/docker/volumes" | \
                jq -r '.Volumes[] | [.Name, .Driver, .Mountpoint] | @tsv' | \
                while IFS=$'\t' read -r name driver mount; do
                    printf "%-30s %-10s %s\n" "$name" "$driver" "$mount"
                done
            ;;
        create)
            local name=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name) name="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            api_auth POST "/endpoints/${ENDPOINT_ID}/docker/volumes/create" \
                -H "Content-Type: application/json" \
                -d "{\"Name\":\"${name}\"}" > /dev/null
            log_info "Volume '${name}' created"
            ;;
        *)
            echo "Usage: portainer.sh volumes [list|create]"
            ;;
    esac
}

cmd_networks() {
    load_config
    local action="${1:-list}"
    shift || true

    case "$action" in
        list)
            api_auth GET "/endpoints/${ENDPOINT_ID}/docker/networks" | \
                jq -r '.[] | [.Name, .Driver, .Scope, .Id[:12]] | @tsv' | \
                while IFS=$'\t' read -r name driver scope id; do
                    printf "%-25s %-10s %-8s %s\n" "$name" "$driver" "$scope" "$id"
                done
            ;;
        create)
            local name="" driver="bridge"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name) name="$2"; shift 2 ;;
                    --driver) driver="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            api_auth POST "/endpoints/${ENDPOINT_ID}/docker/networks/create" \
                -H "Content-Type: application/json" \
                -d "{\"Name\":\"${name}\",\"Driver\":\"${driver}\"}" > /dev/null
            log_info "Network '${name}' created (driver: ${driver})"
            ;;
        *)
            echo "Usage: portainer.sh networks [list|create]"
            ;;
    esac
}

cmd_users() {
    load_config
    local action="${1:-list}"
    shift || true

    case "$action" in
        list)
            api_auth GET "/users" | jq -r '.[] | [
                (.Id | tostring),
                .Username,
                (if .Role == 1 then "admin" else "standard" end)
            ] | @tsv' | while IFS=$'\t' read -r id user role; do
                printf "%-5s %-20s %s\n" "$id" "$user" "$role"
            done
            ;;
        create)
            local username="" password="" role="2"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --username) username="$2"; shift 2 ;;
                    --password) password="$2"; shift 2 ;;
                    --role) [[ "$2" == "admin" ]] && role=1 || role=2; shift 2 ;;
                    *) shift ;;
                esac
            done
            api_auth POST "/users" \
                -H "Content-Type: application/json" \
                -d "{\"Username\":\"${username}\",\"Password\":\"${password}\",\"Role\":${role}}" > /dev/null
            log_info "User '${username}' created"
            ;;
        remove)
            local username=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --username) username="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            local uid
            uid=$(api_auth GET "/users" | jq -r ".[] | select(.Username == \"${username}\") | .Id")
            if [[ -z "$uid" ]]; then
                log_error "User '${username}' not found"
                exit 1
            fi
            api_auth DELETE "/users/${uid}" > /dev/null
            log_info "User '${username}' removed"
            ;;
        *)
            echo "Usage: portainer.sh users [list|create|remove]"
            ;;
    esac
}

cmd_endpoints() {
    load_config
    local action="${1:-list}"
    shift || true

    case "$action" in
        list)
            api_auth GET "/endpoints" | jq -r '.[] | [
                (.Id | tostring),
                .Name,
                .URL,
                (if .Status == 1 then "up" else "down" end)
            ] | @tsv' | while IFS=$'\t' read -r id name url status; do
                printf "%-5s %-20s %-30s %s\n" "$id" "$name" "$url" "$status"
            done
            ;;
        add)
            local name="" url=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --name) name="$2"; shift 2 ;;
                    --url) url="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            api_auth POST "/endpoints" \
                -H "Content-Type: application/json" \
                -d "{\"Name\":\"${name}\",\"URL\":\"${url}\",\"EndpointCreationType\":1}" > /dev/null
            log_info "Endpoint '${name}' added"
            ;;
        *)
            echo "Usage: portainer.sh endpoints [list|add]"
            ;;
    esac
}

cmd_backup() {
    load_config
    local output="portainer-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output) output="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    log_step "Backing up Portainer data..."
    docker run --rm \
        -v "${PORTAINER_VOLUME}:/data:ro" \
        -v "$(dirname "$(realpath "$output")"):/backup" \
        alpine tar czf "/backup/$(basename "$output")" -C /data .

    log_info "Backup saved to: ${output}"
    ls -lh "$output"
}

cmd_restore() {
    local file=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file) file="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$file" || ! -f "$file" ]]; then
        log_error "Backup file required: --file <path>"
        exit 1
    fi

    log_warn "This will stop Portainer and replace all data. Continue? (y/N)"
    read -r confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0

    log_step "Stopping Portainer..."
    docker stop "$PORTAINER_CONTAINER" 2>/dev/null || true

    log_step "Restoring data..."
    docker run --rm \
        -v "${PORTAINER_VOLUME}:/data" \
        -v "$(dirname "$(realpath "$file")"):/backup:ro" \
        alpine sh -c "rm -rf /data/* && tar xzf /backup/$(basename "$file") -C /data"

    docker start "$PORTAINER_CONTAINER"
    log_info "Restore complete, Portainer restarted"
}

cmd_token() {
    load_config
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --refresh)
                log_step "Refreshing API token..."
                # Need to re-auth with password
                log_error "Re-run: portainer.sh init --password <your-password>"
                ;;
            *) shift ;;
        esac
    done
}

cmd_uninstall() {
    log_warn "Remove Portainer? This will delete the container and image."
    echo "  Keep data volume? Pass --keep-data to preserve it."
    
    local keep_data=false
    for arg in "$@"; do
        [[ "$arg" == "--keep-data" ]] && keep_data=true
    done

    docker stop "$PORTAINER_CONTAINER" 2>/dev/null || true
    docker rm "$PORTAINER_CONTAINER" 2>/dev/null || true
    docker rmi "$PORTAINER_IMAGE" 2>/dev/null || true

    if [[ "$keep_data" == false ]]; then
        docker volume rm "$PORTAINER_VOLUME" 2>/dev/null || true
        log_info "Data volume removed"
    else
        log_info "Data volume preserved: ${PORTAINER_VOLUME}"
    fi

    rm -f "$CONFIG_FILE"
    log_info "Portainer uninstalled"
}

cmd_help() {
    echo "Portainer Manager — Manage Portainer CE from the command line"
    echo ""
    echo "Usage: portainer.sh <command> [options]"
    echo ""
    echo "Setup:"
    echo "  install                Install Portainer CE container"
    echo "  init --password <pwd>  Initialize admin account & API key"
    echo "  status                 Show Portainer status & summary"
    echo "  uninstall              Remove Portainer"
    echo ""
    echo "Containers:"
    echo "  containers list        List all containers"
    echo "  containers stop <n>    Stop a container"
    echo "  containers start <n>   Start a container"
    echo "  containers restart <n> Restart a container"
    echo "  containers logs <n>    View container logs"
    echo "  containers inspect <n> Inspect container details"
    echo ""
    echo "Stacks:"
    echo "  stacks list            List stacks"
    echo "  stacks deploy          Deploy from file or git"
    echo "  stacks update          Update a stack"
    echo "  stacks remove          Remove a stack"
    echo "  stacks webhook         Create auto-deploy webhook"
    echo ""
    echo "Resources:"
    echo "  images list|pull|prune Manage images"
    echo "  volumes list|create    Manage volumes"
    echo "  networks list|create   Manage networks"
    echo "  stats                  Container resource usage"
    echo ""
    echo "Admin:"
    echo "  users list|create|remove  Manage users"
    echo "  endpoints list|add        Manage Docker endpoints"
    echo "  backup --output <file>    Backup Portainer data"
    echo "  restore --file <file>     Restore from backup"
}

# Main router
load_config

case "${1:-help}" in
    install)    shift; cmd_install "$@" ;;
    init)       shift; cmd_init "$@" ;;
    status)     shift; cmd_status "$@" ;;
    containers) shift; cmd_containers "$@" ;;
    stacks)     shift; cmd_stacks "$@" ;;
    images)     shift; cmd_images "$@" ;;
    stats)      shift; cmd_stats "$@" ;;
    volumes)    shift; cmd_volumes "$@" ;;
    networks)   shift; cmd_networks "$@" ;;
    users)      shift; cmd_users "$@" ;;
    endpoints)  shift; cmd_endpoints "$@" ;;
    backup)     shift; cmd_backup "$@" ;;
    restore)    shift; cmd_restore "$@" ;;
    token)      shift; cmd_token "$@" ;;
    uninstall)  shift; cmd_uninstall "$@" ;;
    help|--help|-h) cmd_help ;;
    *)          log_error "Unknown command: $1"; cmd_help; exit 1 ;;
esac
