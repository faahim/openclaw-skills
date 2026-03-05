#!/bin/bash
set -euo pipefail

# Listmonk Management Script — CLI for common operations

INSTALL_DIR="${LISTMONK_DIR:-$HOME/listmonk}"
source "$INSTALL_DIR/.env" 2>/dev/null || true

PORT="${LISTMONK_PORT:-9000}"
ADMIN_USER="${LISTMONK_ADMIN_USER:-admin}"
ADMIN_PASS="${LISTMONK_ADMIN_PASSWORD:-admin}"
BASE_URL="http://localhost:${PORT}"
AUTH="-u ${ADMIN_USER}:${ADMIN_PASS}"

COMPOSE="docker compose"
if ! docker compose version &>/dev/null 2>&1; then
    COMPOSE="docker-compose"
fi

api() {
    local method="$1" endpoint="$2"
    shift 2
    curl -sf $AUTH -X "$method" "${BASE_URL}/api${endpoint}" -H "Content-Type: application/json" "$@"
}

CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in

    # === Service Management ===
    start)
        cd "$INSTALL_DIR" && $COMPOSE up -d
        echo "✅ Listmonk started"
        ;;
    stop)
        cd "$INSTALL_DIR" && $COMPOSE down
        echo "✅ Listmonk stopped"
        ;;
    restart)
        cd "$INSTALL_DIR" && $COMPOSE restart
        echo "✅ Listmonk restarted"
        ;;
    logs)
        TAIL="${1:-50}"
        cd "$INSTALL_DIR" && $COMPOSE logs --tail "$TAIL" app
        ;;
    status)
        if curl -sf "${BASE_URL}/api/health" &>/dev/null; then
            echo "✅ Listmonk is running on port ${PORT}"
            SUBS=$(api GET "/subscribers?per_page=1" | jq '.data.total // 0')
            LISTS=$(api GET "/lists?per_page=1" | jq '.data.total // 0')
            CAMPS=$(api GET "/campaigns?per_page=1" | jq '.data.total // 0')
            echo "📊 Subscribers: $SUBS | Lists: $LISTS | Campaigns: $CAMPS"
        else
            echo "❌ Listmonk is not running"
        fi
        ;;
    update)
        cd "$INSTALL_DIR"
        $COMPOSE pull
        $COMPOSE up -d
        echo "✅ Listmonk updated to latest"
        ;;
    uninstall)
        read -p "⚠️  This will delete all data. Continue? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$INSTALL_DIR"
            $COMPOSE down -v
            echo "✅ Listmonk uninstalled"
        fi
        ;;

    # === List Management ===
    create-list)
        NAME="" TYPE="public" OPTIN="single"
        while [[ $# -gt 0 ]]; do
            case $1 in
                --name) NAME="$2"; shift 2 ;;
                --type) TYPE="$2"; shift 2 ;;
                --optin) OPTIN="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        [ -z "$NAME" ] && { echo "Usage: manage.sh create-list --name <name> [--type public|private] [--optin single|double]"; exit 1; }
        RESULT=$(api POST "/lists" -d "{\"name\":\"$NAME\",\"type\":\"$TYPE\",\"optin\":\"$OPTIN\"}")
        ID=$(echo "$RESULT" | jq '.data.id')
        echo "✅ List \"$NAME\" created (ID: $ID)"
        ;;

    list-lists)
        api GET "/lists?per_page=100" | jq -r '.data.results[] | "[\(.id)] \(.name) (\(.type)) — \(.subscriber_count) subscribers"'
        ;;

    # === Subscriber Management ===
    add-subscriber)
        EMAIL="" NAME="" LIST=""
        while [[ $# -gt 0 ]]; do
            case $1 in
                --email) EMAIL="$2"; shift 2 ;;
                --name) NAME="$2"; shift 2 ;;
                --list) LIST="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        [ -z "$EMAIL" ] && { echo "Usage: manage.sh add-subscriber --email <email> [--name <name>] [--list <list-id>]"; exit 1; }

        LISTS_JSON="[]"
        [ -n "$LIST" ] && LISTS_JSON="[$LIST]"

        RESULT=$(api POST "/subscribers" -d "{\"email\":\"$EMAIL\",\"name\":\"${NAME:-}\",\"lists\":$LISTS_JSON,\"status\":\"enabled\"}")
        if echo "$RESULT" | jq -e '.data.id' &>/dev/null; then
            echo "✅ Subscriber added: $EMAIL (ID: $(echo "$RESULT" | jq '.data.id'))"
        else
            echo "❌ Failed: $(echo "$RESULT" | jq -r '.message // "Unknown error"')"
        fi
        ;;

    remove-subscriber)
        EMAIL=""
        while [[ $# -gt 0 ]]; do
            case $1 in --email) EMAIL="$2"; shift 2 ;; *) shift ;; esac
        done
        [ -z "$EMAIL" ] && { echo "Usage: manage.sh remove-subscriber --email <email>"; exit 1; }

        # Find subscriber by email
        SUB=$(api GET "/subscribers?query=subscribers.email%3D'${EMAIL}'&per_page=1" | jq '.data.results[0]')
        if [ "$SUB" = "null" ]; then
            echo "❌ Subscriber not found: $EMAIL"
            exit 1
        fi
        ID=$(echo "$SUB" | jq '.id')
        api DELETE "/subscribers/$ID"
        echo "✅ Subscriber removed: $EMAIL"
        ;;

    list-subscribers)
        LIMIT="${1:-25}"
        api GET "/subscribers?per_page=$LIMIT&order_by=created_at&order=desc" | \
            jq -r '.data.results[] | "[\(.id)] \(.email) — \(.name) (\(.status))"'
        ;;

    import)
        FILE="" LIST=""
        while [[ $# -gt 0 ]]; do
            case $1 in
                --file) FILE="$2"; shift 2 ;;
                --list) LIST="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        [ -z "$FILE" ] && { echo "Usage: manage.sh import --file <csv> [--list <list-id>]"; exit 1; }
        [ ! -f "$FILE" ] && { echo "❌ File not found: $FILE"; exit 1; }

        PARAMS=""
        [ -n "$LIST" ] && PARAMS="params={\"lists\":[$LIST],\"mode\":\"subscribe\"}"

        echo "📥 Importing subscribers from $FILE..."
        RESULT=$(curl -sf $AUTH -X POST "${BASE_URL}/api/import/subscribers" \
            -F "file=@${FILE}" \
            ${PARAMS:+-F "$PARAMS"})
        echo "$RESULT" | jq '.'
        echo "✅ Import started. Check status in admin panel."
        ;;

    # === Campaign Management ===
    send-campaign)
        NAME="" SUBJECT="" LIST="" BODY_FILE="" SCHEDULE=""
        while [[ $# -gt 0 ]]; do
            case $1 in
                --name) NAME="$2"; shift 2 ;;
                --subject) SUBJECT="$2"; shift 2 ;;
                --list) LIST="$2"; shift 2 ;;
                --body-file) BODY_FILE="$2"; shift 2 ;;
                --schedule) SCHEDULE="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        [ -z "$NAME" ] || [ -z "$LIST" ] && { echo "Usage: manage.sh send-campaign --name <name> --subject <subj> --list <list-id> --body-file <html> [--schedule <iso-date>]"; exit 1; }
        [ -z "$SUBJECT" ] && SUBJECT="$NAME"

        BODY="<p>Hello!</p>"
        [ -n "$BODY_FILE" ] && [ -f "$BODY_FILE" ] && BODY=$(cat "$BODY_FILE" | jq -Rs .)

        PAYLOAD=$(jq -n --arg name "$NAME" --arg subject "$SUBJECT" --argjson lists "[$LIST]" \
            --argjson body "$BODY" --arg sched "${SCHEDULE:-}" \
            '{name: $name, subject: $subject, lists: $lists, body: $body, content_type: "richtext", type: "regular", send_at: (if $sched != "" then $sched else null end)}')

        RESULT=$(api POST "/campaigns" -d "$PAYLOAD")
        CID=$(echo "$RESULT" | jq '.data.id')

        if [ "$CID" != "null" ] && [ -n "$CID" ]; then
            if [ -z "$SCHEDULE" ]; then
                api PUT "/campaigns/${CID}/status" -d '{"status":"running"}' >/dev/null
                echo "📧 Campaign \"$NAME\" is sending now! (ID: $CID)"
            else
                echo "📧 Campaign \"$NAME\" scheduled for $SCHEDULE (ID: $CID)"
            fi
        else
            echo "❌ Failed to create campaign"
            echo "$RESULT" | jq . 2>/dev/null
        fi
        ;;

    stats)
        CAMPAIGN=""
        while [[ $# -gt 0 ]]; do
            case $1 in --campaign) CAMPAIGN="$2"; shift 2 ;; *) shift ;; esac
        done

        if [ -n "$CAMPAIGN" ]; then
            # Get campaign by name or ID
            if [[ "$CAMPAIGN" =~ ^[0-9]+$ ]]; then
                DATA=$(api GET "/campaigns/$CAMPAIGN" | jq '.data')
            else
                DATA=$(api GET "/campaigns?query=$CAMPAIGN&per_page=1" | jq '.data.results[0]')
            fi
            echo "📊 Campaign: $(echo "$DATA" | jq -r '.name')"
            echo "├── Status: $(echo "$DATA" | jq -r '.status')"
            echo "├── Sent: $(echo "$DATA" | jq -r '.to_send // 0')"
            echo "├── Views: $(echo "$DATA" | jq -r '.views // 0')"
            echo "└── Clicks: $(echo "$DATA" | jq -r '.clicks // 0')"
        else
            # List all campaigns with stats
            api GET "/campaigns?per_page=20&order_by=created_at&order=desc" | \
                jq -r '.data.results[] | "[\(.id)] \(.name) — \(.status) | Sent: \(.to_send // 0) | Views: \(.views // 0) | Clicks: \(.clicks // 0)"'
        fi
        ;;

    list-templates)
        api GET "/templates" | jq -r '.data[] | "[\(.id)] \(.name) — \(if .is_default then "DEFAULT" else "custom" end)"'
        ;;

    # === Help ===
    help|*)
        echo "Listmonk Newsletter Manager"
        echo ""
        echo "Service:"
        echo "  start              Start Listmonk"
        echo "  stop               Stop Listmonk"
        echo "  restart            Restart Listmonk"
        echo "  status             Show status & stats"
        echo "  logs [N]           Show last N log lines"
        echo "  update             Update to latest version"
        echo "  uninstall          Remove Listmonk completely"
        echo ""
        echo "Lists:"
        echo "  create-list        --name <name> [--type public|private] [--optin single|double]"
        echo "  list-lists         Show all lists"
        echo ""
        echo "Subscribers:"
        echo "  add-subscriber     --email <email> [--name <name>] [--list <id>]"
        echo "  remove-subscriber  --email <email>"
        echo "  list-subscribers   [limit]"
        echo "  import             --file <csv> [--list <id>]"
        echo ""
        echo "Campaigns:"
        echo "  send-campaign      --name <n> --subject <s> --list <id> --body-file <html> [--schedule <iso>]"
        echo "  stats              [--campaign <name-or-id>]"
        echo "  list-templates     Show available templates"
        ;;
esac
