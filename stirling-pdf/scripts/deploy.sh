#!/bin/bash
# Stirling PDF Server — Deploy & Manage
# Usage: bash deploy.sh [--port PORT] [--ocr] [--auth --user USER --pass PASS]
#        bash deploy.sh [--status|--stop|--start|--restart|--update|--remove]

set -e

CONTAINER_NAME="stirling-pdf"
DEFAULT_PORT=8080
DEFAULT_DATA="/opt/stirling-pdf"
IMAGE_STANDARD="frooodle/s-pdf:latest"
IMAGE_OCR="frooodle/s-pdf:latest-ultra-lite"
IMAGE_FULL="frooodle/s-pdf:latest"

# Parse arguments
PORT="$DEFAULT_PORT"
DATA_DIR="$DEFAULT_DATA"
OCR=false
AUTH=false
AUTH_USER=""
AUTH_PASS=""
ACTION="deploy"
LANG="en_GB"

while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --data) DATA_DIR="$2"; shift 2 ;;
    --ocr) OCR=true; shift ;;
    --auth) AUTH=true; shift ;;
    --user) AUTH_USER="$2"; shift 2 ;;
    --pass) AUTH_PASS="$2"; shift 2 ;;
    --lang) LANG="$2"; shift 2 ;;
    --status) ACTION="status"; shift ;;
    --stop) ACTION="stop"; shift ;;
    --start) ACTION="start"; shift ;;
    --restart) ACTION="restart"; shift ;;
    --update) ACTION="update"; shift ;;
    --remove) ACTION="remove"; shift ;;
    --logs) ACTION="logs"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Select image
if [ "$OCR" = true ]; then
  IMAGE="$IMAGE_FULL"
else
  IMAGE="$IMAGE_STANDARD"
fi

case "$ACTION" in
  status)
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      echo "✅ Stirling PDF is running"
      docker ps --filter "name=${CONTAINER_NAME}" --format "  Container: {{.Names}}\n  Image: {{.Image}}\n  Port: {{.Ports}}\n  Status: {{.Status}}\n  Created: {{.CreatedAt}}"
      echo ""
      # Health check
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/" 2>/dev/null || echo "000")
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        echo "  Health: ✅ Responding (HTTP $HTTP_CODE)"
      else
        echo "  Health: ⚠️ Not responding (HTTP $HTTP_CODE)"
      fi
    else
      echo "❌ Stirling PDF is not running"
      if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "  Container exists but is stopped. Run: bash deploy.sh --start"
      fi
    fi
    ;;

  stop)
    echo "Stopping Stirling PDF..."
    docker stop "$CONTAINER_NAME" 2>/dev/null && echo "✅ Stopped" || echo "⚠️ Container not running"
    ;;

  start)
    echo "Starting Stirling PDF..."
    docker start "$CONTAINER_NAME" 2>/dev/null && echo "✅ Started" || echo "❌ Container not found. Run deploy first."
    ;;

  restart)
    echo "Restarting Stirling PDF..."
    docker restart "$CONTAINER_NAME" 2>/dev/null && echo "✅ Restarted" || echo "❌ Container not found"
    ;;

  update)
    echo "Updating Stirling PDF..."
    # Get current image
    CURRENT_IMAGE=$(docker inspect "$CONTAINER_NAME" --format '{{.Config.Image}}' 2>/dev/null || echo "")
    if [ -z "$CURRENT_IMAGE" ]; then
      echo "❌ Container not found. Run deploy first."
      exit 1
    fi

    echo "  Pulling latest image..."
    docker pull "$CURRENT_IMAGE"

    echo "  Recreating container..."
    # Save current config
    CURRENT_PORT=$(docker port "$CONTAINER_NAME" 8080 2>/dev/null | cut -d: -f2 || echo "$DEFAULT_PORT")
    docker stop "$CONTAINER_NAME" 2>/dev/null
    docker rm "$CONTAINER_NAME" 2>/dev/null

    # Redeploy with same settings
    PORT="$CURRENT_PORT" IMAGE="$CURRENT_IMAGE"
    ;& # Fall through to deploy

  deploy)
    # Check Docker
    if ! command -v docker &> /dev/null; then
      echo "❌ Docker is not installed."
      echo "Install: https://docs.docker.com/engine/install/"
      exit 1
    fi

    # Check if already running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      echo "⚠️ Stirling PDF already running on port $(docker port $CONTAINER_NAME 8080 2>/dev/null | cut -d: -f2)"
      echo "Use --restart to restart, --update to update, or --remove to remove first."
      exit 0
    fi

    # Remove stopped container if exists
    docker rm "$CONTAINER_NAME" 2>/dev/null || true

    # Create data directory
    sudo mkdir -p "$DATA_DIR/configs" "$DATA_DIR/logs" "$DATA_DIR/customFiles" "$DATA_DIR/training-data"

    echo "🚀 Deploying Stirling PDF..."
    echo "  Image: $IMAGE"
    echo "  Port: $PORT"
    echo "  Data: $DATA_DIR"
    echo "  OCR: $OCR"

    # Build environment variables
    ENV_ARGS="-e DOCKER_ENABLE_SECURITY=false -e LANGS=$LANG"

    if [ "$AUTH" = true ]; then
      ENV_ARGS="-e DOCKER_ENABLE_SECURITY=true -e SECURITY_ENABLELOGIN=true"
      if [ -n "$AUTH_USER" ]; then
        ENV_ARGS="$ENV_ARGS -e INITIAL_ADMIN_USERNAME=$AUTH_USER"
      fi
      if [ -n "$AUTH_PASS" ]; then
        ENV_ARGS="$ENV_ARGS -e INITIAL_ADMIN_PASSWORD=$AUTH_PASS"
      fi
      echo "  Auth: Enabled (user: ${AUTH_USER:-admin})"
    fi

    # Deploy
    docker run -d \
      --name "$CONTAINER_NAME" \
      --restart unless-stopped \
      -p "${PORT}:8080" \
      -v "${DATA_DIR}/configs:/configs" \
      -v "${DATA_DIR}/logs:/logs" \
      -v "${DATA_DIR}/customFiles:/customFiles" \
      -v "${DATA_DIR}/training-data:/usr/share/tessdata" \
      $ENV_ARGS \
      "$IMAGE"

    echo ""
    echo "⏳ Waiting for startup..."
    for i in $(seq 1 30); do
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/" 2>/dev/null || echo "000")
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        echo "✅ Stirling PDF is ready!"
        echo ""
        echo "  🌐 Web UI: http://localhost:${PORT}"
        echo "  📚 API Docs: http://localhost:${PORT}/swagger-ui/index.html"
        echo "  📁 Data: $DATA_DIR"
        exit 0
      fi
      sleep 2
    done

    echo "⚠️ Container started but may still be initializing."
    echo "  Check logs: docker logs $CONTAINER_NAME"
    echo "  Web UI: http://localhost:${PORT}"
    ;;

  remove)
    echo "Removing Stirling PDF..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    echo "✅ Container removed"
    echo "  Data preserved at: $DATA_DIR"
    echo "  To remove data: sudo rm -rf $DATA_DIR"
    ;;

  logs)
    docker logs "$CONTAINER_NAME" --tail 100
    ;;

  *)
    echo "Unknown action: $ACTION"
    exit 1
    ;;
esac
