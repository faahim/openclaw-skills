#!/bin/bash
set -euo pipefail

# Docker Container Inspector — extract specific info from containers
# Usage: bash docker-inspect.sh <container> [--network] [--env] [--ports] [--mounts]

CONTAINER=""
MODE="full"

if [ $# -lt 1 ]; then
  echo "Usage: bash docker-inspect.sh <container> [--network] [--env] [--ports] [--mounts]"
  exit 1
fi

CONTAINER="$1"; shift

while [[ $# -gt 0 ]]; do
  case $1 in
    --network) MODE="network"; shift ;;
    --env) MODE="env"; shift ;;
    --ports) MODE="ports"; shift ;;
    --mounts) MODE="mounts"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if ! docker inspect "$CONTAINER" &>/dev/null; then
  echo "❌ Container '$CONTAINER' not found."
  exit 1
fi

case $MODE in
  full)
    docker inspect "$CONTAINER" | python3 -m json.tool 2>/dev/null || docker inspect "$CONTAINER"
    ;;
  network)
    echo "=== Network: $CONTAINER ==="
    docker inspect --format '
IP Address:    {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}
Gateway:       {{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}
MAC Address:   {{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}
Networks:      {{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}
' "$CONTAINER"
    echo "Port Mappings:"
    docker inspect --format '{{range $p, $conf := .NetworkSettings.Ports}}  {{$p}} -> {{if $conf}}{{range $conf}}{{.HostIp}}:{{.HostPort}}{{end}}{{else}}(not mapped){{end}}
{{end}}' "$CONTAINER"
    ;;
  env)
    echo "=== Environment: $CONTAINER ==="
    docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$CONTAINER" | sort
    ;;
  ports)
    echo "=== Ports: $CONTAINER ==="
    docker inspect --format '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{if $conf}}{{range $conf}}{{.HostIp}}:{{.HostPort}}{{end}}{{else}}(not mapped){{end}}
{{end}}' "$CONTAINER"
    ;;
  mounts)
    echo "=== Mounts: $CONTAINER ==="
    docker inspect --format '{{range .Mounts}}Type: {{.Type}}
  Source: {{.Source}}
  Dest:   {{.Destination}}
  RW:     {{.RW}}
{{end}}' "$CONTAINER"
    ;;
esac
