#!/bin/bash
# Gotenberg PDF API — Start server
set -e

PORT="${GOTENBERG_PORT:-3000}"
CONTAINER="${GOTENBERG_CONTAINER:-gotenberg}"
TIMEOUT="${GOTENBERG_TIMEOUT:-30s}"
MEMORY=""
CPUS=""
IMAGE="gotenberg/gotenberg:8"

while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --memory) MEMORY="$2"; shift 2 ;;
    --cpus) CPUS="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "❌ Docker is required. Install it:"
  echo "   curl -fsSL https://get.docker.com | sh"
  exit 1
fi

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "🔄 Stopping existing Gotenberg container..."
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
fi

echo "🚀 Starting Gotenberg PDF API on port $PORT..."

DOCKER_ARGS=(
  "run" "-d"
  "--name" "$CONTAINER"
  "-p" "${PORT}:3000"
  "--restart" "unless-stopped"
)

[[ -n "$MEMORY" ]] && DOCKER_ARGS+=("--memory" "$MEMORY")
[[ -n "$CPUS" ]] && DOCKER_ARGS+=("--cpus" "$CPUS")

DOCKER_ARGS+=("$IMAGE" "gotenberg" "--api-timeout=${TIMEOUT}")

docker "${DOCKER_ARGS[@]}"

# Wait for health
echo "⏳ Waiting for server to be ready..."
for i in $(seq 1 30); do
  if curl -sf "http://localhost:${PORT}/health" >/dev/null 2>&1; then
    echo ""
    echo "✅ Gotenberg is running!"
    echo "   URL: http://localhost:${PORT}"
    echo "   Health: http://localhost:${PORT}/health"
    echo "   Container: $CONTAINER"
    echo ""
    echo "   Try it:"
    echo "   echo '<h1>Hello PDF</h1>' > /tmp/test.html"
    echo "   curl -f -X POST http://localhost:${PORT}/forms/chromium/convert/html -F files=@/tmp/test.html -o test.pdf"
    exit 0
  fi
  printf "."
  sleep 1
done

echo ""
echo "⚠️  Server started but health check timed out. Check logs:"
echo "   docker logs $CONTAINER"
