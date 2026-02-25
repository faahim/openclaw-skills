#!/bin/bash
# Logrotate Manager — Create, audit, test, and monitor log rotation configs
set -euo pipefail

LOGROTATE_DIR="/etc/logrotate.d"
LOGROTATE_CONF="/etc/logrotate.conf"
STATE_FILE="/var/lib/logrotate/status"
THRESHOLD="${LOGROTATE_THRESHOLD:-100M}"
DEFAULT_ROTATE="${LOGROTATE_DEFAULT_ROTATE:-7}"
ALERT_CMD="${LOGROTATE_ALERT_CMD:-}"

# Convert human-readable size to bytes
to_bytes() {
  local size="$1"
  local num="${size%[KkMmGgTt]*}"
  local unit="${size##*[0-9]}"
  case "${unit^^}" in
    K) echo $((num * 1024)) ;;
    M) echo $((num * 1024 * 1024)) ;;
    G) echo $((num * 1024 * 1024 * 1024)) ;;
    T) echo $((num * 1024 * 1024 * 1024 * 1024)) ;;
    *) echo "$num" ;;
  esac
}

# Human-readable file size
human_size() {
  local bytes=$1
  if [ "$bytes" -ge $((1024*1024*1024)) ]; then
    echo "$(echo "scale=1; $bytes/1024/1024/1024" | bc)GB"
  elif [ "$bytes" -ge $((1024*1024)) ]; then
    echo "$(echo "scale=1; $bytes/1024/1024" | bc)MB"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$(echo "scale=1; $bytes/1024" | bc)KB"
  else
    echo "${bytes}B"
  fi
}

# === AUDIT ===
cmd_audit() {
  local threshold_bytes
  threshold_bytes=$(to_bytes "$THRESHOLD")

  echo "=== Logrotate Audit ==="
  echo ""

  # Count configs
  local config_count
  config_count=$(ls -1 "$LOGROTATE_DIR"/ 2>/dev/null | wc -l)
  echo "Config files found: $config_count"
  for f in "$LOGROTATE_DIR"/*; do
    [ -f "$f" ] && echo "  $f"
  done
  echo ""

  # Validate configs
  echo "Config validation:"
  local errors=0
  for f in "$LOGROTATE_DIR"/*; do
    [ -f "$f" ] || continue
    if sudo logrotate -d "$f" >/dev/null 2>&1; then
      echo "  ✅ $(basename "$f")"
    else
      echo "  ❌ $(basename "$f") — run 'sudo logrotate -d $f' for details"
      errors=$((errors + 1))
    fi
  done
  echo ""

  # Find large log files
  echo "Large log files (>${THRESHOLD}):"
  local found_large=0
  while IFS= read -r -d '' logfile; do
    local size
    size=$(stat -c%s "$logfile" 2>/dev/null || echo 0)
    if [ "$size" -ge "$threshold_bytes" ]; then
      echo "  ⚠️  $logfile — $(human_size "$size")"
      found_large=$((found_large + 1))
    fi
  done < <(find /var/log -type f -name "*.log" -print0 2>/dev/null)
  [ "$found_large" -eq 0 ] && echo "  ✅ None found"
  echo ""

  # Check for unmanaged logs
  echo "Checking for logs without rotation configs..."
  local managed_paths=()
  for f in "$LOGROTATE_DIR"/*; do
    [ -f "$f" ] || continue
    while IFS= read -r line; do
      line=$(echo "$line" | sed 's/[[:space:]]*{.*//' | xargs)
      [[ -n "$line" && "$line" != "#"* && "$line" != "/"*"}" ]] && managed_paths+=("$line")
    done < <(grep -E '^/' "$f" 2>/dev/null)
  done

  local log_dirs=("/var/log")
  for dir in "${log_dirs[@]}"; do
    while IFS= read -r -d '' logfile; do
      local managed=false
      for pattern in "${managed_paths[@]}"; do
        # Simple glob check
        if [[ "$logfile" == $pattern ]]; then
          managed=true
          break
        fi
      done
      if ! $managed; then
        local size
        size=$(stat -c%s "$logfile" 2>/dev/null || echo 0)
        if [ "$size" -ge 1048576 ]; then  # Only report >1MB unmanaged logs
          echo "  ❌ $logfile ($(human_size "$size")) — no rotation config found"
        fi
      fi
    done < <(find "$dir" -maxdepth 3 -type f -name "*.log" -print0 2>/dev/null)
  done

  echo ""
  echo "Errors: $errors | Large files: $found_large"
}

# === CREATE ===
cmd_create() {
  local path="" rotate="$DEFAULT_ROTATE" frequency="daily" compress=false
  local maxsize="" name="" postrotate="" owner="root:adm" mode="0640"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --path) path="$2"; shift 2 ;;
      --rotate) rotate="$2"; shift 2 ;;
      --frequency) frequency="$2"; shift 2 ;;
      --compress) compress=true; shift ;;
      --maxsize) maxsize="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --postrotate) postrotate="$2"; shift 2 ;;
      --owner) owner="$2"; shift 2 ;;
      --mode) mode="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$path" || -z "$name" ]]; then
    echo "Error: --path and --name are required"
    echo "Usage: $0 create --path '/var/log/app/*.log' --name myapp [options]"
    exit 1
  fi

  if [[ -f "$LOGROTATE_DIR/$name" ]]; then
    echo "Error: Config '$name' already exists at $LOGROTATE_DIR/$name"
    echo "Use 'remove --name $name' first, or pick a different name."
    exit 1
  fi

  local user="${owner%%:*}"
  local group="${owner##*:}"

  local config="$path {
    $frequency
    rotate $rotate"

  $compress && config+="
    compress
    delaycompress"

  [[ -n "$maxsize" ]] && config+="
    maxsize $maxsize"

  config+="
    missingok
    notifempty
    create $mode $user $group
    sharedscripts"

  if [[ -n "$postrotate" ]]; then
    config+="
    postrotate
        $postrotate
    endscript"
  fi

  config+="
}"

  echo "$config" | sudo tee "$LOGROTATE_DIR/$name" > /dev/null
  sudo chmod 644 "$LOGROTATE_DIR/$name"

  echo "✅ Created $LOGROTATE_DIR/$name"
  echo ""
  echo "Config:"
  cat "$LOGROTATE_DIR/$name"
  echo ""

  # Dry-run test
  echo "Testing (dry run)..."
  if sudo logrotate -d "$LOGROTATE_DIR/$name" 2>&1 | tail -5; then
    echo ""
    echo "✅ Config is valid"
  else
    echo ""
    echo "⚠️ Config may have issues — check output above"
  fi
}

# === TEST ===
cmd_test() {
  local name="" all=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --all) all=true; shift ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  if $all; then
    echo "Testing all logrotate configs (dry run)..."
    sudo logrotate -d "$LOGROTATE_CONF" 2>&1
  elif [[ -n "$name" ]]; then
    local conf="$LOGROTATE_DIR/$name"
    if [[ ! -f "$conf" ]]; then
      echo "Error: Config not found: $conf"
      exit 1
    fi
    echo "Testing $conf (dry run)..."
    sudo logrotate -d "$conf" 2>&1
  else
    echo "Error: Specify --name <config> or --all"
    exit 1
  fi
}

# === FORCE ===
cmd_force() {
  local name="" all=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --all) all=true; shift ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  if $all; then
    echo "Force rotating all logs..."
    sudo logrotate -f "$LOGROTATE_CONF" 2>&1
    echo "✅ Done"
  elif [[ -n "$name" ]]; then
    local conf="$LOGROTATE_DIR/$name"
    if [[ ! -f "$conf" ]]; then
      echo "Error: Config not found: $conf"
      exit 1
    fi
    echo "Force rotating $conf..."
    sudo logrotate -f "$conf" 2>&1
    echo "✅ Done"
  else
    echo "Error: Specify --name <config> or --all"
    exit 1
  fi
}

# === LIST ===
cmd_list() {
  printf "%-20s %-35s %-10s %-8s %-10s %-8s\n" "Config" "Path" "Frequency" "Rotate" "Compress" "MaxSize"
  printf "%-20s %-35s %-10s %-8s %-10s %-8s\n" "────────────────────" "───────────────────────────────────" "──────────" "────────" "──────────" "────────"

  for f in "$LOGROTATE_DIR"/*; do
    [ -f "$f" ] || continue
    local name
    name=$(basename "$f")
    local path freq="" rot="" comp="no" maxsz="-"

    path=$(grep -m1 -E '^/' "$f" | sed 's/[[:space:]]*{.*//' | xargs)
    grep -q 'daily' "$f" && freq="daily"
    grep -q 'weekly' "$f" && freq="weekly"
    grep -q 'monthly' "$f" && freq="monthly"
    rot=$(grep -oP 'rotate\s+\K\d+' "$f" 2>/dev/null || echo "-")
    grep -q '^\s*compress' "$f" && comp="yes"
    maxsz=$(grep -oP 'maxsize\s+\K\S+' "$f" 2>/dev/null || echo "-")

    printf "%-20s %-35s %-10s %-8s %-10s %-8s\n" "$name" "${path:0:35}" "${freq:-?}" "$rot" "$comp" "$maxsz"
  done
}

# === REMOVE ===
cmd_remove() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$name" ]]; then
    echo "Error: --name is required"
    exit 1
  fi

  local conf="$LOGROTATE_DIR/$name"
  if [[ ! -f "$conf" ]]; then
    echo "Error: Config not found: $conf"
    exit 1
  fi

  echo "Removing $conf..."
  cat "$conf"
  echo ""
  sudo rm "$conf"
  echo "✅ Removed $name"
}

# === MONITOR ===
cmd_monitor() {
  local dirs="/var/log" threshold="$THRESHOLD" alert_cmd="$ALERT_CMD"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --dirs) dirs="$2"; shift 2 ;;
      --threshold) threshold="$2"; shift 2 ;;
      --alert-cmd) alert_cmd="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  local threshold_bytes
  threshold_bytes=$(to_bytes "$threshold")

  echo "=== Log Size Monitor ==="
  echo "Threshold: $threshold"
  echo "Directories: $dirs"
  echo ""

  IFS=',' read -ra DIR_ARRAY <<< "$dirs"
  local alerts=0

  for dir in "${DIR_ARRAY[@]}"; do
    dir=$(echo "$dir" | xargs)
    [ -d "$dir" ] || continue

    while IFS= read -r -d '' logfile; do
      local size
      size=$(stat -c%s "$logfile" 2>/dev/null || echo 0)
      if [ "$size" -ge "$threshold_bytes" ]; then
        local hsize
        hsize=$(human_size "$size")
        echo "⚠️  $logfile — $hsize"

        if [[ -n "$alert_cmd" ]]; then
          FILE="$logfile" SIZE="$hsize" eval "$alert_cmd"
        fi
        alerts=$((alerts + 1))
      fi
    done < <(find "$dir" -type f \( -name "*.log" -o -name "*.log.*" \) -print0 2>/dev/null)
  done

  echo ""
  if [ "$alerts" -eq 0 ]; then
    echo "✅ All logs within threshold"
  else
    echo "⚠️ $alerts log(s) exceed threshold"
  fi
}

# === MAIN ===
case "${1:-help}" in
  audit)   shift; cmd_audit "$@" ;;
  create)  shift; cmd_create "$@" ;;
  test)    shift; cmd_test "$@" ;;
  force)   shift; cmd_force "$@" ;;
  list)    shift; cmd_list "$@" ;;
  remove)  shift; cmd_remove "$@" ;;
  monitor) shift; cmd_monitor "$@" ;;
  help|--help|-h)
    echo "Logrotate Manager — Create, audit, test, and monitor log rotation"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  audit                          Audit all rotation configs and find large logs"
    echo "  create --path <glob> --name <n>  Create a new rotation config"
    echo "  test --name <n> | --all        Dry-run test a config"
    echo "  force --name <n> | --all       Force immediate rotation"
    echo "  list                           List all rotation configs"
    echo "  remove --name <n>              Remove a rotation config"
    echo "  monitor --dirs <d> --threshold <s>  Check for oversized logs"
    echo ""
    echo "Examples:"
    echo "  $0 create --path '/var/log/app/*.log' --name myapp --rotate 7 --compress --maxsize 100M"
    echo "  $0 audit"
    echo "  $0 monitor --threshold 500M --alert-cmd 'echo \$FILE is \$SIZE'"
    ;;
  *)
    echo "Unknown command: $1 (try 'help')"
    exit 1 ;;
esac
