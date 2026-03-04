#!/bin/bash
# Add system resource monitoring to Monit
set -e

CPU_WARN=80
CPU_CRIT=95
MEM_WARN=80
MEM_CRIT=95
DISK="/"
DISK_WARN=85
DISK_CRIT=95

while [[ $# -gt 0 ]]; do
  case $1 in
    --cpu-warn) CPU_WARN="$2"; shift 2 ;;
    --cpu-critical) CPU_CRIT="$2"; shift 2 ;;
    --mem-warn) MEM_WARN="$2"; shift 2 ;;
    --mem-critical) MEM_CRIT="$2"; shift 2 ;;
    --disk) DISK="$2"; shift 2 ;;
    --disk-warn) DISK_WARN="$2"; shift 2 ;;
    --disk-critical) DISK_CRIT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

CONF_DIR="/etc/monit/conf.d"

# System check
cat <<EOF | sudo tee "$CONF_DIR/system.conf" >/dev/null
check system \$HOST
  if cpu usage > ${CPU_WARN}% for 5 cycles then alert
  if cpu usage > ${CPU_CRIT}% for 3 cycles then alert
  if memory usage > ${MEM_WARN}% for 5 cycles then alert
  if memory usage > ${MEM_CRIT}% for 3 cycles then alert
  if swap usage > 50% then alert
  if loadavg (5min) > 4 then alert
EOF

echo "✅ System resource monitor created at $CONF_DIR/system.conf"

# Disk check
DISK_NAME=$(echo "$DISK" | tr '/' '_' | sed 's/^_/root/')
[ "$DISK_NAME" = "" ] && DISK_NAME="root"

cat <<EOF | sudo tee "$CONF_DIR/disk-${DISK_NAME}.conf" >/dev/null
check filesystem disk_${DISK_NAME} with path $DISK
  if space usage > ${DISK_WARN}% then alert
  if space usage > ${DISK_CRIT}% then alert
  if inode usage > 90% then alert
EOF

echo "✅ Disk monitor for '$DISK' created at $CONF_DIR/disk-${DISK_NAME}.conf"

# Validate and reload
if sudo monit -t 2>/dev/null; then
  sudo monit reload 2>/dev/null
  echo "🔄 Monit reloaded"
else
  echo "❌ Config validation failed"
  exit 1
fi
