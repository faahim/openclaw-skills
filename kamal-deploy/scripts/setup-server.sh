#!/bin/bash
# Kamal Deploy Manager — Remote Server Setup Helper
# Prepares a fresh VPS for Kamal deployments

set -e

SERVER_IP="${1:-}"
SSH_USER="${2:-root}"

if [ -z "$SERVER_IP" ]; then
    echo "Usage: bash setup-server.sh <server-ip> [ssh-user]"
    echo ""
    echo "Examples:"
    echo "  bash setup-server.sh 123.45.67.89"
    echo "  bash setup-server.sh 123.45.67.89 deploy"
    exit 1
fi

echo "=== Kamal Server Setup: $SSH_USER@$SERVER_IP ==="
echo ""

# Test SSH connection
echo "Testing SSH connection..."
if ssh -o ConnectTimeout=10 "$SSH_USER@$SERVER_IP" "echo 'SSH OK'" 2>/dev/null; then
    echo "✅ SSH connection successful"
else
    echo "❌ Cannot connect to $SSH_USER@$SERVER_IP"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check server IP is correct"
    echo "  2. Ensure SSH key is added: ssh-add ~/.ssh/id_ed25519"
    echo "  3. Check firewall allows port 22"
    echo "  4. Try: ssh -v $SSH_USER@$SERVER_IP"
    exit 1
fi
echo ""

# Check if Docker is already installed
echo "Checking Docker on server..."
DOCKER_INSTALLED=$(ssh "$SSH_USER@$SERVER_IP" "command -v docker &>/dev/null && echo yes || echo no" 2>/dev/null)

if [ "$DOCKER_INSTALLED" == "yes" ]; then
    DOCKER_VER=$(ssh "$SSH_USER@$SERVER_IP" "docker --version" 2>/dev/null)
    echo "✅ Docker already installed: $DOCKER_VER"
else
    echo "⚠️  Docker not found. Kamal will install it during 'kamal setup'."
    echo "   Or install manually:"
    echo "   ssh $SSH_USER@$SERVER_IP 'curl -fsSL https://get.docker.com | sh'"
fi
echo ""

# Check open ports
echo "Checking ports on server..."
for PORT in 80 443; do
    RESULT=$(ssh "$SSH_USER@$SERVER_IP" "ss -tlnp | grep :$PORT" 2>/dev/null)
    if [ -n "$RESULT" ]; then
        echo "⚠️  Port $PORT is already in use: $RESULT"
    else
        echo "✅ Port $PORT is available"
    fi
done
echo ""

# Check disk space
echo "Checking disk space..."
DISK_INFO=$(ssh "$SSH_USER@$SERVER_IP" "df -h / | tail -1" 2>/dev/null)
echo "   $DISK_INFO"
DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}' | tr -d '%')
if [ "$DISK_PERCENT" -gt 85 ]; then
    echo "⚠️  Disk usage is high ($DISK_PERCENT%). Consider cleaning up before deploying."
else
    echo "✅ Disk space OK ($DISK_PERCENT% used)"
fi
echo ""

# Check memory
echo "Checking memory..."
MEM_INFO=$(ssh "$SSH_USER@$SERVER_IP" "free -h | head -2" 2>/dev/null)
echo "$MEM_INFO"
echo ""

# Check if non-root user exists for deploy
if [ "$SSH_USER" == "root" ]; then
    echo "⚠️  You're using root. Consider creating a deploy user:"
    echo ""
    echo "   ssh root@$SERVER_IP"
    echo "   adduser deploy"
    echo "   usermod -aG docker deploy"
    echo "   cp -r ~/.ssh /home/deploy/.ssh"
    echo "   chown -R deploy:deploy /home/deploy/.ssh"
    echo ""
    echo "   Then update config/deploy.yml:"
    echo "   ssh:"
    echo "     user: deploy"
fi
echo ""

echo "=== Server is ready for Kamal ==="
echo ""
echo "Next steps:"
echo "  1. cd /path/to/your/app"
echo "  2. kamal init"
echo "  3. Edit config/deploy.yml (set server: $SERVER_IP)"
echo "  4. Edit .kamal/secrets"
echo "  5. kamal setup"
