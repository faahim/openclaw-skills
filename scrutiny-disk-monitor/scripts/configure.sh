#!/bin/bash
# Configure Scrutiny settings
set -euo pipefail

CONFIG="/opt/scrutiny/config/scrutiny.yaml"
COMPOSE="/opt/scrutiny/docker-compose.yml"

while [[ $# -gt 0 ]]; do
  case $1 in
    --scan-interval)
      # Update collector cron schedule (seconds to cron)
      SECS="$2"
      HOURS=$((SECS / 3600))
      [ "$HOURS" -lt 1 ] && HOURS=1
      sed -i "s|COLLECTOR_CRON_SCHEDULE=.*|COLLECTOR_CRON_SCHEDULE=0 */${HOURS} * * *|" "$COMPOSE"
      echo "✅ Scan interval set to every ${HOURS} hour(s)"
      shift 2
      ;;
    --include)
      echo "Include devices: $2"
      echo "  Edit $COMPOSE 'devices:' section to list only these drives"
      shift 2
      ;;
    --exclude)
      echo "Exclude devices: $2"
      echo "  Edit $COMPOSE 'devices:' section to remove these drives"
      shift 2
      ;;
    --add-device)
      DEV="$2"
      if [ -b "$DEV" ]; then
        sed -i "/devices:/a\\      - ${DEV}" "$COMPOSE"
        echo "✅ Added $DEV to docker-compose.yml"
      else
        echo "❌ $DEV is not a valid block device"
      fi
      shift 2
      ;;
    --device)
      DEV="$2"; shift 2
      if [ "$1" = "--type" ]; then
        TYPE="$2"; shift 2
        # Add device type override to scrutiny config
        if ! grep -q "devices:" "$CONFIG"; then
          echo -e "\ndevices:" >> "$CONFIG"
        fi
        echo "  - device: $DEV" >> "$CONFIG"
        echo "    type: $TYPE" >> "$CONFIG"
        echo "✅ Set $DEV type to $TYPE"
      fi
      ;;
    -h|--help)
      echo "Usage: configure.sh [OPTIONS]"
      echo "  --scan-interval SECS   Set scan interval in seconds"
      echo "  --add-device /dev/xxx  Add a device to monitoring"
      echo "  --device DEV --type T  Override device type (sat, nvme, scsi, ata)"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# Restart to apply
docker restart scrutiny &>/dev/null && echo "🔄 Scrutiny restarted with new config" || true
