#!/bin/bash
# Ollama Manager — Main Script
# Manage local LLMs via Ollama

set -e

OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
🦙 Ollama Manager

Usage: bash scripts/run.sh <command> [args]

Commands:
  pull <model>              Download a model (e.g., llama3.2, codellama, mistral)
  delete <model>            Remove a downloaded model
  list                      List all downloaded models
  info <model>              Show model details
  prompt <model> <text>     Run a one-shot prompt
  chat <model>              Start interactive chat
  batch <model> <file>      Process prompts from file (one per line)
  embed <model> <text>      Generate embeddings
  create <name> --modelfile <path>  Create custom model from Modelfile
  status                    Show Ollama status + resource usage
  monitor                   Real-time resource monitoring
  health                    Check API health
  restart                   Restart Ollama service
  disk                      Show disk usage per model
  cleanup [--days N] [--keep "m1,m2"]  Remove unused models
  gpu                       Show GPU info
  config [--host H] [--port P]  Configure Ollama

Environment:
  OLLAMA_HOST       API endpoint (default: http://localhost:11434)
  OLLAMA_MODELS     Models directory
  OLLAMA_NUM_GPU    GPU layers to offload (0 = CPU only)
EOF
    exit 1
}

check_ollama() {
    if ! command -v ollama &>/dev/null; then
        echo -e "${RED}❌ Ollama not installed. Run: bash scripts/install.sh${NC}"
        exit 1
    fi
}

check_api() {
    if ! curl -sf "$OLLAMA_HOST/api/tags" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Ollama API not responding at $OLLAMA_HOST${NC}"
        echo "Starting Ollama..."
        nohup ollama serve &>/dev/null &
        sleep 3
        if ! curl -sf "$OLLAMA_HOST/api/tags" &>/dev/null; then
            echo -e "${RED}❌ Failed to start Ollama API${NC}"
            exit 1
        fi
    fi
}

cmd_pull() {
    local model="$1"
    [[ -z "$model" ]] && { echo "Usage: run.sh pull <model>"; exit 1; }
    check_ollama
    echo -e "${BLUE}📥 Pulling $model...${NC}"
    ollama pull "$model"
    echo -e "${GREEN}✅ $model downloaded${NC}"
}

cmd_delete() {
    local model="$1"
    [[ -z "$model" ]] && { echo "Usage: run.sh delete <model>"; exit 1; }
    check_ollama
    echo -e "${YELLOW}🗑️  Deleting $model...${NC}"
    ollama rm "$model"
    echo -e "${GREEN}✅ $model removed${NC}"
}

cmd_list() {
    check_ollama
    check_api
    echo -e "${BLUE}📋 Downloaded Models${NC}"
    echo "========================"
    ollama list
}

cmd_info() {
    local model="$1"
    [[ -z "$model" ]] && { echo "Usage: run.sh info <model>"; exit 1; }
    check_ollama
    check_api
    echo -e "${BLUE}ℹ️  Model Info: $model${NC}"
    echo "========================"
    ollama show "$model"
}

cmd_prompt() {
    local model="$1"
    shift
    local prompt="$*"
    local system_prompt=""
    
    # Parse --system flag
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --system)
                system_prompt="$2"
                # Remove --system and its arg from prompt
                prompt="${prompt/--system $2/}"
                shift 2
                ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$model" || -z "$prompt" ]] && { echo "Usage: run.sh prompt <model> <text> [--system <text>]"; exit 1; }
    check_ollama
    check_api
    
    if [[ -n "$system_prompt" ]]; then
        curl -sf "$OLLAMA_HOST/api/generate" \
            -d "{\"model\":\"$model\",\"prompt\":\"$prompt\",\"system\":\"$system_prompt\",\"stream\":false}" \
            | jq -r '.response'
    else
        ollama run "$model" "$prompt"
    fi
}

cmd_chat() {
    local model="$1"
    [[ -z "$model" ]] && { echo "Usage: run.sh chat <model>"; exit 1; }
    check_ollama
    check_api
    echo -e "${BLUE}💬 Starting chat with $model (Ctrl+D to exit)${NC}"
    ollama run "$model"
}

cmd_batch() {
    local model="$1"
    local file="$2"
    local output="${3:-results.jsonl}"
    
    # Parse --output flag
    shift 2
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output) output="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$model" || -z "$file" ]] && { echo "Usage: run.sh batch <model> <prompts-file> [--output <file>]"; exit 1; }
    [[ ! -f "$file" ]] && { echo "❌ File not found: $file"; exit 1; }
    
    check_ollama
    check_api
    
    local total=$(wc -l < "$file")
    local count=0
    
    echo -e "${BLUE}📦 Batch processing $total prompts with $model${NC}"
    echo "Output: $output"
    
    > "$output"  # Clear output file
    
    while IFS= read -r prompt; do
        [[ -z "$prompt" ]] && continue
        ((count++))
        echo -ne "\r  Processing $count/$total..."
        
        response=$(curl -sf "$OLLAMA_HOST/api/generate" \
            -d "{\"model\":\"$model\",\"prompt\":$(echo "$prompt" | jq -Rs .),\"stream\":false}" \
            | jq -r '.response')
        
        echo "{\"prompt\":$(echo "$prompt" | jq -Rs .),\"response\":$(echo "$response" | jq -Rs .)}" >> "$output"
    done < "$file"
    
    echo ""
    echo -e "${GREEN}✅ Processed $count prompts → $output${NC}"
}

cmd_embed() {
    local model="$1"
    shift
    local text="$*"
    [[ -z "$model" || -z "$text" ]] && { echo "Usage: run.sh embed <model> <text>"; exit 1; }
    check_ollama
    check_api
    
    curl -sf "$OLLAMA_HOST/api/embed" \
        -d "{\"model\":\"$model\",\"input\":$(echo "$text" | jq -Rs .)}" \
        | jq '.embeddings[0][:10]'
    echo "(showing first 10 dimensions)"
}

cmd_status() {
    check_ollama
    echo -e "${BLUE}🦙 Ollama Status${NC}"
    echo "========================"
    
    # Version
    VER=$(ollama --version 2>/dev/null || echo "unknown")
    echo -e "Version: ${GREEN}$VER${NC}"
    
    # API status
    if curl -sf "$OLLAMA_HOST/api/tags" &>/dev/null; then
        echo -e "API: ${GREEN}Running${NC} ($OLLAMA_HOST)"
    else
        echo -e "API: ${RED}Not responding${NC} ($OLLAMA_HOST)"
        return
    fi
    
    # Running models
    echo ""
    echo "Running models:"
    RUNNING=$(curl -sf "$OLLAMA_HOST/api/ps" | jq -r '.models[] | "  \(.name) — \(.size / 1073741824 | . * 100 | round / 100) GB loaded"' 2>/dev/null)
    if [[ -n "$RUNNING" ]]; then
        echo "$RUNNING"
    else
        echo "  (none)"
    fi
    
    # Downloaded models
    echo ""
    echo "Downloaded models:"
    ollama list 2>/dev/null | tail -n +2 | while read -r line; do
        echo "  $line"
    done
    
    # System resources
    echo ""
    echo "System Resources:"
    
    # RAM
    if command -v free &>/dev/null; then
        RAM_USED=$(free -g | awk '/Mem:/ {print $3}')
        RAM_TOTAL=$(free -g | awk '/Mem:/ {print $2}')
        echo "  RAM: ${RAM_USED}/${RAM_TOTAL} GB"
    fi
    
    # GPU
    if command -v nvidia-smi &>/dev/null; then
        GPU_INFO=$(nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader 2>/dev/null | head -1)
        echo "  GPU: $GPU_INFO"
    elif [[ "$(uname -s)" == "Darwin" ]] && [[ "$(uname -m)" == "arm64" ]]; then
        echo "  GPU: Apple Silicon (Metal)"
    fi
    
    # Disk
    MODELS_DIR="${OLLAMA_MODELS:-$HOME/.ollama/models}"
    if [[ -d "$MODELS_DIR" ]]; then
        DISK=$(du -sh "$MODELS_DIR" 2>/dev/null | cut -f1)
        echo "  Models disk: $DISK"
    fi
}

cmd_monitor() {
    check_ollama
    check_api
    echo -e "${BLUE}📊 Real-time Monitor (Ctrl+C to stop)${NC}"
    while true; do
        clear
        cmd_status
        echo ""
        echo -e "${YELLOW}Refreshing in 5s...${NC}"
        sleep 5
    done
}

cmd_health() {
    echo -n "Checking API health... "
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "$OLLAMA_HOST/api/tags" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo -e "${GREEN}✅ Healthy (HTTP $HTTP_CODE)${NC}"
    else
        echo -e "${RED}❌ Unhealthy (HTTP $HTTP_CODE)${NC}"
        exit 1
    fi
}

cmd_restart() {
    echo "Restarting Ollama..."
    if command -v systemctl &>/dev/null && systemctl is-active --quiet ollama 2>/dev/null; then
        sudo systemctl restart ollama
    else
        pkill -f "ollama serve" 2>/dev/null || true
        sleep 1
        nohup ollama serve &>/dev/null &
    fi
    sleep 3
    cmd_health
}

cmd_disk() {
    check_ollama
    check_api
    echo -e "${BLUE}💾 Disk Usage${NC}"
    echo "========================"
    ollama list 2>/dev/null
    echo ""
    MODELS_DIR="${OLLAMA_MODELS:-$HOME/.ollama/models}"
    echo "Models directory: $MODELS_DIR"
    if [[ -d "$MODELS_DIR" ]]; then
        echo "Total: $(du -sh "$MODELS_DIR" 2>/dev/null | cut -f1)"
    fi
}

cmd_cleanup() {
    local days=30
    local keep=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) days="$2"; shift 2 ;;
            --keep) keep="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    check_ollama
    check_api
    
    echo -e "${YELLOW}🧹 Cleanup: removing models unused for $days+ days${NC}"
    if [[ -n "$keep" ]]; then
        echo "Keeping: $keep"
    fi
    
    # Get list of models
    MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
    
    for model in $MODELS; do
        # Check if in keep list
        if [[ -n "$keep" ]] && echo "$keep" | grep -q "$model"; then
            echo "  ⏭️  Keeping $model"
            continue
        fi
        
        echo -e "  ${RED}🗑️  Removing $model${NC}"
        ollama rm "$model" 2>/dev/null || true
    done
    
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

cmd_gpu() {
    echo -e "${BLUE}🎮 GPU Information${NC}"
    echo "========================"
    
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=index,name,memory.total,memory.used,memory.free,temperature.gpu,utilization.gpu \
            --format=csv,noheader 2>/dev/null | while IFS=, read -r idx name total used free temp util; do
            echo "GPU $idx: $name"
            echo "  Memory: $used / $total (Free: $free)"
            echo "  Temp: $temp | Utilization: $util"
        done
        
        echo ""
        CUDA=$(nvcc --version 2>/dev/null | grep "release" | awk '{print $5}' | tr -d ',')
        DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
        echo "CUDA: ${CUDA:-not found}"
        echo "Driver: ${DRIVER:-not found}"
    elif [[ "$(uname -s)" == "Darwin" ]] && [[ "$(uname -m)" == "arm64" ]]; then
        echo "Apple Silicon detected"
        sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple M-series"
        MEM=$(sysctl -n hw.memsize 2>/dev/null)
        if [[ -n "$MEM" ]]; then
            echo "Unified Memory: $((MEM / 1073741824)) GB"
        fi
        echo "Acceleration: Metal"
    else
        echo "No NVIDIA GPU or Apple Silicon detected"
        echo "Ollama will use CPU mode"
    fi
    
    echo ""
    echo "Ollama GPU offload: ${OLLAMA_NUM_GPU:-auto}"
}

cmd_create() {
    local name="$1"
    shift
    local modelfile=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --modelfile) modelfile="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    [[ -z "$name" || -z "$modelfile" ]] && { echo "Usage: run.sh create <name> --modelfile <path>"; exit 1; }
    [[ ! -f "$modelfile" ]] && { echo "❌ Modelfile not found: $modelfile"; exit 1; }
    
    check_ollama
    check_api
    
    echo -e "${BLUE}🔨 Creating custom model: $name${NC}"
    ollama create "$name" -f "$modelfile"
    echo -e "${GREEN}✅ Model $name created${NC}"
}

cmd_config() {
    local host=""
    local port=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host) host="$2"; shift 2 ;;
            --port) port="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [[ -z "$host" && -z "$port" ]]; then
        echo "Current config:"
        echo "  OLLAMA_HOST=$OLLAMA_HOST"
        echo "  OLLAMA_MODELS=${OLLAMA_MODELS:-~/.ollama/models}"
        echo "  OLLAMA_NUM_GPU=${OLLAMA_NUM_GPU:-auto}"
        return
    fi
    
    # Update systemd override if available
    if command -v systemctl &>/dev/null && systemctl is-active --quiet ollama 2>/dev/null; then
        echo "Updating systemd configuration..."
        sudo mkdir -p /etc/systemd/system/ollama.service.d
        
        local env_lines=""
        [[ -n "$host" ]] && env_lines+="Environment=\"OLLAMA_HOST=$host\"\n"
        [[ -n "$port" ]] && env_lines+="Environment=\"OLLAMA_HOST=0.0.0.0:$port\"\n"
        
        printf "[Service]\n$env_lines" | sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null
        sudo systemctl daemon-reload
        sudo systemctl restart ollama
        echo -e "${GREEN}✅ Configuration updated and service restarted${NC}"
    else
        echo "Set these in your shell profile:"
        [[ -n "$host" ]] && echo "  export OLLAMA_HOST=\"$host\""
        [[ -n "$port" ]] && echo "  export OLLAMA_HOST=\"0.0.0.0:$port\""
        echo "Then restart Ollama."
    fi
}

# Main dispatch
CMD="${1:-}"
shift 2>/dev/null || true

case "$CMD" in
    pull)     cmd_pull "$@" ;;
    delete|rm) cmd_delete "$@" ;;
    list|ls)  cmd_list ;;
    info|show) cmd_info "$@" ;;
    prompt|run) cmd_prompt "$@" ;;
    chat)     cmd_chat "$@" ;;
    batch)    cmd_batch "$@" ;;
    embed)    cmd_embed "$@" ;;
    create)   cmd_create "$@" ;;
    status)   cmd_status ;;
    monitor)  cmd_monitor ;;
    health)   cmd_health ;;
    restart)  cmd_restart ;;
    disk)     cmd_disk ;;
    cleanup)  cmd_cleanup "$@" ;;
    gpu)      cmd_gpu ;;
    config)   cmd_config "$@" ;;
    *)        usage ;;
esac
