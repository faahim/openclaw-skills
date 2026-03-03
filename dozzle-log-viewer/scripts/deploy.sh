#!/bin/bash
# Dozzle Log Viewer — Deploy Script
set -euo pipefail

# Defaults
PORT="${DOZZLE_PORT:-8080}"
LEVEL="${DOZZLE_LEVEL:-info}"
BASE="${DOZZLE_BASE:-}"
FILTER="${DOZZLE_FILTER:-}"
HOSTNAME_LABEL="${DOZZLE_HOSTNAME:-$(hostname)}"
NO_ANALYTICS="${DOZZLE_NO_ANALYTICS:-true}"
CONTAINER_NAME="dozzle"
IMAGE="amir20/dozzle:latest"
AUTH=""
AUTH_USER=""
AUTH_PASS=""
AUTH_FILE=""
AGENTS_FILE=""
SWARM=false
COMPOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --level) LEVEL="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    --hostname) HOSTNAME_LABEL="$2"; shift 2 ;;
    --auth) AUTH=true; shift ;;
    --user) AUTH_USER="$2"; shift 2 ;;
    --password) AUTH_PASS="$2"; shift 2 ;;
    --auth-file) AUTH_FILE="$2"; shift 2 ;;
    --agents) AGENTS_FILE="$2"; shift 2 ;;
    --swarm) SWARM=true; shift ;;
    --compose) COMPOSE=true; shift ;;
    --name) CONTAINER_NAME="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check Docker
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker is not running. Please start Docker first."
  exit 1
fi

echo "🚀 Deploying Dozzle Log Viewer..."

# Pull latest image
echo "📦 Pulling latest Dozzle image..."
docker pull "$IMAGE" --quiet

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "🔄 Stopping existing Dozzle container..."
  docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
  docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
fi

# Build docker run command
DOCKER_ARGS=(
  "docker" "run" "-d"
  "--name" "$CONTAINER_NAME"
  "--restart" "unless-stopped"
  "-p" "${PORT}:8080"
  "-v" "/var/run/docker.sock:/var/run/docker.sock:ro"
  "-e" "DOZZLE_LEVEL=${LEVEL}"
  "-e" "DOZZLE_NO_ANALYTICS=${NO_ANALYTICS}"
  "-e" "DOZZLE_HOSTNAME=${HOSTNAME_LABEL}"
)

# Optional: base path
if [[ -n "$BASE" ]]; then
  DOCKER_ARGS+=("-e" "DOZZLE_BASE=${BASE}")
fi

# Optional: filter
if [[ -n "$FILTER" ]]; then
  DOCKER_ARGS+=("-e" "DOZZLE_FILTER=${FILTER}")
fi

# Optional: auth with users file
if [[ -n "$AUTH_FILE" ]]; then
  DOCKER_ARGS+=("-v" "${AUTH_FILE}:/data/users.yml:ro")
fi

# Optional: auth via generate command
if [[ "$AUTH" == "true" && -n "$AUTH_USER" && -n "$AUTH_PASS" ]]; then
  echo "🔐 Setting up authentication..."
  mkdir -p /tmp/dozzle-auth
  docker run --rm "$IMAGE" generate "$AUTH_USER" --password "$AUTH_PASS" > /tmp/dozzle-auth/users.yml
  DOCKER_ARGS+=("-v" "/tmp/dozzle-auth/users.yml:/data/users.yml:ro")
fi

# Optional: remote agents
if [[ -n "$AGENTS_FILE" ]]; then
  DOCKER_ARGS+=("-v" "${AGENTS_FILE}:/data/agents.yml:ro")
fi

# Optional: swarm mode
if [[ "$SWARM" == "true" ]]; then
  DOCKER_ARGS+=("-e" "DOZZLE_MODE=swarm")
fi

# Add image
DOCKER_ARGS+=("$IMAGE")

# Run
"${DOCKER_ARGS[@]}" > /dev/null

# Wait for health
sleep 2
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
  echo ""
  echo "✅ Dozzle is running!"
  echo "   🌐 URL: http://${LOCAL_IP}:${PORT}${BASE}"
  echo "   📋 Container: ${CONTAINER_NAME}"
  echo "   📊 Log level: ${LEVEL}"
  [[ "$AUTH" == "true" || -n "$AUTH_FILE" ]] && echo "   🔐 Authentication: enabled"
  [[ -n "$FILTER" ]] && echo "   🔍 Filter: ${FILTER}"
  echo ""
  echo "   View Dozzle logs: docker logs ${CONTAINER_NAME} -f"
else
  echo "❌ Dozzle failed to start. Check: docker logs ${CONTAINER_NAME}"
  exit 1
fi
