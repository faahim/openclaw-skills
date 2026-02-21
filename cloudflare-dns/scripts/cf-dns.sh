#!/bin/bash
# Cloudflare DNS Manager — Full CLI for DNS record management
# Dependencies: curl, jq, dig (optional)
set -euo pipefail

VERSION="1.0.0"
CF_API="https://api.cloudflare.com/client/v4"

# --- Auth ---
auth_header() {
  if [[ -n "${CF_API_TOKEN:-}" ]]; then
    echo "Authorization: Bearer $CF_API_TOKEN"
  elif [[ -n "${CF_API_KEY:-}" && -n "${CF_EMAIL:-}" ]]; then
    # Global API key returns two headers; caller handles
    echo "X-Auth-Key: $CF_API_KEY"
  else
    echo "ERROR: Set CF_API_TOKEN or (CF_API_KEY + CF_EMAIL)" >&2
    exit 1
  fi
}

cf_curl() {
  local method="$1" endpoint="$2"
  shift 2
  local url="${CF_API}${endpoint}"
  local auth
  auth=$(auth_header)

  local -a headers=(-H "Content-Type: application/json" -H "$auth")
  if [[ -n "${CF_EMAIL:-}" && -n "${CF_API_KEY:-}" ]]; then
    headers+=(-H "X-Auth-Email: $CF_EMAIL")
  fi

  curl -s -X "$method" "$url" "${headers[@]}" "$@"
}

check_success() {
  local resp="$1"
  local ok
  ok=$(echo "$resp" | jq -r '.success // false')
  if [[ "$ok" != "true" ]]; then
    echo "ERROR: API call failed:" >&2
    echo "$resp" | jq -r '.errors[]? | "  [\(.code)] \(.message)"' >&2
    return 1
  fi
}

# --- Zone helpers ---
get_zone_id() {
  local zone_name="$1"
  local resp
  resp=$(cf_curl GET "/zones?name=$zone_name&status=active")
  check_success "$resp" || return 1
  local zid
  zid=$(echo "$resp" | jq -r '.result[0].id // empty')
  if [[ -z "$zid" ]]; then
    echo "ERROR: Zone '$zone_name' not found" >&2
    return 1
  fi
  echo "$zid"
}

get_record_id() {
  local zone_id="$1" rec_type="$2" rec_name="$3"
  local resp
  resp=$(cf_curl GET "/zones/$zone_id/dns_records?type=$rec_type&name=$rec_name")
  check_success "$resp" || return 1
  echo "$resp" | jq -r '.result[0].id // empty'
}

# Resolve short name to FQDN
fqdn() {
  local name="$1" zone="$2"
  if [[ "$name" == "@" || "$name" == "$zone" ]]; then
    echo "$zone"
  elif [[ "$name" == *"$zone" ]]; then
    echo "$name"
  else
    echo "${name}.${zone}"
  fi
}

# --- Commands ---

cmd_whoami() {
  local resp
  resp=$(cf_curl GET "/user/tokens/verify")
  check_success "$resp" || return 1
  echo "✅ Token is valid"
  echo "$resp" | jq -r '"   Status: \(.result.status)\n   Expires: \(.result.expires_on // "never")"'
}

cmd_zones() {
  local resp
  resp=$(cf_curl GET "/zones?per_page=50")
  check_success "$resp" || return 1
  printf "%-36s %-30s %s\n" "ZONE ID" "NAME" "STATUS"
  echo "$resp" | jq -r '.result[] | "\(.id)  \(.name)  \(.status)"' | while read -r id name status; do
    printf "%-36s %-30s %s\n" "$id" "$name" "$status"
  done
}

cmd_list() {
  local zone_name="${1:?Usage: cf-dns.sh list <zone>}"
  local zone_id
  zone_id=$(get_zone_id "$zone_name") || return 1

  local page=1 per_page=100
  printf "%-6s %-35s %-40s %-6s %s\n" "TYPE" "NAME" "CONTENT" "TTL" "PROXIED"

  while true; do
    local resp
    resp=$(cf_curl GET "/zones/$zone_id/dns_records?per_page=$per_page&page=$page")
    check_success "$resp" || return 1

    local count
    count=$(echo "$resp" | jq '.result | length')
    [[ "$count" -eq 0 ]] && break

    echo "$resp" | jq -r '.result[] | [.type, .name, .content, (if .ttl == 1 then "auto" else (.ttl|tostring) end), (if .proxied then "✅" else "❌" end)] | @tsv' | while IFS=$'\t' read -r type name content ttl proxied; do
      printf "%-6s %-35s %-40s %-6s %s\n" "$type" "$name" "${content:0:40}" "$ttl" "$proxied"
    done

    local total_pages
    total_pages=$(echo "$resp" | jq '.result_info.total_pages // 1')
    [[ "$page" -ge "$total_pages" ]] && break
    ((page++))
  done
}

cmd_add() {
  local zone_name="${1:?Usage: cf-dns.sh add <zone> <type> <name> <content> [flags]}"
  local rec_type="${2:?}" rec_name="${3:?}" content="${4:?}"
  shift 4

  local proxied=false ttl=1 priority=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --proxied) proxied=true; shift ;;
      --no-proxy) proxied=false; shift ;;
      --ttl) ttl="$2"; shift 2 ;;
      --priority) priority="$2"; shift 2 ;;
      *) echo "Unknown flag: $1" >&2; return 1 ;;
    esac
  done

  local zone_id
  zone_id=$(get_zone_id "$zone_name") || return 1
  local full_name
  full_name=$(fqdn "$rec_name" "$zone_name")

  local payload
  payload=$(jq -n \
    --arg type "$rec_type" \
    --arg name "$full_name" \
    --arg content "$content" \
    --argjson ttl "$ttl" \
    --argjson proxied "$proxied" \
    '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied}')

  if [[ -n "$priority" ]]; then
    payload=$(echo "$payload" | jq --argjson p "$priority" '. + {priority: $p}')
  fi

  local resp
  resp=$(cf_curl POST "/zones/$zone_id/dns_records" -d "$payload")
  check_success "$resp" || return 1

  echo "✅ Created $rec_type record: $full_name → $content"
  [[ "$proxied" == "true" ]] && echo "   Proxied: ✅"
}

cmd_update() {
  local zone_name="${1:?Usage: cf-dns.sh update <zone> <type> <name> <content> [flags]}"
  local rec_type="${2:?}" rec_name="${3:?}" content="${4:?}"
  shift 4

  local proxied="" ttl=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --proxied) proxied=true; shift ;;
      --no-proxy) proxied=false; shift ;;
      --ttl) ttl="$2"; shift 2 ;;
      *) echo "Unknown flag: $1" >&2; return 1 ;;
    esac
  done

  local zone_id
  zone_id=$(get_zone_id "$zone_name") || return 1
  local full_name
  full_name=$(fqdn "$rec_name" "$zone_name")

  local rec_id
  rec_id=$(get_record_id "$zone_id" "$rec_type" "$full_name")
  if [[ -z "$rec_id" ]]; then
    echo "ERROR: No $rec_type record found for $full_name" >&2
    return 1
  fi

  # Build patch payload
  local payload
  payload=$(jq -n --arg type "$rec_type" --arg name "$full_name" --arg content "$content" \
    '{type: $type, name: $name, content: $content}')

  [[ -n "$proxied" ]] && payload=$(echo "$payload" | jq --argjson p "$proxied" '. + {proxied: $p}')
  [[ -n "$ttl" ]] && payload=$(echo "$payload" | jq --argjson t "$ttl" '. + {ttl: $t}')

  local resp
  resp=$(cf_curl PUT "/zones/$zone_id/dns_records/$rec_id" -d "$payload")
  check_success "$resp" || return 1

  echo "✅ Updated $rec_type record: $full_name → $content"
}

cmd_delete() {
  local zone_name="${1:?Usage: cf-dns.sh delete <zone> <type> <name>}"
  local rec_type="${2:?}" rec_name="${3:?}"

  local zone_id
  zone_id=$(get_zone_id "$zone_name") || return 1
  local full_name
  full_name=$(fqdn "$rec_name" "$zone_name")

  local rec_id
  rec_id=$(get_record_id "$zone_id" "$rec_type" "$full_name")
  if [[ -z "$rec_id" ]]; then
    echo "ERROR: No $rec_type record found for $full_name" >&2
    return 1
  fi

  local resp
  resp=$(cf_curl DELETE "/zones/$zone_id/dns_records/$rec_id")
  check_success "$resp" || return 1

  echo "✅ Deleted $rec_type record: $full_name"
}

cmd_purge() {
  local zone_name="${1:?Usage: cf-dns.sh purge <zone> [--all|--urls ...|--tags ...]}"
  shift

  local zone_id
  zone_id=$(get_zone_id "$zone_name") || return 1

  local payload='{}'
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) payload='{"purge_everything":true}'; shift ;;
      --urls) IFS=',' read -ra urls <<< "$2"
              payload=$(jq -n --argjson f "$(printf '%s\n' "${urls[@]}" | jq -R . | jq -s .)" '{files: $f}')
              shift 2 ;;
      --tags) IFS=',' read -ra tags <<< "$2"
              payload=$(jq -n --argjson t "$(printf '%s\n' "${tags[@]}" | jq -R . | jq -s .)" '{tags: $t}')
              shift 2 ;;
      *) echo "Unknown flag: $1" >&2; return 1 ;;
    esac
  done

  local resp
  resp=$(cf_curl POST "/zones/$zone_id/purge_cache" -d "$payload")
  check_success "$resp" || return 1

  echo "✅ Cache purged for $zone_name"
}

cmd_export() {
  local zone_name="${1:?Usage: cf-dns.sh export <zone> [--format json|bind]}"
  local format="${2:---format}"
  [[ "$format" == "--format" ]] && format="${3:-json}"

  local zone_id
  zone_id=$(get_zone_id "$zone_name") || return 1

  if [[ "$format" == "bind" ]]; then
    local resp
    resp=$(cf_curl GET "/zones/$zone_id/dns_records/export")
    echo "$resp"
  else
    local resp
    resp=$(cf_curl GET "/zones/$zone_id/dns_records?per_page=500")
    check_success "$resp" || return 1
    echo "$resp" | jq '.result | map({type, name, content, ttl, proxied, priority})'
  fi
}

cmd_import() {
  local zone_name="${1:?Usage: cf-dns.sh import <zone> <file.json>}"
  local file="${2:?}"

  if [[ ! -f "$file" ]]; then
    echo "ERROR: File not found: $file" >&2
    return 1
  fi

  local zone_id
  zone_id=$(get_zone_id "$zone_name") || return 1

  local count=0
  while IFS= read -r record; do
    local rec_type name content ttl proxied priority
    rec_type=$(echo "$record" | jq -r '.type')
    name=$(echo "$record" | jq -r '.name')
    content=$(echo "$record" | jq -r '.content')
    ttl=$(echo "$record" | jq -r '.ttl')
    proxied=$(echo "$record" | jq -r '.proxied')
    priority=$(echo "$record" | jq -r '.priority // empty')

    local payload
    payload=$(jq -n \
      --arg type "$rec_type" --arg name "$name" --arg content "$content" \
      --argjson ttl "$ttl" --argjson proxied "$proxied" \
      '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied}')

    [[ -n "$priority" ]] && payload=$(echo "$payload" | jq --argjson p "$priority" '. + {priority: $p}')

    cf_curl POST "/zones/$zone_id/dns_records" -d "$payload" > /dev/null 2>&1
    ((count++))
    echo "  Imported: $rec_type $name → $content"
  done < <(jq -c '.[]' "$file")

  echo "✅ Imported $count records into $zone_name"
}

cmd_check() {
  local zone_name="${1:?Usage: cf-dns.sh check <zone> <type> <name>}"
  local rec_type="${2:?}" rec_name="${3:?}"
  local full_name
  full_name=$(fqdn "$rec_name" "$zone_name")

  local qtype="$rec_type"

  echo "Checking $full_name ($rec_type record)..."
  echo ""

  local -a servers=("8.8.8.8:Google DNS" "1.1.1.1:Cloudflare" "208.67.222.222:OpenDNS" "9.9.9.9:Quad9")

  for entry in "${servers[@]}"; do
    local server="${entry%%:*}" label="${entry##*:}"
    local result
    if command -v dig &>/dev/null; then
      result=$(dig +short "$full_name" "$qtype" @"$server" 2>/dev/null | head -1)
    else
      result=$(host -t "$qtype" "$full_name" "$server" 2>/dev/null | tail -1 | awk '{print $NF}')
    fi
    if [[ -n "$result" ]]; then
      printf "%-25s %s ✅\n" "$label ($server):" "$result"
    else
      printf "%-25s %s ❌\n" "$label ($server):" "(no response)"
    fi
  done
}

cmd_dyndns() {
  local zone_name="${1:?Usage: cf-dns.sh dyndns <zone> <name>}"
  local rec_name="${2:?}"
  local full_name
  full_name=$(fqdn "$rec_name" "$zone_name")

  # Get current public IP
  local current_ip
  current_ip=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me)

  if [[ -z "$current_ip" ]]; then
    echo "ERROR: Could not determine public IP" >&2
    return 1
  fi

  local zone_id
  zone_id=$(get_zone_id "$zone_name") || return 1

  # Check existing record
  local rec_id existing_ip
  local resp
  resp=$(cf_curl GET "/zones/$zone_id/dns_records?type=A&name=$full_name")
  rec_id=$(echo "$resp" | jq -r '.result[0].id // empty')
  existing_ip=$(echo "$resp" | jq -r '.result[0].content // empty')

  if [[ "$existing_ip" == "$current_ip" ]]; then
    echo "✅ IP unchanged: $full_name → $current_ip"
    return 0
  fi

  if [[ -n "$rec_id" ]]; then
    # Update existing
    local payload
    payload=$(jq -n --arg name "$full_name" --arg ip "$current_ip" \
      '{type: "A", name: $name, content: $ip, ttl: 1, proxied: false}')
    resp=$(cf_curl PUT "/zones/$zone_id/dns_records/$rec_id" -d "$payload")
    check_success "$resp" || return 1
    echo "✅ Updated $full_name: $existing_ip → $current_ip"
  else
    # Create new
    local payload
    payload=$(jq -n --arg name "$full_name" --arg ip "$current_ip" \
      '{type: "A", name: $name, content: $ip, ttl: 1, proxied: false}')
    resp=$(cf_curl POST "/zones/$zone_id/dns_records" -d "$payload")
    check_success "$resp" || return 1
    echo "✅ Created $full_name → $current_ip"
  fi
}

cmd_analytics() {
  local zone_name="${1:?Usage: cf-dns.sh analytics <zone> [--period 24h|7d|30d]}"
  shift
  local period="24h"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --period) period="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local zone_id
  zone_id=$(get_zone_id "$zone_name") || return 1

  local since
  case "$period" in
    24h) since="-1440" ;;
    7d)  since="-10080" ;;
    30d) since="-43200" ;;
    *)   since="-1440" ;;
  esac

  local resp
  resp=$(cf_curl GET "/zones/$zone_id/analytics/dashboard?since=$since&continuous=true")
  check_success "$resp" || return 1

  echo "📊 Zone Analytics: $zone_name (last $period)"
  echo ""
  echo "$resp" | jq -r '
    .result.totals |
    "Requests:      \(.requests.all // 0)
Cached:        \(.requests.cached // 0)
Uncached:      \(.requests.uncached // 0)
Bandwidth:     \((.bandwidth.all // 0) / 1048576 | floor)MB
Threats:       \(.threats.all // 0)
Page Views:    \(.pageviews.all // 0)"'
}

# --- Main ---
cmd="${1:-help}"
shift 2>/dev/null || true

case "$cmd" in
  whoami)    cmd_whoami "$@" ;;
  zones)     cmd_zones "$@" ;;
  list)      cmd_list "$@" ;;
  add)       cmd_add "$@" ;;
  update)    cmd_update "$@" ;;
  delete)    cmd_delete "$@" ;;
  purge)     cmd_purge "$@" ;;
  export)    cmd_export "$@" ;;
  import)    cmd_import "$@" ;;
  check)     cmd_check "$@" ;;
  dyndns)    cmd_dyndns "$@" ;;
  analytics) cmd_analytics "$@" ;;
  version)   echo "cf-dns $VERSION" ;;
  help|*)
    cat <<EOF
Cloudflare DNS Manager v$VERSION

Usage: cf-dns.sh <command> [args]

Commands:
  whoami                              Verify API token
  zones                               List all zones
  list <zone>                         List DNS records
  add <zone> <type> <name> <content>  Add record [--proxied] [--ttl N] [--priority N]
  update <zone> <type> <name> <content>  Update record [--proxied|--no-proxy] [--ttl N]
  delete <zone> <type> <name>         Delete record
  purge <zone>                        Purge cache [--all|--urls ..|--tags ..]
  export <zone> [--format json|bind]  Export records
  import <zone> <file.json>           Import records from JSON
  check <zone> <type> <name>          Check DNS propagation
  dyndns <zone> <name>                Dynamic DNS update (current IP)
  analytics <zone> [--period 24h]     Zone analytics

Environment:
  CF_API_TOKEN    Cloudflare API token (recommended)
  CF_API_KEY      Global API key (legacy)
  CF_EMAIL        Account email (with CF_API_KEY)
EOF
    ;;
esac
