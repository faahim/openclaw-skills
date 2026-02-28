#!/bin/bash
# Take a one-time system snapshot in JSON format
# Works even without Glances web mode running

set -e

GLANCES_BIN=""
if command -v glances &>/dev/null; then
    GLANCES_BIN="glances"
elif [ -f "$HOME/.local/bin/glances" ]; then
    GLANCES_BIN="$HOME/.local/bin/glances"
fi

# If Glances web is running, use the API
if curl -s http://localhost:61208/api/4/all &>/dev/null; then
    curl -s http://localhost:61208/api/4/all | python3 -m json.tool
    exit 0
fi

# Otherwise, use glances stdout mode
if [ -n "$GLANCES_BIN" ]; then
    $GLANCES_BIN --stdout cpu.total,mem.percent,swap.percent,load.min5 --time 1 --count 1 2>/dev/null
    exit 0
fi

# Fallback: native system commands
python3 -c "
import json, os, subprocess

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode().strip()
    except:
        return ''

snapshot = {}

# CPU
try:
    with open('/proc/stat') as f:
        line = f.readline().split()
    idle = int(line[4])
    total = sum(int(x) for x in line[1:])
    # Simple instant reading
    snapshot['cpu'] = {'cores': os.cpu_count()}
except:
    pass

# Memory
try:
    mem = {}
    with open('/proc/meminfo') as f:
        for line in f:
            parts = line.split()
            key = parts[0].rstrip(':')
            mem[key] = int(parts[1])
    total = mem.get('MemTotal', 0)
    avail = mem.get('MemAvailable', 0)
    used = total - avail
    snapshot['mem'] = {
        'total_mb': round(total / 1024),
        'used_mb': round(used / 1024),
        'available_mb': round(avail / 1024),
        'percent': round(used / total * 100, 1) if total else 0
    }
except:
    pass

# Disk
try:
    statvfs = os.statvfs('/')
    total = statvfs.f_frsize * statvfs.f_blocks
    free = statvfs.f_frsize * statvfs.f_bavail
    used = total - free
    snapshot['disk_root'] = {
        'total_gb': round(total / (1024**3), 1),
        'used_gb': round(used / (1024**3), 1),
        'free_gb': round(free / (1024**3), 1),
        'percent': round(used / total * 100, 1) if total else 0
    }
except:
    pass

# Load
try:
    load = os.getloadavg()
    snapshot['load'] = {'1min': load[0], '5min': load[1], '15min': load[2]}
except:
    pass

# Uptime
try:
    with open('/proc/uptime') as f:
        uptime_sec = float(f.read().split()[0])
    days = int(uptime_sec // 86400)
    hours = int((uptime_sec % 86400) // 3600)
    snapshot['uptime'] = f'{days}d {hours}h'
except:
    pass

print(json.dumps(snapshot, indent=2))
"
