#!/bin/bash
# Hetzner Cloud Manager — CLI wrapper for Hetzner Cloud API
# https://docs.hetzner.cloud/

set -euo pipefail

API_BASE="https://api.hetzner.cloud/v1"
CONFIG_DIR="${HOME}/.config/hetzner-cloud"
CONFIG_FILE="${CONFIG_DIR}/config"

# Load config file if exists
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

check_token() {
  if [[ -z "${HETZNER_API_TOKEN:-}" ]]; then
    echo "❌ HETZNER_API_TOKEN not set"
    echo "   export HETZNER_API_TOKEN=\"your-token-here\""
    echo "   Get one at: https://console.hetzner.cloud → Security → API Tokens"
    exit 1
  fi
}

# Defaults
DEFAULT_LOCATION="${HETZNER_DEFAULT_LOCATION:-fsn1}"
DEFAULT_TYPE="${HETZNER_DEFAULT_TYPE:-cx22}"
DEFAULT_IMAGE="${HETZNER_DEFAULT_IMAGE:-ubuntu-24.04}"
DEFAULT_SSH_KEY="${HETZNER_DEFAULT_SSH_KEY:-}"

# ── HTTP helpers ──────────────────────────────────────────────────────────────

api() {
  check_token
  local method="$1" endpoint="$2"
  shift 2
  local response
  response=$(curl -s -w "\n%{http_code}" \
    -X "$method" \
    -H "Authorization: Bearer $HETZNER_API_TOKEN" \
    -H "Content-Type: application/json" \
    "$@" \
    "${API_BASE}${endpoint}")
  
  local body http_code
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')
  
  if [[ "$http_code" -ge 400 ]]; then
    local msg
    msg=$(echo "$body" | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "$body")
    echo "❌ API Error ($http_code): $msg" >&2
    return 1
  fi
  
  echo "$body"
}

api_get()    { api GET    "$@"; }
api_post()   { api POST   "$@"; }
api_put()    { api PUT    "$@"; }
api_delete() { api DELETE "$@"; }

# ── Pagination helper ─────────────────────────────────────────────────────────

api_get_all() {
  local endpoint="$1"
  local page=1 per_page=50
  local all_results="[]"
  local key
  
  # Guess the response key from endpoint
  key=$(echo "$endpoint" | sed 's|^/||' | cut -d'?' -f1 | cut -d'/' -f1)
  
  while true; do
    local sep="?"
    [[ "$endpoint" == *"?"* ]] && sep="&"
    local resp
    resp=$(api_get "${endpoint}${sep}page=${page}&per_page=${per_page}")
    
    local items
    items=$(echo "$resp" | jq ".${key} // []")
    local count
    count=$(echo "$items" | jq 'length')
    
    all_results=$(echo "$all_results" "$items" | jq -s '.[0] + .[1]')
    
    if [[ "$count" -lt "$per_page" ]]; then
      break
    fi
    ((page++))
  done
  
  echo "$all_results"
}

# ── Status ────────────────────────────────────────────────────────────────────

cmd_status() {
  local servers volumes snapshots firewalls
  servers=$(api_get "/servers?per_page=1" | jq '.meta.pagination.total_entries // 0')
  volumes=$(api_get "/volumes?per_page=1" | jq '.meta.pagination.total_entries // 0')
  snapshots=$(api_get "/images?type=snapshot&per_page=1" | jq '.meta.pagination.total_entries // 0')
  firewalls=$(api_get "/firewalls?per_page=1" | jq '.meta.pagination.total_entries // 0')
  
  echo "✅ Connected to Hetzner Cloud"
  echo "Servers: $servers | Volumes: $volumes | Snapshots: $snapshots | Firewalls: $firewalls"
}

# ── Servers ───────────────────────────────────────────────────────────────────

cmd_servers() {
  local subcmd="${1:-list}"
  shift || true
  
  case "$subcmd" in
    list)     cmd_servers_list "$@" ;;
    create)   cmd_servers_create "$@" ;;
    delete)   cmd_servers_delete "$@" ;;
    power-on) cmd_servers_action "poweron" "$@" ;;
    power-off) cmd_servers_action "poweroff" "$@" ;;
    reboot)   cmd_servers_action "reboot" "$@" ;;
    rebuild)  cmd_servers_rebuild "$@" ;;
    metrics)  cmd_servers_metrics "$@" ;;
    *)        echo "Unknown servers command: $subcmd"; exit 1 ;;
  esac
}

cmd_servers_list() {
  local format="table"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format) format="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local data
  data=$(api_get_all "/servers")
  
  if [[ "$format" == "json" ]]; then
    echo "$data" | jq .
    return
  fi
  
  printf "%-8s %-20s %-10s %-10s %-18s %-8s %s\n" "ID" "NAME" "STATUS" "TYPE" "IP" "LOC" "CREATED"
  echo "$data" | jq -r '.[] | [
    (.id | tostring),
    .name,
    .status,
    .server_type.name,
    (.public_net.ipv4.ip // "none"),
    .datacenter.location.name,
    (.created | split("T")[0])
  ] | @tsv' | while IFS=$'\t' read -r id name status type ip loc created; do
    printf "%-8s %-20s %-10s %-10s %-18s %-8s %s\n" "$id" "$name" "$status" "$type" "$ip" "$loc" "$created"
  done
}

cmd_servers_create() {
  local name="" type="$DEFAULT_TYPE" image="$DEFAULT_IMAGE" location="$DEFAULT_LOCATION" ssh_key="$DEFAULT_SSH_KEY"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)     name="$2"; shift 2 ;;
      --type)     type="$2"; shift 2 ;;
      --image)    image="$2"; shift 2 ;;
      --location) location="$2"; shift 2 ;;
      --ssh-key)  ssh_key="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done
  
  if [[ -z "$name" ]]; then
    echo "❌ --name is required"; exit 1
  fi
  
  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg type "$type" \
    --arg image "$image" \
    --arg location "$location" \
    '{
      name: $name,
      server_type: $type,
      image: $image,
      location: $location,
      start_after_create: true
    }')
  
  # Add SSH key if specified
  if [[ -n "$ssh_key" ]]; then
    # Resolve SSH key name to ID
    local key_id
    key_id=$(api_get "/ssh_keys" | jq -r --arg name "$ssh_key" '.ssh_keys[] | select(.name == $name) | .id')
    if [[ -n "$key_id" ]]; then
      payload=$(echo "$payload" | jq --argjson kid "$key_id" '.ssh_keys = [$kid]')
    fi
  fi
  
  local resp
  resp=$(api_post "/servers" -d "$payload")
  
  local sid sname sip stype sloc
  sid=$(echo "$resp" | jq -r '.server.id')
  sname=$(echo "$resp" | jq -r '.server.name')
  sip=$(echo "$resp" | jq -r '.server.public_net.ipv4.ip // "pending"')
  stype=$(echo "$resp" | jq -r '.server.server_type.description // .server.server_type.name')
  sloc=$(echo "$resp" | jq -r '.server.datacenter.location.name')
  
  echo "✅ Server '$sname' created"
  echo "ID: $sid"
  echo "IPv4: $sip"
  echo "Type: $type ($stype)"
  echo "Location: $sloc"
  echo "Image: $image"
}

cmd_servers_delete() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$id" ]]; then echo "❌ --id is required"; exit 1; fi
  
  api_delete "/servers/$id" > /dev/null
  echo "✅ Server $id deleted"
}

cmd_servers_action() {
  local action="$1"; shift
  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$id" ]]; then echo "❌ --id is required"; exit 1; fi
  
  api_post "/servers/$id/actions/$action" -d '{}' > /dev/null
  echo "✅ Server $id: $action initiated"
}

cmd_servers_rebuild() {
  local id="" image=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)    id="$2"; shift 2 ;;
      --image) image="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$id" || -z "$image" ]]; then
    echo "❌ --id and --image are required"; exit 1
  fi
  
  api_post "/servers/$id/actions/rebuild" -d "{\"image\":\"$image\"}" > /dev/null
  echo "✅ Server $id: rebuild with image '$image' initiated"
}

cmd_servers_metrics() {
  local id="" type="cpu" period="1h"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)     id="$2"; shift 2 ;;
      --type)   type="$2"; shift 2 ;;
      --period) period="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$id" ]]; then echo "❌ --id is required"; exit 1; fi
  
  local end_ts start_ts
  end_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  case "$period" in
    1h)  start_ts=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) ;;
    6h)  start_ts=$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-6H +%Y-%m-%dT%H:%M:%SZ) ;;
    24h) start_ts=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-24H +%Y-%m-%dT%H:%M:%SZ) ;;
    7d)  start_ts=$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-7d +%Y-%m-%dT%H:%M:%SZ) ;;
    *)   echo "❌ Unknown period: $period (use 1h, 6h, 24h, 7d)"; exit 1 ;;
  esac
  
  local resp
  resp=$(api_get "/servers/$id/metrics?type=$type&start=$start_ts&end=$end_ts")
  echo "$resp" | jq '.metrics.time_series'
}

# ── Snapshots ─────────────────────────────────────────────────────────────────

cmd_snapshots() {
  local subcmd="${1:-list}"
  shift || true
  
  case "$subcmd" in
    list)    cmd_snapshots_list "$@" ;;
    create)  cmd_snapshots_create "$@" ;;
    delete)  cmd_snapshots_delete "$@" ;;
    cleanup) cmd_snapshots_cleanup "$@" ;;
    *)       echo "Unknown snapshots command: $subcmd"; exit 1 ;;
  esac
}

cmd_snapshots_list() {
  local data
  data=$(api_get_all "/images?type=snapshot")
  
  printf "%-8s %-10s %-25s %-8s %s\n" "ID" "SERVER" "DESCRIPTION" "SIZE" "CREATED"
  echo "$data" | jq -r '.[] | [
    (.id | tostring),
    (.created_from.id // "?" | tostring),
    (.description // "none"),
    ((.image_size // 0 | . * 100 | round / 100 | tostring) + "GB"),
    (.created | split("T")[0])
  ] | @tsv' | while IFS=$'\t' read -r id server desc size created; do
    printf "%-8s %-10s %-25s %-8s %s\n" "$id" "$server" "$desc" "$size" "$created"
  done
}

cmd_snapshots_create() {
  local server="" description=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --server)      server="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$server" ]]; then echo "❌ --server is required"; exit 1; fi
  [[ -z "$description" ]] && description="Snapshot $(date +%Y-%m-%d_%H%M)"
  
  local resp
  resp=$(api_post "/servers/$server/actions/create_image" \
    -d "{\"description\":\"$description\",\"type\":\"snapshot\"}")
  
  local snap_id
  snap_id=$(echo "$resp" | jq -r '.image.id')
  echo "✅ Snapshot created: $description (ID: $snap_id)"
}

cmd_snapshots_delete() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$id" ]]; then echo "❌ --id is required"; exit 1; fi
  
  api_delete "/images/$id" > /dev/null
  echo "✅ Snapshot $id deleted"
}

cmd_snapshots_cleanup() {
  local older_than="7d"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --older-than) older_than="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local days
  days=$(echo "$older_than" | sed 's/d$//')
  local cutoff
  cutoff=$(date -u -d "$days days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-${days}d +%Y-%m-%dT%H:%M:%SZ)
  
  local data deleted=0
  data=$(api_get_all "/images?type=snapshot")
  
  echo "$data" | jq -r --arg cutoff "$cutoff" '.[] | select(.created < $cutoff) | .id' | while read -r id; do
    api_delete "/images/$id" > /dev/null
    echo "🗑️  Deleted snapshot $id"
    ((deleted++))
  done
  
  echo "✅ Cleanup complete"
}

# ── Firewalls ─────────────────────────────────────────────────────────────────

cmd_firewalls() {
  local subcmd="${1:-list}"
  shift || true
  
  case "$subcmd" in
    list)     cmd_firewalls_list "$@" ;;
    create)   cmd_firewalls_create "$@" ;;
    delete)   cmd_firewalls_delete "$@" ;;
    add-rule) cmd_firewalls_add_rule "$@" ;;
    apply)    cmd_firewalls_apply "$@" ;;
    *)        echo "Unknown firewalls command: $subcmd"; exit 1 ;;
  esac
}

cmd_firewalls_list() {
  local data
  data=$(api_get_all "/firewalls")
  
  printf "%-8s %-20s %-8s %s\n" "ID" "NAME" "RULES" "APPLIED TO"
  echo "$data" | jq -r '.[] | [
    (.id | tostring),
    .name,
    (.rules | length | tostring),
    ([.applied_to[]? | .server.id // empty | tostring] | join(",") // "none")
  ] | @tsv' | while IFS=$'\t' read -r id name rules applied; do
    printf "%-8s %-20s %-8s %s\n" "$id" "$name" "$rules" "$applied"
  done
}

cmd_firewalls_create() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$name" ]]; then echo "❌ --name is required"; exit 1; fi
  
  local resp
  resp=$(api_post "/firewalls" -d "{\"name\":\"$name\",\"rules\":[]}")
  local fid
  fid=$(echo "$resp" | jq -r '.firewall.id')
  echo "✅ Firewall '$name' created (ID: $fid)"
}

cmd_firewalls_delete() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in --id) id="$2"; shift 2 ;; *) shift ;; esac
  done
  if [[ -z "$id" ]]; then echo "❌ --id is required"; exit 1; fi
  api_delete "/firewalls/$id" > /dev/null
  echo "✅ Firewall $id deleted"
}

cmd_firewalls_add_rule() {
  local id="" direction="in" protocol="tcp" port="" source="0.0.0.0/0" description=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)          id="$2"; shift 2 ;;
      --direction)   direction="$2"; shift 2 ;;
      --protocol)    protocol="$2"; shift 2 ;;
      --port)        port="$2"; shift 2 ;;
      --source)      source="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$id" || -z "$port" ]]; then
    echo "❌ --id and --port are required"; exit 1
  fi
  
  # Get existing rules
  local existing
  existing=$(api_get "/firewalls/$id" | jq '.firewall.rules')
  
  # Build new rule
  local new_rule
  new_rule=$(jq -n \
    --arg dir "$direction" \
    --arg proto "$protocol" \
    --arg port "$port" \
    --arg desc "$description" \
    '{
      direction: $dir,
      protocol: $proto,
      port: $port,
      description: $desc
    }')
  
  if [[ "$direction" == "in" ]]; then
    new_rule=$(echo "$new_rule" | jq --arg src "$source" '.source_ips = [$src, "::/0"]')
  else
    new_rule=$(echo "$new_rule" | jq --arg dst "$source" '.destination_ips = [$dst, "::/0"]')
  fi
  
  local rules
  rules=$(echo "$existing" | jq --argjson rule "$new_rule" '. + [$rule]')
  
  api_post "/firewalls/$id/actions/set_rules" -d "{\"rules\":$rules}" > /dev/null
  echo "✅ Rule added: $protocol/$port ($description)"
}

cmd_firewalls_apply() {
  local id="" server=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)     id="$2"; shift 2 ;;
      --server) server="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$id" || -z "$server" ]]; then
    echo "❌ --id and --server are required"; exit 1
  fi
  
  api_post "/firewalls/$id/actions/apply_to_resources" \
    -d "{\"apply_to\":[{\"type\":\"server\",\"server\":{\"id\":$server}}]}" > /dev/null
  echo "✅ Firewall $id applied to server $server"
}

# ── Volumes ───────────────────────────────────────────────────────────────────

cmd_volumes() {
  local subcmd="${1:-list}"
  shift || true
  
  case "$subcmd" in
    list)   cmd_volumes_list "$@" ;;
    create) cmd_volumes_create "$@" ;;
    delete) cmd_volumes_delete "$@" ;;
    attach) cmd_volumes_attach "$@" ;;
    detach) cmd_volumes_detach "$@" ;;
    resize) cmd_volumes_resize "$@" ;;
    *)      echo "Unknown volumes command: $subcmd"; exit 1 ;;
  esac
}

cmd_volumes_list() {
  local data
  data=$(api_get_all "/volumes")
  
  printf "%-8s %-20s %-8s %-10s %-8s %s\n" "ID" "NAME" "SIZE" "SERVER" "LOC" "FORMAT"
  echo "$data" | jq -r '.[] | [
    (.id | tostring),
    .name,
    ((.size | tostring) + "GB"),
    (.server // "none" | tostring),
    .location.name,
    (.format // "none")
  ] | @tsv' | while IFS=$'\t' read -r id name size server loc fmt; do
    printf "%-8s %-20s %-8s %-10s %-8s %s\n" "$id" "$name" "$size" "$server" "$loc" "$fmt"
  done
}

cmd_volumes_create() {
  local name="" size=10 location="$DEFAULT_LOCATION" format="ext4"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)     name="$2"; shift 2 ;;
      --size)     size="$2"; shift 2 ;;
      --location) location="$2"; shift 2 ;;
      --format)   format="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$name" ]]; then echo "❌ --name is required"; exit 1; fi
  
  local resp
  resp=$(api_post "/volumes" \
    -d "{\"name\":\"$name\",\"size\":$size,\"location\":\"$location\",\"format\":\"$format\",\"automount\":false}")
  
  local vid linux_device
  vid=$(echo "$resp" | jq -r '.volume.id')
  linux_device=$(echo "$resp" | jq -r '.volume.linux_device // "pending"')
  
  echo "✅ Volume '$name' created (${size}GB, $format)"
  echo "ID: $vid"
  echo "Linux device: $linux_device"
}

cmd_volumes_delete() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in --id) id="$2"; shift 2 ;; *) shift ;; esac
  done
  if [[ -z "$id" ]]; then echo "❌ --id is required"; exit 1; fi
  api_delete "/volumes/$id" > /dev/null
  echo "✅ Volume $id deleted"
}

cmd_volumes_attach() {
  local id="" server=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)     id="$2"; shift 2 ;;
      --server) server="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [[ -z "$id" || -z "$server" ]]; then echo "❌ --id and --server required"; exit 1; fi
  api_post "/volumes/$id/actions/attach" -d "{\"server\":$server,\"automount\":true}" > /dev/null
  echo "✅ Volume $id attached to server $server"
}

cmd_volumes_detach() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in --id) id="$2"; shift 2 ;; *) shift ;; esac
  done
  if [[ -z "$id" ]]; then echo "❌ --id is required"; exit 1; fi
  api_post "/volumes/$id/actions/detach" -d '{}' > /dev/null
  echo "✅ Volume $id detached"
}

cmd_volumes_resize() {
  local id="" size=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)   id="$2"; shift 2 ;;
      --size) size="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [[ -z "$id" || -z "$size" ]]; then echo "❌ --id and --size required"; exit 1; fi
  api_post "/volumes/$id/actions/resize" -d "{\"size\":$size}" > /dev/null
  echo "✅ Volume $id resized to ${size}GB"
}

# ── SSH Keys ──────────────────────────────────────────────────────────────────

cmd_ssh_keys() {
  local subcmd="${1:-list}"
  shift || true
  
  case "$subcmd" in
    list)   cmd_ssh_keys_list "$@" ;;
    create) cmd_ssh_keys_create "$@" ;;
    delete) cmd_ssh_keys_delete "$@" ;;
    *)      echo "Unknown ssh-keys command: $subcmd"; exit 1 ;;
  esac
}

cmd_ssh_keys_list() {
  local data
  data=$(api_get_all "/ssh_keys")
  
  printf "%-8s %-20s %s\n" "ID" "NAME" "FINGERPRINT"
  echo "$data" | jq -r '.[] | [
    (.id | tostring),
    .name,
    .fingerprint
  ] | @tsv' | while IFS=$'\t' read -r id name fp; do
    printf "%-8s %-20s %s\n" "$id" "$name" "$fp"
  done
}

cmd_ssh_keys_create() {
  local name="" key=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --key)  key="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [[ -z "$name" || -z "$key" ]]; then echo "❌ --name and --key required"; exit 1; fi
  
  local resp
  resp=$(api_post "/ssh_keys" -d "{\"name\":\"$name\",\"public_key\":\"$key\"}")
  local kid
  kid=$(echo "$resp" | jq -r '.ssh_key.id')
  echo "✅ SSH key '$name' uploaded (ID: $kid)"
}

cmd_ssh_keys_delete() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in --id) id="$2"; shift 2 ;; *) shift ;; esac
  done
  if [[ -z "$id" ]]; then echo "❌ --id is required"; exit 1; fi
  api_delete "/ssh_keys/$id" > /dev/null
  echo "✅ SSH key $id deleted"
}

# ── Server Types ──────────────────────────────────────────────────────────────

cmd_types() {
  local location=""
  while [[ $# -gt 0 ]]; do
    case "$1" in --location) location="$2"; shift 2 ;; *) shift ;; esac
  done
  
  local data
  data=$(api_get_all "/server_types")
  
  printf "%-10s %-5s %-8s %-8s %s\n" "TYPE" "vCPU" "RAM" "DISK" "PRICE/mo"
  echo "$data" | jq -r '.[] | [
    .name,
    (.cores | tostring),
    ((.memory | tostring) + "GB"),
    ((.disk | tostring) + "GB"),
    "€" + ((.prices[0].price_monthly.gross // "?") | tostring)
  ] | @tsv' | sort | while IFS=$'\t' read -r type vcpu ram disk price; do
    printf "%-10s %-5s %-8s %-8s %s\n" "$type" "$vcpu" "$ram" "$disk" "$price"
  done
}

# ── Locations ─────────────────────────────────────────────────────────────────

cmd_locations() {
  local data
  data=$(api_get_all "/locations")
  
  printf "%-6s %-15s %-15s %s\n" "ID" "NAME" "CITY" "COUNTRY"
  echo "$data" | jq -r '.[] | [
    .name,
    .description,
    .city,
    .country
  ] | @tsv' | while IFS=$'\t' read -r name desc city country; do
    printf "%-6s %-15s %-15s %s\n" "$name" "$desc" "$city" "$country"
  done
}

# ── Cost Estimate ─────────────────────────────────────────────────────────────

cmd_cost() {
  echo "Monthly Cost Estimate:"
  echo ""
  printf "%-20s %-10s %-8s %s\n" "RESOURCE" "TYPE" "COUNT" "COST/mo"
  echo "────────────────────────────────────────────────────"
  
  local total=0
  
  # Servers
  local servers
  servers=$(api_get_all "/servers")
  echo "$servers" | jq -r 'group_by(.server_type.name) | .[] | [
    .[0].server_type.name,
    (length | tostring)
  ] | @tsv' | while read -r type count; do
    printf "%-20s %-10s %-8s %s\n" "Servers" "$type" "$count" "(see types)"
  done
  
  # Volumes
  local volumes total_vol_gb=0
  volumes=$(api_get_all "/volumes")
  total_vol_gb=$(echo "$volumes" | jq '[.[].size] | add // 0')
  if [[ "$total_vol_gb" -gt 0 ]]; then
    local vol_count vol_cost
    vol_count=$(echo "$volumes" | jq 'length')
    vol_cost=$(echo "scale=2; $total_vol_gb * 0.0440" | bc 2>/dev/null || echo "?")
    printf "%-20s %-10s %-8s €%s\n" "Volumes" "${total_vol_gb}GB" "$vol_count" "$vol_cost"
  fi
  
  # Snapshots
  local snapshots snap_size
  snapshots=$(api_get_all "/images?type=snapshot")
  snap_size=$(echo "$snapshots" | jq '[.[].image_size // 0] | add // 0')
  if (( $(echo "$snap_size > 0" | bc -l 2>/dev/null || echo "0") )); then
    local snap_count snap_cost
    snap_count=$(echo "$snapshots" | jq 'length')
    snap_cost=$(echo "scale=2; $snap_size * 0.0200" | bc 2>/dev/null || echo "?")
    printf "%-20s %-10s %-8s €%s\n" "Snapshots" "${snap_size}GB" "$snap_count" "$snap_cost"
  fi
  
  echo "────────────────────────────────────────────────────"
  echo "(Run 'hetzner.sh types' for per-server pricing)"
}

# ── Main Router ───────────────────────────────────────────────────────────────

main() {
  local cmd="${1:-help}"
  shift || true
  
  case "$cmd" in
    status)    cmd_status "$@" ;;
    servers)   cmd_servers "$@" ;;
    snapshots) cmd_snapshots "$@" ;;
    firewalls) cmd_firewalls "$@" ;;
    volumes)   cmd_volumes "$@" ;;
    ssh-keys)  cmd_ssh_keys "$@" ;;
    types)     cmd_types "$@" ;;
    locations) cmd_locations "$@" ;;
    cost)      cmd_cost "$@" ;;
    help|--help|-h)
      echo "Hetzner Cloud Manager"
      echo ""
      echo "Usage: hetzner.sh <command> [subcommand] [options]"
      echo ""
      echo "Commands:"
      echo "  status              Show account overview"
      echo "  servers             Manage servers (list|create|delete|power-on|power-off|reboot|rebuild|metrics)"
      echo "  snapshots           Manage snapshots (list|create|delete|cleanup)"
      echo "  firewalls           Manage firewalls (list|create|delete|add-rule|apply)"
      echo "  volumes             Manage volumes (list|create|delete|attach|detach|resize)"
      echo "  ssh-keys            Manage SSH keys (list|create|delete)"
      echo "  types               List server types and pricing"
      echo "  locations           List datacenters"
      echo "  cost                Estimate monthly cost"
      echo ""
      echo "Environment: HETZNER_API_TOKEN (required)"
      ;;
    *)
      echo "❌ Unknown command: $cmd"
      echo "Run: hetzner.sh help"
      exit 1
      ;;
  esac
}

main "$@"
