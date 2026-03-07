#!/bin/bash
set -euo pipefail

# Linkding Bookmark CLI
# Requires: LINKDING_URL and LINKDING_TOKEN environment variables

LINKDING_URL="${LINKDING_URL:-http://localhost:9090}"
LINKDING_TOKEN="${LINKDING_TOKEN:-}"

if [[ -z "$LINKDING_TOKEN" ]]; then
    echo "❌ LINKDING_TOKEN not set."
    echo "   Run: bash scripts/manage.sh get-token --username admin --password yourpass"
    exit 1
fi

API="$LINKDING_URL/api"
AUTH="Authorization: Token $LINKDING_TOKEN"

ACTION="${1:-help}"
shift 2>/dev/null || true

# Parse named args
URL="" TITLE="" DESCRIPTION="" TAGS="" TAG="" LIMIT=20 FORMAT="html" FILE="" IDS="" ADD_TAG="" REMOVE_TAG="" ARCHIVE=false QUERY=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --url) URL="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --tags) TAGS="$2"; shift 2 ;;
        --tag) TAG="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;
        --file) FILE="$2"; shift 2 ;;
        --ids) IDS="$2"; shift 2 ;;
        --add) ADD_TAG="$2"; shift 2 ;;
        --remove) REMOVE_TAG="$2"; shift 2 ;;
        --archive) ARCHIVE=true; shift ;;
        *) QUERY="${QUERY:+$QUERY }$1"; shift ;;
    esac
done

case "$ACTION" in
    add)
        if [[ -z "$URL" ]]; then
            echo "Usage: bookmarks.sh add --url <url> [--title <title>] [--tags <tag1,tag2>] [--description <desc>] [--archive]"
            exit 1
        fi
        # Build JSON payload
        IFS=',' read -ra TAG_ARRAY <<< "${TAGS:-}"
        TAG_JSON=$(printf '%s\n' "${TAG_ARRAY[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')
        
        PAYLOAD=$(jq -n \
            --arg url "$URL" \
            --arg title "${TITLE:-}" \
            --arg desc "${DESCRIPTION:-}" \
            --argjson tags "$TAG_JSON" \
            --argjson is_archived "$( [[ "$ARCHIVE" == true ]] && echo true || echo false )" \
            '{url: $url, title: $title, description: $desc, tag_names: $tags, is_archived: $is_archived}')

        RESULT=$(curl -s -X POST "$API/bookmarks/" \
            -H "$AUTH" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD")

        ID=$(echo "$RESULT" | jq -r '.id // empty')
        if [[ -n "$ID" ]]; then
            echo "✅ Bookmark added (ID: $ID)"
            echo "   URL: $URL"
            echo "   Tags: ${TAGS:-none}"
        else
            ERROR=$(echo "$RESULT" | jq -r '.url[0] // .detail // "Unknown error"')
            echo "❌ Failed: $ERROR"
        fi
        ;;

    search)
        SEARCH_URL="$API/bookmarks/?limit=$LIMIT"
        if [[ -n "$TAG" ]]; then
            SEARCH_URL="$API/bookmarks/?limit=$LIMIT&q=%23${TAG}"
        elif [[ -n "$QUERY" ]]; then
            ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))" 2>/dev/null || echo "$QUERY")
            SEARCH_URL="$API/bookmarks/?limit=$LIMIT&q=$ENCODED"
        fi

        RESULT=$(curl -s "$SEARCH_URL" -H "$AUTH")
        COUNT=$(echo "$RESULT" | jq -r '.count')
        
        echo "Found $COUNT bookmark(s):"
        echo ""
        printf "%-6s | %-40s | %-30s | %s\n" "ID" "URL" "Title" "Tags"
        printf "%s\n" "-------|------------------------------------------|--------------------------------|------------------"
        
        echo "$RESULT" | jq -r '.results[] | [
            (.id | tostring),
            (.url | if length > 38 then .[0:38] + ".." else . end),
            (.title | if length > 28 then .[0:28] + ".." else . end),
            ([.tag_names[]?] | join(","))
        ] | join(" | ")' | while IFS='|' read -r id url title tags; do
            printf "%-6s |%-41s |%-31s | %s\n" "$id" "$url" "$title" "$tags"
        done
        ;;

    list)
        RESULT=$(curl -s "$API/bookmarks/?limit=$LIMIT&offset=0" -H "$AUTH")
        COUNT=$(echo "$RESULT" | jq -r '.count')
        
        echo "📚 Total bookmarks: $COUNT (showing up to $LIMIT)"
        echo ""
        echo "$RESULT" | jq -r '.results[] | "[\(.id)] \(.title // .url)\n    🔗 \(.url)\n    🏷️  \([.tag_names[]?] | join(", "))\n"'
        ;;

    delete)
        if [[ -z "$QUERY" ]]; then
            echo "Usage: bookmarks.sh delete <bookmark-id>"
            exit 1
        fi
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API/bookmarks/${QUERY}/" -H "$AUTH")
        if [[ "$HTTP_CODE" == "204" ]]; then
            echo "✅ Bookmark $QUERY deleted"
        else
            echo "❌ Failed to delete bookmark $QUERY (HTTP $HTTP_CODE)"
        fi
        ;;

    import)
        if [[ -z "$FILE" ]]; then
            echo "Usage: bookmarks.sh import --file <bookmarks.html>"
            exit 1
        fi
        if [[ ! -f "$FILE" ]]; then
            echo "❌ File not found: $FILE"
            exit 1
        fi
        RESULT=$(curl -s -X POST "$API/bookmarks/import" \
            -H "$AUTH" \
            -F "file=@$FILE")
        echo "✅ Import complete"
        echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
        ;;

    export)
        if [[ "$FORMAT" == "json" ]]; then
            # Paginate through all bookmarks
            OFFSET=0
            echo "["
            FIRST=true
            while true; do
                RESULT=$(curl -s "$API/bookmarks/?limit=100&offset=$OFFSET" -H "$AUTH")
                ITEMS=$(echo "$RESULT" | jq '.results | length')
                if [[ "$ITEMS" -eq 0 ]]; then break; fi
                if [[ "$FIRST" == true ]]; then FIRST=false; else echo ","; fi
                echo "$RESULT" | jq -r '[.results[]] | @json'
                OFFSET=$((OFFSET + 100))
            done
            echo "]"
        else
            # Export as HTML
            curl -s "$API/bookmarks/export" -H "$AUTH"
        fi
        ;;

    tags)
        RESULT=$(curl -s "$API/tags/?limit=100" -H "$AUTH")
        echo "🏷️  Tags:"
        echo ""
        printf "%-20s | %s\n" "Tag" "Bookmarks"
        printf "%s\n" "---------------------|----------"
        echo "$RESULT" | jq -r '.results | sort_by(-.count_all) | .[] | "\(.name) | \(.count_all)"' | \
            while IFS='|' read -r name count; do
                printf "%-20s |%s\n" "$name" "$count"
            done
        ;;

    bulk-tag)
        if [[ -z "$IDS" ]]; then
            echo "Usage: bookmarks.sh bulk-tag --ids <id1,id2,...> --add <tag> | --remove <tag>"
            exit 1
        fi
        IFS=',' read -ra ID_ARRAY <<< "$IDS"
        for id in "${ID_ARRAY[@]}"; do
            CURRENT=$(curl -s "$API/bookmarks/${id}/" -H "$AUTH")
            CURRENT_TAGS=$(echo "$CURRENT" | jq -r '[.tag_names[]]')
            
            if [[ -n "$ADD_TAG" ]]; then
                NEW_TAGS=$(echo "$CURRENT_TAGS" | jq --arg t "$ADD_TAG" '. + [$t] | unique')
            elif [[ -n "$REMOVE_TAG" ]]; then
                NEW_TAGS=$(echo "$CURRENT_TAGS" | jq --arg t "$REMOVE_TAG" 'map(select(. != $t))')
            else
                echo "Specify --add or --remove"; exit 1
            fi

            curl -s -X PATCH "$API/bookmarks/${id}/" \
                -H "$AUTH" \
                -H "Content-Type: application/json" \
                -d "{\"tag_names\": $NEW_TAGS}" > /dev/null
            echo "✅ Updated bookmark $id"
        done
        ;;

    help|*)
        echo "Linkding Bookmark CLI"
        echo ""
        echo "Usage: bookmarks.sh <action> [options]"
        echo ""
        echo "Actions:"
        echo "  add --url <url> [--title] [--tags t1,t2] [--description] [--archive]"
        echo "  search <query>              Search bookmarks by keyword"
        echo "  search --tag <tag>          Search by tag"
        echo "  list [--limit N]            List all bookmarks"
        echo "  delete <id>                 Delete a bookmark"
        echo "  import --file <path>        Import bookmarks HTML file"
        echo "  export [--format html|json] Export bookmarks"
        echo "  tags                        List all tags with counts"
        echo "  bulk-tag --ids <ids> --add/--remove <tag>"
        ;;
esac
