#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.config/zfs-snapshot-manager/config.env"
ACTION="snapshot"
CLASS="hourly"
DRY_RUN=0

usage() {
  cat <<USAGE
Usage:
  bash scripts/run.sh --action snapshot --class hourly
  bash scripts/run.sh --action prune
  bash scripts/run.sh --action status
Options:
  --config <path>      Config file path (default: ~/.config/zfs-snapshot-manager/config.env)
  --action <name>      snapshot | prune | status
  --class <name>       hourly | daily | weekly (for snapshot action)
  --dry-run            Print commands without executing
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --class) CLASS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

[ -f "$CONFIG_FILE" ] || { echo "❌ Missing config: $CONFIG_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${DATASETS:?DATASETS must be set}"
: "${SNAPSHOT_PREFIX:=oclaw}"
: "${KEEP_HOURLY:=24}"
: "${KEEP_DAILY:=7}"
: "${KEEP_WEEKLY:=4}"

run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}

snapshot_name() {
  date -u +"${SNAPSHOT_PREFIX}-$CLASS-%Y%m%d-%H%M%S"
}

create_snapshots() {
  local snap
  snap="$(snapshot_name)"
  for ds in $DATASETS; do
    echo "📸 Creating snapshot $ds@$snap"
    run_cmd "zfs snapshot $ds@$snap"
  done
}

get_keep_for_class() {
  case "$1" in
    hourly) echo "$KEEP_HOURLY" ;;
    daily) echo "$KEEP_DAILY" ;;
    weekly) echo "$KEEP_WEEKLY" ;;
    *) echo "0" ;;
  esac
}

prune_dataset_class() {
  local ds="$1" class="$2" keep="$3"
  local snaps
  snaps=$(zfs list -H -t snapshot -o name -s creation | grep "^${ds}@${SNAPSHOT_PREFIX}-${class}-" || true)
  [ -n "$snaps" ] || return 0

  local total
  total=$(printf "%s\n" "$snaps" | wc -l | tr -d ' ')
  if [ "$total" -le "$keep" ]; then
    echo "✅ $ds ($class): $total snapshots, keep=$keep"
    return 0
  fi

  local remove_count=$((total - keep))
  echo "🧹 $ds ($class): removing $remove_count old snapshots"
  printf "%s\n" "$snaps" | head -n "$remove_count" | while read -r snap; do
    [ -n "$snap" ] || continue
    run_cmd "zfs destroy $snap"
  done
}

prune_snapshots() {
  for ds in $DATASETS; do
    prune_dataset_class "$ds" hourly "$(get_keep_for_class hourly)"
    prune_dataset_class "$ds" daily "$(get_keep_for_class daily)"
    prune_dataset_class "$ds" weekly "$(get_keep_for_class weekly)"
  done
}

show_status() {
  for ds in $DATASETS; do
    echo "\n=== $ds ==="
    zfs list -H -t snapshot -o name,creation -s creation | grep "^${ds}@${SNAPSHOT_PREFIX}-" || echo "(no snapshots)"
  done
}

case "$ACTION" in
  snapshot) create_snapshots ;;
  prune) prune_snapshots ;;
  status) show_status ;;
  *) echo "❌ Invalid action: $ACTION"; usage; exit 1 ;;
esac
