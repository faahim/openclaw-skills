#!/bin/bash
# Manage Fly.io Postgres databases
# Usage: bash database.sh --create --name DB --region REGION | --attach --db DB --app APP | --connect --db DB

set -euo pipefail

PREFIX="[flyio-manager]"
ACTION=""
DB_NAME=""
REGION="iad"
APP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --create) ACTION="create"; shift ;;
        --attach) ACTION="attach"; shift ;;
        --connect) ACTION="connect"; shift ;;
        --detach) ACTION="detach"; shift ;;
        --list) ACTION="list"; shift ;;
        --name|--db) DB_NAME="$2"; shift 2 ;;
        --region) REGION="$2"; shift 2 ;;
        --app) APP="$2"; shift 2 ;;
        *) echo "$PREFIX Unknown option: $1"; exit 1 ;;
    esac
done

if ! command -v fly &>/dev/null; then
    echo "$PREFIX flyctl not found. Run: bash scripts/install.sh"
    exit 1
fi

case "$ACTION" in
    create)
        if [[ -z "$DB_NAME" ]]; then
            echo "$PREFIX --name required for create"; exit 1
        fi
        echo "$PREFIX Creating Postgres cluster: $DB_NAME in $REGION..."
        fly postgres create --name "$DB_NAME" --region "$REGION"
        echo ""
        echo "$PREFIX ✅ Database created"
        echo "$PREFIX Attach to app: bash scripts/database.sh --attach --db $DB_NAME --app YOUR_APP"
        ;;
    attach)
        if [[ -z "$DB_NAME" ]] || [[ -z "$APP" ]]; then
            echo "$PREFIX --db and --app required for attach"; exit 1
        fi
        echo "$PREFIX Attaching $DB_NAME to $APP..."
        fly postgres attach "$DB_NAME" --app "$APP"
        echo "$PREFIX ✅ DATABASE_URL secret set on $APP"
        ;;
    detach)
        if [[ -z "$DB_NAME" ]] || [[ -z "$APP" ]]; then
            echo "$PREFIX --db and --app required for detach"; exit 1
        fi
        echo "$PREFIX Detaching $DB_NAME from $APP..."
        fly postgres detach "$DB_NAME" --app "$APP"
        echo "$PREFIX ✅ Detached"
        ;;
    connect)
        if [[ -z "$DB_NAME" ]]; then
            echo "$PREFIX --db required for connect"; exit 1
        fi
        echo "$PREFIX Connecting to $DB_NAME via psql..."
        fly postgres connect --app "$DB_NAME"
        ;;
    list)
        echo "$PREFIX Postgres clusters:"
        fly postgres list 2>/dev/null || fly apps list | grep -i postgres
        ;;
    *)
        echo "$PREFIX Usage:"
        echo "  bash database.sh --create --name mydb --region iad"
        echo "  bash database.sh --attach --db mydb --app myapp"
        echo "  bash database.sh --connect --db mydb"
        echo "  bash database.sh --detach --db mydb --app myapp"
        echo "  bash database.sh --list"
        exit 1
        ;;
esac
