#!/bin/bash
# Self-host a tmate server using Docker
set -e

ACTION="${1:-help}"
CONTAINER_NAME="tmate-server"
TMATE_PORT="${TMATE_PORT:-2222}"

case "$ACTION" in
    setup)
        echo "🐳 Setting up self-hosted tmate server..."

        if ! command -v docker &>/dev/null; then
            echo "❌ Docker is required. Install Docker first."
            exit 1
        fi

        # Pull and run tmate server
        docker run -d \
            --name "$CONTAINER_NAME" \
            --restart unless-stopped \
            -p "${TMATE_PORT}:2222" \
            -v tmate-keys:/etc/tmate-ssh-server-keys \
            tmate/tmate-ssh-server

        echo "⏳ Waiting for server to start..."
        sleep 5

        # Get server fingerprints
        echo ""
        echo "✅ tmate server running on port ${TMATE_PORT}"
        echo ""
        echo "Server fingerprints (add to ~/.tmate.conf):"

        RSA_FP=$(docker exec "$CONTAINER_NAME" ssh-keygen -lf /etc/tmate-ssh-server-keys/ssh_host_rsa_key.pub 2>/dev/null | awk '{print $2}')
        ED25519_FP=$(docker exec "$CONTAINER_NAME" ssh-keygen -lf /etc/tmate-ssh-server-keys/ssh_host_ed25519_key.pub 2>/dev/null | awk '{print $2}')

        HOST_IP=$(hostname -I | awk '{print $1}')

        echo ""
        echo "Add to ~/.tmate.conf:"
        echo '---'
        echo "set -g tmate-server-host \"${HOST_IP}\""
        echo "set -g tmate-server-port ${TMATE_PORT}"
        echo "set -g tmate-server-rsa-fingerprint \"${RSA_FP}\""
        echo "set -g tmate-server-ed25519-fingerprint \"${ED25519_FP}\""
        echo '---'
        ;;

    stop)
        echo "🛑 Stopping tmate server..."
        docker stop "$CONTAINER_NAME" 2>/dev/null && docker rm "$CONTAINER_NAME" 2>/dev/null
        echo "✅ Server stopped and removed"
        ;;

    status)
        if docker ps --filter "name=$CONTAINER_NAME" --format '{{.Status}}' | grep -q .; then
            echo "✅ tmate server is running"
            docker ps --filter "name=$CONTAINER_NAME" --format "  Container: {{.Names}}  Status: {{.Status}}  Ports: {{.Ports}}"
        else
            echo "❌ tmate server is not running"
        fi
        ;;

    logs)
        docker logs "$CONTAINER_NAME" --tail 50
        ;;

    help|*)
        echo "tmate Self-Hosted Server Manager"
        echo ""
        echo "Usage: bash self-host.sh <action>"
        echo ""
        echo "Actions:"
        echo "  setup   Install and start tmate server (Docker)"
        echo "  stop    Stop and remove the server"
        echo "  status  Check if server is running"
        echo "  logs    View server logs"
        ;;
esac
