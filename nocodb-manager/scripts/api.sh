#!/bin/bash
# NocoDB API Helper Script
# Interact with NocoDB's REST API from the command line

set -euo pipefail

NOCODB_URL="${NOCODB_URL:-http://localhost:8080}"
NOCODB_TOKEN="${NOCODB_TOKEN:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [OPTIONS]

NocoDB API client.

COMMANDS:
  create-token    Generate an API token
  list-tokens     List API tokens
  revoke-token    Revoke an API token
  list-bases      List all bases (projects)
  create-table    Create a new table
  list-tables     List tables in a base
  insert-rows     Insert records
  list-rows       Query records
  update-row      Update a record
  delete-row      Delete a record

ENVIRONMENT:
  NOCODB_URL      NocoDB URL (default: http://localhost:8080)
  NOCODB_TOKEN    API token (required for most commands)
EOF
  exit 0
}

api_call() {
  local method="$1" endpoint="$2"
  shift 2
  local args=(-s -X "$method" "${NOCODB_URL}/api/v2${endpoint}")
  [[ -n "$NOCODB_TOKEN" ]] && args+=(-H "xc-token: ${NOCODB_TOKEN}")
  args+=(-H "Content-Type: application/json")
  args+=("$@")
  curl "${args[@]}"
}

check_token() {
  if [[ -z "$NOCODB_TOKEN" ]]; then
    echo "❌ NOCODB_TOKEN not set. Export it or run: $(basename "$0") create-token"
    exit 1
  fi
}

[[ $# -eq 0 ]] && usage

COMMAND="$1"; shift

case "$COMMAND" in
  create-token)
    NAME=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --name) NAME="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    check_token
    RESULT=$(api_call POST "/tokens" -d "{\"description\":\"${NAME:-api-token}\"}")
    echo "$RESULT" | jq .
    echo ""
    TOKEN=$(echo "$RESULT" | jq -r '.token // empty')
    [[ -n "$TOKEN" ]] && echo "🔑 Token: $TOKEN"
    ;;

  list-tokens)
    check_token
    api_call GET "/tokens" | jq .
    ;;

  revoke-token)
    TOKEN_NAME=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --name) TOKEN_NAME="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    check_token
    TOKENS=$(api_call GET "/tokens")
    TOKEN_ID=$(echo "$TOKENS" | jq -r ".[] | select(.description==\"${TOKEN_NAME}\") | .id")
    if [[ -n "$TOKEN_ID" ]]; then
      api_call DELETE "/tokens/${TOKEN_ID}"
      echo "✅ Token '${TOKEN_NAME}' revoked"
    else
      echo "❌ Token '${TOKEN_NAME}' not found"
    fi
    ;;

  list-bases)
    check_token
    api_call GET "/meta/bases" | jq '.list[] | {id, title, created_at}'
    ;;

  create-table)
    BASE="" TABLE_NAME="" COLUMNS=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --base) BASE="$2"; shift 2 ;;
        --name) TABLE_NAME="$2"; shift 2 ;;
        --columns) COLUMNS="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    check_token

    # Find base ID by name
    BASES=$(api_call GET "/meta/bases")
    BASE_ID=$(echo "$BASES" | jq -r ".list[] | select(.title==\"${BASE}\") | .id")
    if [[ -z "$BASE_ID" ]]; then
      echo "❌ Base '${BASE}' not found. Available:"
      echo "$BASES" | jq -r '.list[].title'
      exit 1
    fi

    PAYLOAD="{\"table_name\":\"${TABLE_NAME}\",\"columns\":${COLUMNS:-[]}}"
    RESULT=$(api_call POST "/meta/bases/${BASE_ID}/tables" -d "$PAYLOAD")
    echo "$RESULT" | jq '{id, title: .table_name}'
    echo "✅ Table '${TABLE_NAME}' created"
    ;;

  list-tables)
    BASE=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --base) BASE="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    check_token

    BASES=$(api_call GET "/meta/bases")
    BASE_ID=$(echo "$BASES" | jq -r ".list[] | select(.title==\"${BASE}\") | .id")
    if [[ -z "$BASE_ID" ]]; then
      echo "❌ Base '${BASE}' not found"
      exit 1
    fi

    api_call GET "/meta/bases/${BASE_ID}/tables" | jq '.list[] | {id, title: .table_name}'
    ;;

  insert-rows)
    TABLE="" ROWS=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --table) TABLE="$2"; shift 2 ;;
        --rows) ROWS="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    check_token

    # Find table ID (search across all bases)
    BASES=$(api_call GET "/meta/bases")
    TABLE_ID=""
    for BASE_ID in $(echo "$BASES" | jq -r '.list[].id'); do
      TABLES=$(api_call GET "/meta/bases/${BASE_ID}/tables")
      TABLE_ID=$(echo "$TABLES" | jq -r ".list[] | select(.table_name==\"${TABLE}\") | .id")
      [[ -n "$TABLE_ID" ]] && break
    done

    if [[ -z "$TABLE_ID" ]]; then
      echo "❌ Table '${TABLE}' not found"
      exit 1
    fi

    RESULT=$(api_call POST "/tables/${TABLE_ID}/records" -d "$ROWS")
    COUNT=$(echo "$RESULT" | jq 'if type == "array" then length else 1 end')
    echo "✅ Inserted ${COUNT} record(s) into '${TABLE}'"
    ;;

  list-rows)
    TABLE="" WHERE="" SORT="" LIMIT=25 OFFSET=0
    while [[ $# -gt 0 ]]; do
      case $1 in
        --table) TABLE="$2"; shift 2 ;;
        --where) WHERE="$2"; shift 2 ;;
        --sort) SORT="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --offset) OFFSET="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    check_token

    BASES=$(api_call GET "/meta/bases")
    TABLE_ID=""
    for BASE_ID in $(echo "$BASES" | jq -r '.list[].id'); do
      TABLES=$(api_call GET "/meta/bases/${BASE_ID}/tables")
      TABLE_ID=$(echo "$TABLES" | jq -r ".list[] | select(.table_name==\"${TABLE}\") | .id")
      [[ -n "$TABLE_ID" ]] && break
    done

    if [[ -z "$TABLE_ID" ]]; then
      echo "❌ Table '${TABLE}' not found"
      exit 1
    fi

    PARAMS="limit=${LIMIT}&offset=${OFFSET}"
    [[ -n "$WHERE" ]] && PARAMS+="&where=${WHERE}"
    [[ -n "$SORT" ]] && PARAMS+="&sort=${SORT}"

    api_call GET "/tables/${TABLE_ID}/records?${PARAMS}" | jq .
    ;;

  update-row)
    TABLE="" ROW_ID="" DATA=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --table) TABLE="$2"; shift 2 ;;
        --id) ROW_ID="$2"; shift 2 ;;
        --data) DATA="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    check_token

    BASES=$(api_call GET "/meta/bases")
    TABLE_ID=""
    for BASE_ID in $(echo "$BASES" | jq -r '.list[].id'); do
      TABLES=$(api_call GET "/meta/bases/${BASE_ID}/tables")
      TABLE_ID=$(echo "$TABLES" | jq -r ".list[] | select(.table_name==\"${TABLE}\") | .id")
      [[ -n "$TABLE_ID" ]] && break
    done

    PAYLOAD=$(echo "$DATA" | jq ". + {\"Id\": ${ROW_ID}}")
    api_call PATCH "/tables/${TABLE_ID}/records" -d "[${PAYLOAD}]"
    echo "✅ Updated row ${ROW_ID} in '${TABLE}'"
    ;;

  delete-row)
    TABLE="" ROW_ID=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --table) TABLE="$2"; shift 2 ;;
        --id) ROW_ID="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    check_token

    BASES=$(api_call GET "/meta/bases")
    TABLE_ID=""
    for BASE_ID in $(echo "$BASES" | jq -r '.list[].id'); do
      TABLES=$(api_call GET "/meta/bases/${BASE_ID}/tables")
      TABLE_ID=$(echo "$TABLES" | jq -r ".list[] | select(.table_name==\"${TABLE}\") | .id")
      [[ -n "$TABLE_ID" ]] && break
    done

    api_call DELETE "/tables/${TABLE_ID}/records" -d "[{\"Id\": ${ROW_ID}}]"
    echo "✅ Deleted row ${ROW_ID} from '${TABLE}'"
    ;;

  *)
    echo "❌ Unknown command: $COMMAND"
    usage
    ;;
esac
