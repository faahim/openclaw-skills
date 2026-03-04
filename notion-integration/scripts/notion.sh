#!/usr/bin/env bash
# Notion Integration — CLI wrapper for the Notion API
# Requires: NOTION_API_KEY environment variable, curl, jq

set -euo pipefail

###############################################################################
# Config
###############################################################################
API_BASE="https://api.notion.com"
API_VERSION="${NOTION_API_VERSION:-2022-06-28}"
MAX_RETRIES=3
RETRY_DELAY=2

if [[ -z "${NOTION_API_KEY:-}" ]]; then
  echo "Error: NOTION_API_KEY not set. Export it or add to ~/.openclaw/env" >&2
  exit 1
fi

for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed." >&2
    exit 1
  fi
done

###############################################################################
# Helpers
###############################################################################
notion_request() {
  local method="$1" endpoint="$2" body="${3:-}"
  local attempt=0 response http_code

  while (( attempt < MAX_RETRIES )); do
    if [[ -n "$body" ]]; then
      response=$(curl -s -w "\n%{http_code}" -X "$method" \
        "${API_BASE}${endpoint}" \
        -H "Authorization: Bearer ${NOTION_API_KEY}" \
        -H "Notion-Version: ${API_VERSION}" \
        -H "Content-Type: application/json" \
        -d "$body" 2>/dev/null)
    else
      response=$(curl -s -w "\n%{http_code}" -X "$method" \
        "${API_BASE}${endpoint}" \
        -H "Authorization: Bearer ${NOTION_API_KEY}" \
        -H "Notion-Version: ${API_VERSION}" 2>/dev/null)
    fi

    http_code=$(echo "$response" | tail -1)
    response=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "429" ]]; then
      attempt=$((attempt + 1))
      local wait=$((RETRY_DELAY * attempt))
      echo "Rate limited, retrying in ${wait}s..." >&2
      sleep "$wait"
      continue
    elif [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
      echo "$response"
      return 0
    else
      echo "Error (HTTP $http_code): $(echo "$response" | jq -r '.message // .code // "Unknown error"' 2>/dev/null || echo "$response")" >&2
      return 1
    fi
  done

  echo "Error: Max retries exceeded." >&2
  return 1
}

format_rich_text() {
  local text="$1"
  echo "$text" | jq -Rs '[{type:"text",text:{content:.}}]'
}

extract_title() {
  local props="$1" key
  # Find the title property
  key=$(echo "$props" | jq -r 'to_entries[] | select(.value.type == "title") | .key' | head -1)
  if [[ -n "$key" ]]; then
    echo "$props" | jq -r ".\"$key\".title[0].plain_text // \"(untitled)\""
  else
    echo "(untitled)"
  fi
}

extract_plain_text() {
  jq -r '.results[]?.properties | to_entries[] | select(.value.type == "title") | .value.title[0].plain_text // "(untitled)"' 2>/dev/null
}

blocks_to_text() {
  jq -r '.results[] |
    if .type == "paragraph" then
      (.paragraph.rich_text | map(.plain_text) | join(""))
    elif .type == "heading_1" then
      "# " + (.heading_1.rich_text | map(.plain_text) | join(""))
    elif .type == "heading_2" then
      "## " + (.heading_2.rich_text | map(.plain_text) | join(""))
    elif .type == "heading_3" then
      "### " + (.heading_3.rich_text | map(.plain_text) | join(""))
    elif .type == "bulleted_list_item" then
      "- " + (.bulleted_list_item.rich_text | map(.plain_text) | join(""))
    elif .type == "numbered_list_item" then
      "1. " + (.numbered_list_item.rich_text | map(.plain_text) | join(""))
    elif .type == "to_do" then
      (if .to_do.checked then "- [x] " else "- [ ] " end) + (.to_do.rich_text | map(.plain_text) | join(""))
    elif .type == "code" then
      "```" + (.code.language // "") + "\n" + (.code.rich_text | map(.plain_text) | join("")) + "\n```"
    elif .type == "quote" then
      "> " + (.quote.rich_text | map(.plain_text) | join(""))
    elif .type == "divider" then
      "---"
    elif .type == "callout" then
      "> " + (.callout.icon.emoji // "💡") + " " + (.callout.rich_text | map(.plain_text) | join(""))
    elif .type == "toggle" then
      "<details><summary>" + (.toggle.rich_text | map(.plain_text) | join("")) + "</summary></details>"
    elif .type == "image" then
      "![image](" + (.image.file.url // .image.external.url // "") + ")"
    else
      ""
    end
  ' 2>/dev/null
}

###############################################################################
# Commands
###############################################################################
cmd_me() {
  local result
  result=$(notion_request GET "/v1/users/me")
  echo "$result" | jq '{name: .name, type: .type, bot: .bot}'
}

cmd_search() {
  local query="$1"
  shift
  local filter_type=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --filter) filter_type="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local body
  body=$(jq -n --arg q "$query" '{query: $q, page_size: 20}')

  if [[ -n "$filter_type" ]]; then
    body=$(echo "$body" | jq --arg ft "$filter_type" '. + {filter: {value: $ft, property: "object"}}')
  fi

  local result
  result=$(notion_request POST "/v1/search" "$body")

  echo "$result" | jq -r '.results[] |
    "[\(.object)] \(.id) — " +
    (if .object == "page" then
      (.properties | to_entries[] | select(.value.type == "title") | .value.title[0].plain_text // "(untitled)")
    elif .object == "database" then
      (.title[0].plain_text // "(untitled)")
    else
      "(unknown)"
    end)
  '
}

cmd_query_db() {
  local db_id="$1"
  shift
  local filter_json="{}" sorts_json="[]"
  local status_val="" due_today=false due_this_week=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) status_val="$2"; shift 2 ;;
      --due-today) due_today=true; shift ;;
      --due-this-week) due_this_week=true; shift ;;
      *) shift ;;
    esac
  done

  local body='{"page_size": 50}'

  # Build filter
  local filters=()

  if [[ -n "$status_val" ]]; then
    filters+=("{\"property\":\"Status\",\"status\":{\"equals\":\"$status_val\"}}")
  fi

  if [[ "$due_today" == "true" ]]; then
    local today
    today=$(date -u +%Y-%m-%d)
    filters+=("{\"property\":\"Due\",\"date\":{\"equals\":\"$today\"}}")
  fi

  if [[ "$due_this_week" == "true" ]]; then
    filters+=("{\"property\":\"Due\",\"date\":{\"this_week\":{}}}")
  fi

  if (( ${#filters[@]} == 1 )); then
    body=$(echo "$body" | jq --argjson f "${filters[0]}" '. + {filter: $f}')
  elif (( ${#filters[@]} > 1 )); then
    local combined
    combined=$(printf '%s,' "${filters[@]}")
    combined="[${combined%,}]"
    body=$(echo "$body" | jq --argjson f "$combined" '. + {filter: {and: $f}}')
  fi

  local result
  result=$(notion_request POST "/v1/databases/${db_id}/query" "$body")

  echo "$result" | jq -r '.results[] | {
    id: .id,
    title: (.properties | to_entries[] | select(.value.type == "title") | .value.title[0].plain_text // "(untitled)"),
    status: (.properties.Status.status.name // "—"),
    priority: (.properties.Priority.select.name // "—"),
    due: (.properties.Due.date.start // "—")
  } | "\(.title) | Status: \(.status) | Priority: \(.priority) | Due: \(.due) | ID: \(.id)"'
}

cmd_create_page() {
  local parent_id="$1" title="$2" content="${3:-}"

  local rich_title
  rich_title=$(jq -n --arg t "$title" '[{type:"text",text:{content:$t}}]')

  local body
  body=$(jq -n \
    --arg pid "$parent_id" \
    --argjson title "$rich_title" \
    '{
      parent: {page_id: $pid},
      properties: {title: {title: $title}}
    }')

  # Add content blocks if provided
  if [[ -n "$content" ]]; then
    local content_blocks
    content_blocks=$(jq -n --arg c "$content" '[{
      object: "block",
      type: "paragraph",
      paragraph: {rich_text: [{type: "text", text: {content: $c}}]}
    }]')
    body=$(echo "$body" | jq --argjson children "$content_blocks" '. + {children: $children}')
  fi

  local result
  result=$(notion_request POST "/v1/pages" "$body")
  echo "$result" | jq '{id: .id, url: .url, created: .created_time}'
}

cmd_create_entry() {
  local db_id="$1"
  shift

  local title="" status="" priority="" due=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --status) status="$2"; shift 2 ;;
      --priority) priority="$2"; shift 2 ;;
      --due) due="$2"; shift 2 ;;
      --author) shift 2 ;;  # Custom property placeholder
      *) shift ;;
    esac
  done

  local props='{}'

  if [[ -n "$title" ]]; then
    props=$(echo "$props" | jq --arg t "$title" '. + {Name: {title: [{type:"text",text:{content:$t}}]}}')
  fi

  if [[ -n "$status" ]]; then
    props=$(echo "$props" | jq --arg s "$status" '. + {Status: {status: {name: $s}}}')
  fi

  if [[ -n "$priority" ]]; then
    props=$(echo "$props" | jq --arg p "$priority" '. + {Priority: {select: {name: $p}}}')
  fi

  if [[ -n "$due" ]]; then
    props=$(echo "$props" | jq --arg d "$due" '. + {Due: {date: {start: $d}}}')
  fi

  local body
  body=$(jq -n --arg dbid "$db_id" --argjson props "$props" '{
    parent: {database_id: $dbid},
    properties: $props
  }')

  local result
  result=$(notion_request POST "/v1/pages" "$body")
  echo "$result" | jq '{id: .id, url: .url, created: .created_time}'
}

cmd_read_page() {
  local page_id="$1"

  # Get page title
  local page_info
  page_info=$(notion_request GET "/v1/pages/${page_id}")
  local title
  title=$(echo "$page_info" | jq -r '.properties | to_entries[] | select(.value.type == "title") | .value.title[0].plain_text // "(untitled)"')
  echo "# $title"
  echo ""

  # Get blocks
  local blocks
  blocks=$(notion_request GET "/v1/blocks/${page_id}/children?page_size=100")
  echo "$blocks" | blocks_to_text
}

cmd_export_md() {
  cmd_read_page "$@"
}

cmd_update_props() {
  local page_id="$1"
  shift
  local props='{}'

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) props=$(echo "$props" | jq --arg s "$2" '. + {Status: {status: {name: $s}}}'); shift 2 ;;
      --priority) props=$(echo "$props" | jq --arg p "$2" '. + {Priority: {select: {name: $p}}}'); shift 2 ;;
      --due) props=$(echo "$props" | jq --arg d "$2" '. + {Due: {date: {start: $d}}}'); shift 2 ;;
      *) shift ;;
    esac
  done

  local body
  body=$(jq -n --argjson props "$props" '{properties: $props}')

  local result
  result=$(notion_request PATCH "/v1/pages/${page_id}" "$body")
  echo "$result" | jq '{id: .id, last_edited: .last_edited_time}'
}

cmd_append() {
  local page_id="$1" text="$2"

  local body
  body=$(jq -n --arg t "$text" '{
    children: [{
      object: "block",
      type: "paragraph",
      paragraph: {rich_text: [{type: "text", text: {content: $t}}]}
    }]
  }')

  notion_request PATCH "/v1/blocks/${page_id}/children" "$body" | jq '{blocks_added: (.results | length)}'
}

cmd_append_todo() {
  local page_id="$1" text="$2"
  shift 2
  local checked=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --checked) checked="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local body
  body=$(jq -n --arg t "$text" --argjson c "$checked" '{
    children: [{
      object: "block",
      type: "to_do",
      to_do: {
        rich_text: [{type: "text", text: {content: $t}}],
        checked: $c
      }
    }]
  }')

  notion_request PATCH "/v1/blocks/${page_id}/children" "$body" | jq '{blocks_added: (.results | length)}'
}

cmd_list_databases() {
  local body='{"filter":{"value":"database","property":"object"},"page_size":50}'
  local result
  result=$(notion_request POST "/v1/search" "$body")

  echo "$result" | jq -r '.results[] |
    "\(.id) — \(.title[0].plain_text // "(untitled)") [\(.properties | keys | join(", "))]"'
}

cmd_get_schema() {
  local db_id="$1"
  local result
  result=$(notion_request GET "/v1/databases/${db_id}")

  echo "$result" | jq '.properties | to_entries[] | {
    name: .key,
    type: .value.type,
    options: (
      if .value.type == "select" then [.value.select.options[].name]
      elif .value.type == "multi_select" then [.value.multi_select.options[].name]
      elif .value.type == "status" then [.value.status.options[].name]
      else null
      end
    )
  }'
}

cmd_export_db() {
  local db_id="$1" output_dir="${2:-.}"
  mkdir -p "$output_dir"

  local result
  result=$(notion_request POST "/v1/databases/${db_id}/query" '{"page_size":100}')

  local ids
  ids=$(echo "$result" | jq -r '.results[].id')

  local count=0
  while IFS= read -r page_id; do
    [[ -z "$page_id" ]] && continue
    local title
    title=$(echo "$result" | jq -r --arg id "$page_id" '.results[] | select(.id == $id) | .properties | to_entries[] | select(.value.type == "title") | .value.title[0].plain_text // "untitled"')
    local safe_title
    safe_title=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
    cmd_read_page "$page_id" > "${output_dir}/${safe_title}.md" 2>/dev/null
    count=$((count + 1))
    echo "Exported: ${title}" >&2
  done <<< "$ids"

  echo "Exported $count pages to $output_dir"
}

cmd_raw() {
  local method="$1" endpoint="$2" body="${3:-}"
  notion_request "$method" "$endpoint" "$body"
}

###############################################################################
# Main
###############################################################################
usage() {
  cat <<EOF
Notion Integration — CLI for the Notion API

Usage: $(basename "$0") <command> [options]

Commands:
  me                              Show current bot user info
  search <query> [--filter page|database]
                                  Search workspace
  list-databases                  List all shared databases
  get-schema <db-id>              Show database property schema
  query-db <db-id> [--status X] [--due-today] [--due-this-week]
                                  Query database entries
  create-page <parent-id> <title> [content]
                                  Create a new page
  create-entry <db-id> --title X [--status X] [--priority X] [--due YYYY-MM-DD]
                                  Create a database entry
  read-page <page-id>             Read page content as text
  export-md <page-id>             Export page as Markdown
  export-db <db-id> [output-dir]  Export all pages in a database
  update-props <page-id> [--status X] [--priority X] [--due X]
                                  Update page properties
  append <page-id> <text>         Append paragraph to page
  append-todo <page-id> <text> [--checked true|false]
                                  Append to-do item to page
  raw <METHOD> <endpoint> [body]  Raw API call

Environment:
  NOTION_API_KEY      Required. Your Notion integration token.
  NOTION_API_VERSION  Optional. Default: 2022-06-28
  NOTION_DEFAULT_DB   Optional. Default database ID for quick queries.

EOF
  exit 0
}

[[ $# -eq 0 ]] && usage

command="$1"
shift

case "$command" in
  me)              cmd_me ;;
  search)          cmd_search "$@" ;;
  list-databases)  cmd_list_databases ;;
  get-schema)      cmd_get_schema "$@" ;;
  query-db)        cmd_query_db "$@" ;;
  create-page)     cmd_create_page "$@" ;;
  create-entry)    cmd_create_entry "$@" ;;
  read-page)       cmd_read_page "$@" ;;
  export-md)       cmd_export_md "$@" ;;
  export-db)       cmd_export_db "$@" ;;
  update-props)    cmd_update_props "$@" ;;
  append)          cmd_append "$@" ;;
  append-todo)     cmd_append_todo "$@" ;;
  raw)             cmd_raw "$@" ;;
  help|--help|-h)  usage ;;
  *)               echo "Unknown command: $command. Run '$(basename "$0") help' for usage." >&2; exit 1 ;;
esac
