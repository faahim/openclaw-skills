#!/bin/bash
# Tune Netdata performance
set -e

CONF="/etc/netdata/netdata.conf"
HISTORY="" UPDATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --history) HISTORY="$2"; shift 2 ;;
        --update-every) UPDATE="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

[ -z "$HISTORY" ] && [ -z "$UPDATE" ] && {
    echo "Usage: bash scripts/tune.sh [--history SECONDS] [--update-every SECONDS]"
    echo ""
    echo "  --history 3600       Keep 1 hour of data in RAM (default)"
    echo "  --history 1800       Keep 30 min (saves ~50% RAM)"
    echo "  --history 7200       Keep 2 hours"
    echo "  --update-every 1     Collect every 1 second (default)"
    echo "  --update-every 2     Collect every 2 seconds (saves CPU)"
    echo "  --update-every 5     Collect every 5 seconds"
    exit 0
}

# Ensure config exists
[ ! -f "$CONF" ] && sudo touch "$CONF"

# Check if [global] section exists
if ! grep -q '^\[global\]' "$CONF" 2>/dev/null; then
    echo "[global]" | sudo tee -a "$CONF" >/dev/null
fi

if [ -n "$HISTORY" ]; then
    if grep -q '^[[:space:]]*history' "$CONF"; then
        sudo sed -i "s|^[[:space:]]*history.*|    history = $HISTORY|" "$CONF"
    else
        sudo sed -i "/^\[global\]/a\\    history = $HISTORY" "$CONF"
    fi
    echo "✅ History set to ${HISTORY}s (~$((HISTORY / 60)) min)"
fi

if [ -n "$UPDATE" ]; then
    if grep -q '^[[:space:]]*update every' "$CONF"; then
        sudo sed -i "s|^[[:space:]]*update every.*|    update every = $UPDATE|" "$CONF"
    else
        sudo sed -i "/^\[global\]/a\\    update every = $UPDATE" "$CONF"
    fi
    echo "✅ Update interval set to ${UPDATE}s"
fi

echo ""
echo "Restart to apply: sudo systemctl restart netdata"
