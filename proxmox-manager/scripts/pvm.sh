#!/bin/bash
# Proxmox VE Manager (pvm.sh) — CLI for Proxmox REST API
# Requires: curl, jq, bash 4.0+

set -euo pipefail

# --- Config ---
CONFIG_FILE="${PROXMOX_CONFIG:-$HOME/.proxmox-manager.env}"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

PROXMOX_HOST="${PROXMOX_HOST:-}"
PROXMOX_USER="${PROXMOX_USER:-root@pam}"
PROXMOX_PASSWORD="${PROXMOX_PASSWORD:-}"
PROXMOX_TOKEN_ID="${PROXMOX_TOKEN_ID:-}"
PROXMOX_TOKEN_SECRET="${PROXMOX_TOKEN_SECRET:-}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
PROXMOX_VERIFY_SSL="${PROXMOX_VERIFY_SSL:-false}"
JSON_OUTPUT=false

# --- Helpers ---
die() { echo "❌ $*" >&2; exit 1; }
info() { [[ "$JSON_OUTPUT" == "false" ]] && echo "$*"; }

curl_opts() {
  local opts=("-s" "-f")
  [[ "$PROXMOX_VERIFY_SSL" == "false" ]] && opts+=("-k")
  echo "${opts[@]}"
}

# Auth: prefer API token, fallback to ticket
TICKET=""
CSRF=""

auth_header() {
  if [[ -n "$PROXMOX_TOKEN_ID" && -n "$PROXMOX_TOKEN_SECRET" ]]; then
    echo "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}"
  else
    [[ -z "$TICKET" ]] && get_ticket
    echo "Cookie: PVEAuthCookie=$TICKET"
  fi
}

csrf_header() {
  if [[ -n "$PROXMOX_TOKEN_ID" ]]; then
    echo "X-Noop: token"
  else
    [[ -z "$CSRF" ]] && get_ticket
    echo "CSRFPreventionToken: $CSRF"
  fi
}

get_ticket() {
  [[ -z "$PROXMOX_PASSWORD" ]] && die "No token or password configured. Edit $CONFIG_FILE"
  local resp
  resp=$(curl $(curl_opts) -d "username=$PROXMOX_USER&password=$PROXMOX_PASSWORD" \
    "$PROXMOX_HOST/api2/json/access/ticket" 2>/dev/null) || die "Auth failed. Check host/credentials."
  TICKET=$(echo "$resp" | jq -r '.data.ticket')
  CSRF=$(echo "$resp" | jq -r '.data.CSRFPreventionToken')
  [[ "$TICKET" == "null" || -z "$TICKET" ]] && die "Authentication failed"
}

api_get() {
  local path="$1"
  curl $(curl_opts) -H "$(auth_header)" "$PROXMOX_HOST/api2/json${path}" 2>/dev/null || die "API GET $path failed"
}

api_post() {
  local path="$1"; shift
  curl $(curl_opts) -X POST -H "$(auth_header)" -H "$(csrf_header)" "$@" \
    "$PROXMOX_HOST/api2/json${path}" 2>/dev/null || die "API POST $path failed"
}

api_delete() {
  local path="$1"
  curl $(curl_opts) -X DELETE -H "$(auth_header)" -H "$(csrf_header)" \
    "$PROXMOX_HOST/api2/json${path}" 2>/dev/null || die "API DELETE $path failed"
}

detect_type() {
  local vmid="$1"
  # Try qemu first
  local resp
  resp=$(curl $(curl_opts) -o /dev/null -w "%{http_code}" -H "$(auth_header)" \
    "$PROXMOX_HOST/api2/json/nodes/$PROXMOX_NODE/qemu/$vmid/status/current" 2>/dev/null)
  if [[ "$resp" == "200" ]]; then echo "qemu"; return; fi
  resp=$(curl $(curl_opts) -o /dev/null -w "%{http_code}" -H "$(auth_header)" \
    "$PROXMOX_HOST/api2/json/nodes/$PROXMOX_NODE/lxc/$vmid/status/current" 2>/dev/null)
  if [[ "$resp" == "200" ]]; then echo "lxc"; return; fi
  die "VM/CT $vmid not found on node $PROXMOX_NODE"
}

human_bytes() {
  local bytes=$1
  if (( bytes >= 1073741824 )); then
    echo "$(echo "scale=1; $bytes/1073741824" | bc) GB"
  elif (( bytes >= 1048576 )); then
    echo "$(echo "scale=0; $bytes/1048576" | bc) MB"
  else
    echo "${bytes} B"
  fi
}

human_uptime() {
  local secs=$1
  local days=$((secs / 86400))
  local hours=$(( (secs % 86400) / 3600 ))
  local mins=$(( (secs % 3600) / 60 ))
  echo "${days}d ${hours}h ${mins}m"
}

# --- Commands ---

cmd_status() {
  [[ -z "$PROXMOX_HOST" ]] && die "PROXMOX_HOST not set. Configure $CONFIG_FILE"
  local version node_data
  version=$(api_get "/version" | jq -r '.data.version')
  node_data=$(api_get "/nodes/$PROXMOX_NODE/status")

  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "$node_data" | jq '.data | {
      cpu_usage: (.cpu * 100 | floor / 100),
      memory_used: .memory.used,
      memory_total: .memory.total,
      uptime: .uptime,
      pveversion: .pveversion
    }'
    return
  fi

  local cpu mem_used mem_total uptime_s
  cpu=$(echo "$node_data" | jq -r '.data.cpu * 100' | cut -d. -f1)
  mem_used=$(echo "$node_data" | jq -r '.data.memory.used')
  mem_total=$(echo "$node_data" | jq -r '.data.memory.total')
  uptime_s=$(echo "$node_data" | jq -r '.data.uptime')

  echo "✅ Connected to Proxmox VE $version at $PROXMOX_HOST"
  echo "Node: $PROXMOX_NODE | CPU: ${cpu}% | RAM: $(human_bytes "$mem_used") / $(human_bytes "$mem_total") | Uptime: $(human_uptime "$uptime_s")"
}

cmd_list() {
  local status_filter="" tag_filter=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --status) status_filter="$2"; shift 2 ;;
      --tag) tag_filter="$2"; shift 2 ;;
      --json) JSON_OUTPUT=true; shift ;;
      *) shift ;;
    esac
  done

  local qemu_data lxc_data
  qemu_data=$(api_get "/nodes/$PROXMOX_NODE/qemu" | jq '.data // []')
  lxc_data=$(api_get "/nodes/$PROXMOX_NODE/lxc" | jq '.data // []')

  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "$qemu_data $lxc_data" | jq -s 'add'
    return
  fi

  printf "%-6s %-5s %-20s %-10s %-4s %-10s %-8s\n" "ID" "TYPE" "NAME" "STATUS" "CPU" "RAM" "DISK"
  echo "----------------------------------------------------------------------"

  echo "$qemu_data" | jq -r '.[] | [.vmid, "qemu", .name, .status, (.cpus // 0), (.maxmem // 0), (.maxdisk // 0)] | @tsv' | \
  while IFS=$'\t' read -r vmid type name status cpus maxmem maxdisk; do
    [[ -n "$status_filter" && "$status" != "$status_filter" ]] && continue
    printf "%-6s %-5s %-20s %-10s %-4s %-10s %-8s\n" "$vmid" "$type" "$name" "$status" "$cpus" "$(human_bytes "$maxmem")" "$(human_bytes "$maxdisk")"
  done

  echo "$lxc_data" | jq -r '.[] | [.vmid, "lxc", .name, .status, (.cpus // 0), (.maxmem // 0), (.maxdisk // 0)] | @tsv' | \
  while IFS=$'\t' read -r vmid type name status cpus maxmem maxdisk; do
    [[ -n "$status_filter" && "$status" != "$status_filter" ]] && continue
    printf "%-6s %-5s %-20s %-10s %-4s %-10s %-8s\n" "$vmid" "$type" "$name" "$status" "$cpus" "$(human_bytes "$maxmem")" "$(human_bytes "$maxdisk")"
  done
}

cmd_start() {
  local vmid="$1"
  local type=$(detect_type "$vmid")
  api_post "/nodes/$PROXMOX_NODE/$type/$vmid/status/start" > /dev/null
  info "✅ $type/$vmid starting..."
}

cmd_stop() {
  local vmid="$1"; shift
  local force=false
  while [[ $# -gt 0 ]]; do
    case $1 in --force) force=true; shift ;; *) shift ;; esac
  done
  local type=$(detect_type "$vmid")
  if [[ "$force" == "true" ]]; then
    api_post "/nodes/$PROXMOX_NODE/$type/$vmid/status/stop" > /dev/null
    info "⚡ $type/$vmid force stopping..."
  else
    api_post "/nodes/$PROXMOX_NODE/$type/$vmid/status/shutdown" > /dev/null
    info "🔌 $type/$vmid shutting down..."
  fi
}

cmd_restart() {
  local vmid="$1"
  local type=$(detect_type "$vmid")
  api_post "/nodes/$PROXMOX_NODE/$type/$vmid/status/reboot" > /dev/null
  info "🔄 $type/$vmid restarting..."
}

cmd_suspend() {
  local vmid="$1"
  local type=$(detect_type "$vmid")
  api_post "/nodes/$PROXMOX_NODE/$type/$vmid/status/suspend" > /dev/null
  info "⏸️  $type/$vmid suspended"
}

cmd_resume() {
  local vmid="$1"
  local type=$(detect_type "$vmid")
  api_post "/nodes/$PROXMOX_NODE/$type/$vmid/status/resume" > /dev/null
  info "▶️  $type/$vmid resumed"
}

cmd_snapshot() {
  local vmid="$1"; shift
  local snap_name="snap-$(date +%Y%m%d-%H%M%S)" description="Created by pvm.sh"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) snap_name="$2"; shift 2 ;;
      --desc) description="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local type=$(detect_type "$vmid")
  api_post "/nodes/$PROXMOX_NODE/$type/$vmid/snapshot" \
    -d "snapname=$snap_name" -d "description=$description" > /dev/null
  info "📸 Snapshot '$snap_name' created for $type/$vmid"
}

cmd_snapshots() {
  local vmid="$1"
  local type=$(detect_type "$vmid")
  local data
  data=$(api_get "/nodes/$PROXMOX_NODE/$type/$vmid/snapshot")

  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "$data" | jq '.data'
    return
  fi

  printf "%-25s %-22s %-30s\n" "NAME" "DATE" "DESCRIPTION"
  echo "-------------------------------------------------------------------"
  echo "$data" | jq -r '.data[] | select(.name != "current") | [.name, (.snaptime // 0 | tostring), (.description // "")] | @tsv' | \
  while IFS=$'\t' read -r name snaptime desc; do
    local date_str=""
    [[ "$snaptime" != "0" ]] && date_str=$(date -d "@$snaptime" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$snaptime")
    printf "%-25s %-22s %-30s\n" "$name" "$date_str" "$desc"
  done
}

cmd_rollback() {
  local vmid="$1"; shift
  local snap_name=""
  while [[ $# -gt 0 ]]; do
    case $1 in --name) snap_name="$2"; shift 2 ;; *) shift ;; esac
  done
  [[ -z "$snap_name" ]] && die "Usage: pvm.sh rollback <vmid> --name <snapshot>"
  local type=$(detect_type "$vmid")
  api_post "/nodes/$PROXMOX_NODE/$type/$vmid/snapshot/$snap_name/rollback" > /dev/null
  info "⏪ Rolled back $type/$vmid to snapshot '$snap_name'"
}

cmd_snap_delete() {
  local vmid="$1"; shift
  local snap_name=""
  while [[ $# -gt 0 ]]; do
    case $1 in --name) snap_name="$2"; shift 2 ;; *) shift ;; esac
  done
  [[ -z "$snap_name" ]] && die "Usage: pvm.sh snap-delete <vmid> --name <snapshot>"
  local type=$(detect_type "$vmid")
  api_delete "/nodes/$PROXMOX_NODE/$type/$vmid/snapshot/$snap_name" > /dev/null
  info "🗑️  Snapshot '$snap_name' deleted from $type/$vmid"
}

cmd_snap_prune() {
  local vmid="$1"; shift
  local keep=7
  while [[ $# -gt 0 ]]; do
    case $1 in --keep) keep="$2"; shift 2 ;; *) shift ;; esac
  done
  local type=$(detect_type "$vmid")
  local snaps
  snaps=$(api_get "/nodes/$PROXMOX_NODE/$type/$vmid/snapshot" | \
    jq -r "[.data[] | select(.name != \"current\")] | sort_by(.snaptime) | reverse | .[$keep:][] | .name")
  local count=0
  for snap in $snaps; do
    api_delete "/nodes/$PROXMOX_NODE/$type/$vmid/snapshot/$snap" > /dev/null
    info "🗑️  Pruned snapshot: $snap"
    ((count++))
  done
  info "✅ Pruned $count old snapshots (kept last $keep)"
}

cmd_backup() {
  local vmid="$1"; shift
  local compress="zstd" storage="local"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --compress) compress="$2"; shift 2 ;;
      --storage) storage="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local type=$(detect_type "$vmid")
  local mode="snapshot"
  [[ "$type" == "lxc" ]] && mode="suspend"
  api_post "/nodes/$PROXMOX_NODE/vzdump" \
    -d "vmid=$vmid" -d "compress=$compress" -d "storage=$storage" -d "mode=$mode" > /dev/null
  info "💾 Backup started for $type/$vmid (compress=$compress, storage=$storage)"
}

cmd_backups() {
  local storage="${1:-local}"
  local data
  data=$(api_get "/nodes/$PROXMOX_NODE/storage/$storage/content" | jq '[.data[] | select(.content == "backup")]')

  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "$data"
    return
  fi

  printf "%-6s %-22s %-10s %-10s %-50s\n" "VMID" "DATE" "SIZE" "STORAGE" "FILE"
  echo "--------------------------------------------------------------------------------------------------------------"
  echo "$data" | jq -r '.[] | [(.vmid // "?"), (.ctime // 0 | tostring), (.size // 0 | tostring), "'"$storage"'", .volid] | @tsv' | \
  while IFS=$'\t' read -r vmid ctime size stor volid; do
    local date_str=""
    [[ "$ctime" != "0" ]] && date_str=$(date -d "@$ctime" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$ctime")
    printf "%-6s %-22s %-10s %-10s %-50s\n" "$vmid" "$date_str" "$(human_bytes "$size")" "$stor" "$volid"
  done
}

cmd_node_status() {
  local data
  data=$(api_get "/nodes/$PROXMOX_NODE/status")
  local qemu_running lxc_running qemu_stopped lxc_stopped
  qemu_running=$(api_get "/nodes/$PROXMOX_NODE/qemu" | jq '[.data[] | select(.status=="running")] | length')
  qemu_stopped=$(api_get "/nodes/$PROXMOX_NODE/qemu" | jq '[.data[] | select(.status!="running")] | length')
  lxc_running=$(api_get "/nodes/$PROXMOX_NODE/lxc" | jq '[.data[] | select(.status=="running")] | length')
  lxc_stopped=$(api_get "/nodes/$PROXMOX_NODE/lxc" | jq '[.data[] | select(.status!="running")] | length')

  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "$data" | jq '.data'
    return
  fi

  local cpu mem_used mem_total swap_used swap_total root_used root_total uptime_s
  cpu=$(echo "$data" | jq -r '(.data.cpu * 1000 | floor) / 10')
  mem_used=$(echo "$data" | jq -r '.data.memory.used')
  mem_total=$(echo "$data" | jq -r '.data.memory.total')
  swap_used=$(echo "$data" | jq -r '.data.swap.used')
  swap_total=$(echo "$data" | jq -r '.data.swap.total')
  root_used=$(echo "$data" | jq -r '.data.rootfs.used')
  root_total=$(echo "$data" | jq -r '.data.rootfs.total')
  uptime_s=$(echo "$data" | jq -r '.data.uptime')

  echo "NODE: $PROXMOX_NODE"
  echo "CPU:      ${cpu}%"
  echo "RAM:      $(human_bytes "$mem_used") / $(human_bytes "$mem_total")"
  echo "SWAP:     $(human_bytes "$swap_used") / $(human_bytes "$swap_total")"
  echo "DISK:     $(human_bytes "$root_used") / $(human_bytes "$root_total")"
  echo "UPTIME:   $(human_uptime "$uptime_s")"
  echo "VMs:      $qemu_running running / $qemu_stopped stopped"
  echo "CTs:      $lxc_running running / $lxc_stopped stopped"
}

cmd_top() {
  local qemu_data
  qemu_data=$(api_get "/nodes/$PROXMOX_NODE/qemu" | jq '.data[] | select(.status=="running")')
  local lxc_data
  lxc_data=$(api_get "/nodes/$PROXMOX_NODE/lxc" | jq '.data[] | select(.status=="running")')

  printf "%-6s %-20s %-6s %-6s %-12s\n" "ID" "NAME" "CPU%" "RAM%" "UPTIME"
  echo "----------------------------------------------------------"

  {
    echo "$qemu_data"
    echo "$lxc_data"
  } | jq -r '[.vmid, .name, ((.cpu // 0) * 100 * 10 | floor / 10 | tostring), (if .maxmem > 0 then ((.mem // 0) / .maxmem * 100 * 10 | floor / 10) else 0 end | tostring), (.uptime // 0 | tostring)] | @tsv' 2>/dev/null | \
  while IFS=$'\t' read -r vmid name cpu mem uptime_s; do
    printf "%-6s %-20s %-6s %-6s %-12s\n" "$vmid" "$name" "${cpu}%" "${mem}%" "$(human_uptime "${uptime_s%%.*}")"
  done
}

cmd_tasks() {
  local data
  data=$(api_get "/nodes/$PROXMOX_NODE/tasks?limit=10")

  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "$data" | jq '.data'
    return
  fi

  printf "%-38s %-10s %-20s %-8s\n" "UPID" "STATUS" "TYPE" "USER"
  echo "-------------------------------------------------------------------"
  echo "$data" | jq -r '.data[] | [.upid, .status, .type, .user] | @tsv' | head -10 | \
  while IFS=$'\t' read -r upid status type user; do
    printf "%-38s %-10s %-20s %-8s\n" "${upid:0:36}.." "$status" "$type" "$user"
  done
}

cmd_create_ct() {
  local vmid="" name="" template="" memory=512 cores=1 disk=8 net=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id) vmid="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --template) template="$2"; shift 2 ;;
      --memory) memory="$2"; shift 2 ;;
      --cores) cores="$2"; shift 2 ;;
      --disk) disk="$2"; shift 2 ;;
      --net) net="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$vmid" || -z "$template" ]] && die "Usage: pvm.sh create-ct --id <id> --template <template> [--name name] [--memory MB] [--cores N] [--disk GB] [--net config]"
  local args=(-d "vmid=$vmid" -d "ostemplate=$template" -d "memory=$memory" -d "cores=$cores" -d "rootfs=local-lvm:$disk")
  [[ -n "$name" ]] && args+=(-d "hostname=$name")
  [[ -n "$net" ]] && args+=(-d "net0=$net")
  api_post "/nodes/$PROXMOX_NODE/lxc" "${args[@]}" > /dev/null
  info "✅ Container $vmid created (${name:-unnamed}, ${memory}MB RAM, ${cores} cores, ${disk}GB disk)"
}

cmd_create_vm() {
  local vmid="" name="" memory=2048 cores=2 disk=32 iso="" net=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id) vmid="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --memory) memory="$2"; shift 2 ;;
      --cores) cores="$2"; shift 2 ;;
      --disk) disk="$2"; shift 2 ;;
      --iso) iso="$2"; shift 2 ;;
      --net) net="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$vmid" ]] && die "Usage: pvm.sh create-vm --id <id> [--name name] [--memory MB] [--cores N] [--disk GB] [--iso path] [--net config]"
  local args=(-d "vmid=$vmid" -d "memory=$memory" -d "cores=$cores" -d "scsi0=local-lvm:$disk")
  [[ -n "$name" ]] && args+=(-d "name=$name")
  [[ -n "$iso" ]] && args+=(-d "cdrom=$iso")
  [[ -n "$net" ]] && args+=(-d "net0=virtio,$net")
  api_post "/nodes/$PROXMOX_NODE/qemu" "${args[@]}" > /dev/null
  info "✅ VM $vmid created (${name:-unnamed}, ${memory}MB RAM, ${cores} cores, ${disk}GB disk)"
}

cmd_migrate() {
  local vmid="$1"; shift
  local target="" offline=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --target) target="$2"; shift 2 ;;
      --offline) offline=true; shift ;;
      *) shift ;;
    esac
  done
  [[ -z "$target" ]] && die "Usage: pvm.sh migrate <vmid> --target <node>"
  local type=$(detect_type "$vmid")
  local args=(-d "target=$target")
  [[ "$offline" == "true" ]] && args+=(-d "online=0") || args+=(-d "online=1")
  api_post "/nodes/$PROXMOX_NODE/$type/$vmid/migrate" "${args[@]}" > /dev/null
  info "🚚 Migration of $type/$vmid to $target started"
}

cmd_health() {
  local ids="" alert=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --ids) ids="$2"; shift 2 ;;
      --alert) alert="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$ids" ]] && die "Usage: pvm.sh health --ids 100,101,200 [--alert telegram]"

  local failed=0 msg=""
  IFS=',' read -ra ID_LIST <<< "$ids"
  for vmid in "${ID_LIST[@]}"; do
    local type=$(detect_type "$vmid")
    local data
    data=$(api_get "/nodes/$PROXMOX_NODE/$type/$vmid/status/current")
    local status name
    status=$(echo "$data" | jq -r '.data.status')
    name=$(echo "$data" | jq -r '.data.name // "unknown"')
    if [[ "$status" != "running" ]]; then
      info "❌ $type $vmid ($name) is ${status^^} — expected running"
      msg+="❌ $type $vmid ($name) is ${status^^}\n"
      ((failed++))
    else
      info "✅ $type $vmid ($name) is running"
    fi
  done

  if [[ $failed -gt 0 && "$alert" == "telegram" ]]; then
    local bot_token="${TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${TELEGRAM_CHAT_ID:-}"
    if [[ -n "$bot_token" && -n "$chat_id" ]]; then
      curl -s "https://api.telegram.org/bot${bot_token}/sendMessage" \
        -d "chat_id=$chat_id" -d "text=🚨 Proxmox Health Alert:\n${msg}" > /dev/null
      info "🔔 Alert sent to Telegram"
    else
      info "⚠️  Telegram not configured (set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)"
    fi
  fi

  return $failed
}

# --- Main ---
[[ -z "$PROXMOX_HOST" ]] && {
  echo "Proxmox VE Manager (pvm.sh)"
  echo ""
  echo "Usage: pvm.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  status          Cluster/node connection status"
  echo "  list            List all VMs and containers"
  echo "  start <id>      Start a VM/CT"
  echo "  stop <id>       Stop a VM/CT (--force for hard stop)"
  echo "  restart <id>    Restart a VM/CT"
  echo "  suspend <id>    Suspend a VM"
  echo "  resume <id>     Resume a VM"
  echo "  snapshot <id>   Create snapshot (--name <name>)"
  echo "  snapshots <id>  List snapshots"
  echo "  rollback <id>   Rollback to snapshot (--name <name>)"
  echo "  snap-delete <id> Delete snapshot (--name <name>)"
  echo "  snap-prune <id> Prune old snapshots (--keep N)"
  echo "  backup <id>     Create backup (--compress, --storage)"
  echo "  backups         List backups"
  echo "  node-status     Detailed node resource info"
  echo "  top             Running VM/CT resource usage"
  echo "  tasks           Recent task list"
  echo "  create-ct       Create LXC container"
  echo "  create-vm       Create QEMU VM"
  echo "  migrate <id>    Migrate VM/CT (--target <node>)"
  echo "  health          Check VM health (--ids, --alert)"
  echo ""
  echo "Global flags: --json (JSON output)"
  echo ""
  echo "Configure: $CONFIG_FILE"
  exit 0
}

# Parse global flags
ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--json" ]]; then
    JSON_OUTPUT=true
  else
    ARGS+=("$arg")
  fi
done
set -- "${ARGS[@]}"

CMD="${1:-status}"; shift || true

case "$CMD" in
  status)       cmd_status ;;
  list)         cmd_list "$@" ;;
  start)        cmd_start "$@" ;;
  stop)         cmd_stop "$@" ;;
  restart)      cmd_restart "$@" ;;
  suspend)      cmd_suspend "$@" ;;
  resume)       cmd_resume "$@" ;;
  snapshot)     cmd_snapshot "$@" ;;
  snapshots)    cmd_snapshots "$@" ;;
  rollback)     cmd_rollback "$@" ;;
  snap-delete)  cmd_snap_delete "$@" ;;
  snap-prune)   cmd_snap_prune "$@" ;;
  backup)       cmd_backup "$@" ;;
  backups)      cmd_backups "$@" ;;
  node-status)  cmd_node_status ;;
  top)          cmd_top ;;
  tasks)        cmd_tasks ;;
  create-ct)    cmd_create_ct "$@" ;;
  create-vm)    cmd_create_vm "$@" ;;
  migrate)      cmd_migrate "$@" ;;
  health)       cmd_health "$@" ;;
  *)            die "Unknown command: $CMD. Run 'pvm.sh' for help." ;;
esac
