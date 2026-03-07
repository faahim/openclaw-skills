#!/bin/bash
set -euo pipefail

LINKDING_PORT="${LINKDING_PORT:-9090}"
LINKDING_DATA_DIR="${LINKDING_DATA_DIR:-$HOME/.linkding}"

ACTION="${1:-help}"
shift 2>/dev/null || true

# Parse named args
USERNAME="" PASSWORD="" FILE="" DOMAIN=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --username) USERNAME="$2"; shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        --file) FILE="$2"; shift 2 ;;
        --domain) DOMAIN="$2"; shift 2 ;;
        *) shift ;;
    esac
done

case "$ACTION" in
    start)
        echo "🚀 Starting Linkding..."
        cd "$LINKDING_DATA_DIR"
        if docker compose version &>/dev/null 2>&1; then
            docker compose up -d
        else
            docker start linkding 2>/dev/null || docker-compose up -d
        fi
        echo "✅ Linkding started on port $LINKDING_PORT"
        ;;

    stop)
        echo "⏹️  Stopping Linkding..."
        docker stop linkding
        echo "✅ Linkding stopped"
        ;;

    restart)
        echo "🔄 Restarting Linkding..."
        docker restart linkding
        echo "✅ Linkding restarted"
        ;;

    status)
        if docker ps --format '{{.Names}}' | grep -q '^linkding$'; then
            echo "✅ Linkding is running"
            docker ps --filter name=linkding --format "table {{.Status}}\t{{.Ports}}"
            # Get bookmark count if token is set
            if [[ -n "${LINKDING_TOKEN:-}" && -n "${LINKDING_URL:-}" ]]; then
                COUNT=$(curl -s "$LINKDING_URL/api/bookmarks/?limit=1" \
                    -H "Authorization: Token $LINKDING_TOKEN" 2>/dev/null | jq -r '.count // "?"')
                echo "📊 Bookmarks: $COUNT"
            fi
        else
            echo "❌ Linkding is not running"
        fi
        ;;

    create-user)
        if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
            echo "Usage: manage.sh create-user --username <user> --password <pass>"
            exit 1
        fi
        echo "👤 Creating superuser '$USERNAME'..."
        docker exec linkding python manage.py createsuperuser \
            --username "$USERNAME" --email "${USERNAME}@localhost" --noinput 2>/dev/null || true
        # Set password
        docker exec linkding python manage.py shell -c \
            "from django.contrib.auth.models import User; u=User.objects.get(username='$USERNAME'); u.set_password('$PASSWORD'); u.save(); print('Password set')"
        echo "✅ User '$USERNAME' created"
        ;;

    get-token)
        if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
            echo "Usage: manage.sh get-token --username <user> --password <pass>"
            exit 1
        fi
        # Get token via API
        TOKEN=$(curl -s -X POST "http://localhost:${LINKDING_PORT}/api/api-token" \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" 2>/dev/null | jq -r '.token // empty')
        
        if [[ -z "$TOKEN" ]]; then
            # Try creating token via Django management
            TOKEN=$(docker exec linkding python manage.py shell -c \
                "from django.contrib.auth.models import User; from rest_framework.authtoken.models import Token; u=User.objects.get(username='$USERNAME'); t,_=Token.objects.get_or_create(user=u); print(t.key)" 2>/dev/null)
        fi

        if [[ -n "$TOKEN" ]]; then
            echo "🔑 API Token: $TOKEN"
            echo ""
            echo "Set in your shell:"
            echo "  export LINKDING_URL=\"http://localhost:${LINKDING_PORT}\""
            echo "  export LINKDING_TOKEN=\"$TOKEN\""
        else
            echo "❌ Could not retrieve token. Check credentials."
        fi
        ;;

    backup)
        BACKUP_FILE="$LINKDING_DATA_DIR/backups/linkding-$(date +%Y-%m-%d_%H%M%S).sql.gz"
        echo "💾 Backing up Linkding database..."
        docker exec linkding python manage.py dumpdata --natural-foreign --natural-primary | gzip > "$BACKUP_FILE"
        echo "✅ Backup saved to $BACKUP_FILE"
        echo "   Size: $(du -h "$BACKUP_FILE" | cut -f1)"
        ;;

    restore)
        if [[ -z "$FILE" ]]; then
            echo "Usage: manage.sh restore --file <backup-file>"
            echo ""
            echo "Available backups:"
            ls -lh "$LINKDING_DATA_DIR/backups/" 2>/dev/null || echo "  No backups found"
            exit 1
        fi
        echo "⚠️  Restoring from $FILE..."
        echo "   This will replace all current data!"
        zcat "$FILE" | docker exec -i linkding python manage.py loaddata --format=json -
        echo "✅ Restore complete"
        ;;

    update)
        echo "📦 Updating Linkding..."
        docker pull sissbruecker/linkding:latest
        docker stop linkding
        docker rm linkding
        cd "$LINKDING_DATA_DIR"
        if docker compose version &>/dev/null 2>&1; then
            docker compose up -d
        else
            docker-compose up -d
        fi
        echo "✅ Linkding updated and restarted"
        ;;

    nginx-config)
        if [[ -z "$DOMAIN" ]]; then
            echo "Usage: manage.sh nginx-config --domain bookmarks.example.com"
            exit 1
        fi
        CONFIG="server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:${LINKDING_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}"
        echo "$CONFIG"
        if [[ -d /etc/nginx/sites-available ]]; then
            echo "$CONFIG" | sudo tee "/etc/nginx/sites-available/linkding" > /dev/null
            echo ""
            echo "✅ Config written to /etc/nginx/sites-available/linkding"
            echo "   Enable: sudo ln -s /etc/nginx/sites-available/linkding /etc/nginx/sites-enabled/"
            echo "   Test:   sudo nginx -t"
            echo "   Reload: sudo systemctl reload nginx"
        fi
        ;;

    help|*)
        echo "Linkding Manager"
        echo ""
        echo "Usage: manage.sh <action> [options]"
        echo ""
        echo "Actions:"
        echo "  start                          Start Linkding container"
        echo "  stop                           Stop Linkding container"
        echo "  restart                        Restart Linkding container"
        echo "  status                         Check if Linkding is running"
        echo "  create-user --username --password  Create admin user"
        echo "  get-token --username --password    Get API token"
        echo "  backup                         Backup database"
        echo "  restore --file <path>          Restore from backup"
        echo "  update                         Update to latest version"
        echo "  nginx-config --domain <domain> Generate Nginx reverse proxy config"
        ;;
esac
