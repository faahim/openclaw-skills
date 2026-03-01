#!/bin/bash
# JupyterLab Runner — Start, stop, configure, and manage JupyterLab
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Load env
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

VENV_PATH="${JUPYTER_VENV:-$HOME/.jupyter-venv}"
WORKSPACE="${JUPYTER_HOME:-$HOME/jupyter-workspace}"
PORT="${JUPYTER_PORT:-8888}"
IP="${JUPYTER_IP:-127.0.0.1}"
PID_FILE="$HOME/.jupyter/jupyter-lab.pid"

activate_venv() {
  if [ -d "$VENV_PATH" ]; then
    # shellcheck disable=SC1091
    source "$VENV_PATH/bin/activate"
  fi
}

cmd_start() {
  activate_venv
  local bg=false ssl=false extra_args=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --background|-b) bg=true; shift ;;
      --port) PORT="$2"; shift 2 ;;
      --ip) IP="$2"; shift 2 ;;
      --ssl) ssl=true; shift ;;
      --no-browser) extra_args="$extra_args --no-browser"; shift ;;
      *) extra_args="$extra_args $1"; shift ;;
    esac
  done

  if [ "$ssl" = true ]; then
    # Generate self-signed cert if none exists
    local cert_dir="$HOME/.jupyter/ssl"
    if [ ! -f "$cert_dir/jupyter.pem" ]; then
      mkdir -p "$cert_dir"
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/jupyter.key" \
        -out "$cert_dir/jupyter.pem" \
        -subj "/CN=jupyter-local" 2>/dev/null
      echo "🔒 Self-signed SSL certificate generated"
    fi
    extra_args="$extra_args --certfile=$cert_dir/jupyter.pem --keyfile=$cert_dir/jupyter.key"
  fi

  mkdir -p "$(dirname "$PID_FILE")"

  if [ "$bg" = true ]; then
    nohup jupyter lab --ip="$IP" --port="$PORT" --no-browser \
      --notebook-dir="$WORKSPACE" $extra_args \
      > "$HOME/.jupyter/jupyter-lab.log" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 2
    
    # Get token
    local token
    token=$(jupyter lab list 2>/dev/null | grep -oP 'token=\K[a-z0-9]+' | head -1 || echo "")
    
    local proto="http"
    [ "$ssl" = true ] && proto="https"
    
    echo "🚀 JupyterLab running in background"
    echo "   URL: ${proto}://${IP}:${PORT}"
    [ -n "$token" ] && echo "   Token: $token"
    echo "   PID: $(cat "$PID_FILE")"
    echo "   Log: $HOME/.jupyter/jupyter-lab.log"
  else
    echo "🚀 Starting JupyterLab on ${IP}:${PORT}..."
    jupyter lab --ip="$IP" --port="$PORT" --no-browser \
      --notebook-dir="$WORKSPACE" $extra_args
  fi
}

cmd_stop() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      rm -f "$PID_FILE"
      echo "🛑 JupyterLab stopped (PID: $pid)"
    else
      rm -f "$PID_FILE"
      echo "⚠️  Process $pid not running. Cleaned up PID file."
    fi
  else
    # Try jupyter stop
    activate_venv
    jupyter lab stop "$PORT" 2>/dev/null || echo "⚠️  No running JupyterLab found"
  fi
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start --background "$@"
}

cmd_status() {
  activate_venv
  echo "📊 JupyterLab Status"
  echo "===================="
  
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Status: ✅ Running (PID: $(cat "$PID_FILE"))"
  else
    echo "Status: 🔴 Stopped"
  fi
  
  echo ""
  echo "Running servers:"
  jupyter lab list 2>/dev/null || echo "  None"
  echo ""
  echo "Config:"
  echo "  Venv:      $VENV_PATH"
  echo "  Workspace: $WORKSPACE"
  echo "  Port:      $PORT"
  echo "  IP:        $IP"
  echo ""
  echo "Installed packages:"
  pip list 2>/dev/null | grep -iE "jupyter|numpy|pandas|matplotlib|scipy|scikit" || echo "  (activate venv first)"
}

cmd_password() {
  activate_venv
  echo "🔐 Set JupyterLab password:"
  jupyter lab password
  echo "✅ Password set. Restart JupyterLab to apply."
}

cmd_configure() {
  local config="$HOME/.jupyter/jupyter_lab_config.py"
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --ip)
        IP="$2"
        sed -i "s/c.ServerApp.ip = .*/c.ServerApp.ip = '$IP'/" "$config" 2>/dev/null || true
        shift 2 ;;
      --port)
        PORT="$2"
        sed -i "s/c.ServerApp.port = .*/c.ServerApp.port = $PORT/" "$config" 2>/dev/null || true
        shift 2 ;;
      *) shift ;;
    esac
  done
  
  # Update .env
  cat > "$ENV_FILE" << EOF
JUPYTER_VENV="$VENV_PATH"
JUPYTER_HOME="$WORKSPACE"
JUPYTER_PORT="$PORT"
JUPYTER_IP="$IP"
EOF
  
  echo "✅ Configuration updated"
  echo "   IP: $IP, Port: $PORT"
}

cmd_service() {
  local action="${1:-help}"
  local service_file="/etc/systemd/system/jupyterlab.service"
  local user
  user=$(whoami)
  
  case "$action" in
    install)
      activate_venv
      local jupyter_bin
      jupyter_bin=$(which jupyter)
      
      sudo tee "$service_file" > /dev/null << SVCEOF
[Unit]
Description=JupyterLab Server
After=network.target

[Service]
Type=simple
User=$user
WorkingDirectory=$WORKSPACE
Environment="PATH=$VENV_PATH/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$jupyter_bin lab --ip=$IP --port=$PORT --no-browser --notebook-dir=$WORKSPACE
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF
      sudo systemctl daemon-reload
      sudo systemctl enable jupyterlab
      echo "✅ JupyterLab systemd service installed and enabled"
      echo "   Start: bash scripts/run.sh service start"
      ;;
    start) sudo systemctl start jupyterlab; echo "✅ Service started" ;;
    stop) sudo systemctl stop jupyterlab; echo "🛑 Service stopped" ;;
    status) sudo systemctl status jupyterlab --no-pager ;;
    uninstall)
      sudo systemctl stop jupyterlab 2>/dev/null || true
      sudo systemctl disable jupyterlab 2>/dev/null || true
      sudo rm -f "$service_file"
      sudo systemctl daemon-reload
      echo "✅ Service removed"
      ;;
    *) echo "Usage: run.sh service [install|start|stop|status|uninstall]" ;;
  esac
}

cmd_docker() {
  local volume="${WORKSPACE}:/home/jovyan/work"
  local gpu=false
  local extra=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --port) PORT="$2"; shift 2 ;;
      --volume) volume="$2"; shift 2 ;;
      --gpu) gpu=true; shift ;;
      *) shift ;;
    esac
  done
  
  local image="jupyter/scipy-notebook:latest"
  [ "$gpu" = true ] && image="jupyter/tensorflow-notebook:latest"
  
  mkdir -p "$WORKSPACE"
  
  local gpu_flag=""
  [ "$gpu" = true ] && gpu_flag="--gpus all"
  
  echo "🐳 Starting JupyterLab in Docker..."
  docker run -d --name jupyterlab \
    -p "${PORT}:8888" \
    -v "$volume" \
    $gpu_flag \
    "$image" \
    start-notebook.sh --NotebookApp.token=''
  
  echo "🚀 JupyterLab running at http://localhost:${PORT}"
  echo "   Volume: $volume"
  echo "   Stop: docker stop jupyterlab && docker rm jupyterlab"
}

# Main dispatch
ACTION="${1:-help}"
shift || true

case "$ACTION" in
  start) cmd_start "$@" ;;
  stop) cmd_stop ;;
  restart) cmd_restart "$@" ;;
  status) cmd_status ;;
  password) cmd_password ;;
  configure) cmd_configure "$@" ;;
  service) cmd_service "$@" ;;
  docker) cmd_docker "$@" ;;
  *)
    echo "JupyterLab Manager"
    echo ""
    echo "Usage: bash run.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start [--background] [--port N] [--ip ADDR] [--ssl]"
    echo "  stop"
    echo "  restart"
    echo "  status"
    echo "  password          Set access password"
    echo "  configure         Update config (--ip, --port)"
    echo "  service           Systemd service management"
    echo "  docker            Run in Docker container"
    ;;
esac
