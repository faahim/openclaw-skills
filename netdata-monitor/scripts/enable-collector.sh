#!/bin/bash
# Enable a Netdata collector
set -e

COLLECTOR="${1:-}"
URL=""

shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --url) URL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[ -z "$COLLECTOR" ] && {
    echo "Usage: bash scripts/enable-collector.sh <collector> [--url URL]"
    echo ""
    echo "Common collectors:"
    echo "  docker    - Docker container metrics"
    echo "  nginx     - Nginx web server (needs --url http://localhost/nginx_status)"
    echo "  apache    - Apache web server (needs --url http://localhost/server-status?auto)"
    echo "  mysql     - MySQL/MariaDB"
    echo "  postgres  - PostgreSQL"
    echo "  redis     - Redis"
    echo "  mongodb   - MongoDB"
    echo "  rabbitmq  - RabbitMQ"
    echo "  haproxy   - HAProxy"
    exit 0
}

CONF_DIR="/etc/netdata/go.d"
sudo mkdir -p "$CONF_DIR"

case "$COLLECTOR" in
    docker)
        echo "Docker monitoring is auto-detected if Docker is running."
        echo "Ensure Netdata user can access Docker socket:"
        echo "  sudo usermod -aG docker netdata"
        sudo usermod -aG docker netdata 2>/dev/null || true
        ;;
    nginx)
        [ -z "$URL" ] && URL="http://localhost/nginx_status"
        sudo tee "$CONF_DIR/nginx.conf" > /dev/null <<EOF
jobs:
  - name: local
    url: $URL
EOF
        echo "✅ Nginx collector configured → $URL"
        echo "   Ensure nginx stub_status is enabled:"
        echo "   location /nginx_status { stub_status; allow 127.0.0.1; deny all; }"
        ;;
    apache)
        [ -z "$URL" ] && URL="http://localhost/server-status?auto"
        sudo tee "$CONF_DIR/apache.conf" > /dev/null <<EOF
jobs:
  - name: local
    url: $URL
EOF
        echo "✅ Apache collector configured → $URL"
        ;;
    mysql)
        sudo tee "$CONF_DIR/mysql.conf" > /dev/null <<EOF
jobs:
  - name: local
    dsn: netdata@tcp(localhost:3306)/
EOF
        echo "✅ MySQL collector configured"
        echo "   Create user: CREATE USER 'netdata'@'localhost'; GRANT USAGE ON *.* TO 'netdata'@'localhost';"
        ;;
    postgres)
        sudo tee "$CONF_DIR/postgres.conf" > /dev/null <<EOF
jobs:
  - name: local
    dsn: postgresql://netdata@localhost:5432/postgres
EOF
        echo "✅ PostgreSQL collector configured"
        echo "   Create role: CREATE ROLE netdata LOGIN; GRANT pg_monitor TO netdata;"
        ;;
    redis)
        sudo tee "$CONF_DIR/redis.conf" > /dev/null <<EOF
jobs:
  - name: local
    address: redis://localhost:6379
EOF
        echo "✅ Redis collector configured"
        ;;
    *)
        echo "⚠️  Unknown collector: $COLLECTOR"
        echo "   Check Netdata docs: https://learn.netdata.cloud/docs/data-collection"
        exit 1
        ;;
esac

echo ""
echo "Restart Netdata: sudo systemctl restart netdata"
