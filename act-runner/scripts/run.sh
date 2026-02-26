#!/bin/bash
# Wrapper for act with sensible defaults and helpers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat << 'EOF'
act-runner — Run GitHub Actions locally

USAGE:
  bash run.sh [command] [options]

COMMANDS:
  list              List all workflows and jobs
  run [event]       Run workflows (default: push)
  job <job-id>      Run a specific job
  dry-run [event]   Show execution plan without running
  secrets           Check secret configuration
  status            Check act + Docker status
  help              Show this help

OPTIONS:
  -w, --workflow    Specific workflow file
  -s, --secret      Add secret (KEY=VALUE)
  -f, --secret-file Path to secrets file
  -v, --verbose     Verbose output
  --reuse           Reuse containers between runs
  --privileged      Enable privileged mode (Docker-in-Docker)

EXAMPLES:
  bash run.sh list
  bash run.sh run push
  bash run.sh job build
  bash run.sh run pull_request -s GITHUB_TOKEN=ghp_xxx
  bash run.sh run -w .github/workflows/deploy.yml --reuse
EOF
}

check_deps() {
  local ok=true
  
  if ! command -v act &>/dev/null; then
    echo -e "${RED}❌ act not found.${NC} Run: bash scripts/install.sh"
    ok=false
  fi
  
  if ! command -v docker &>/dev/null; then
    echo -e "${RED}❌ Docker not found.${NC}"
    ok=false
  elif ! docker info &>/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Docker not running.${NC} Start: sudo systemctl start docker"
    ok=false
  fi
  
  if [ ! -d ".github/workflows" ]; then
    echo -e "${YELLOW}⚠️  No .github/workflows/ directory found.${NC}"
    echo "  Make sure you're in a repo with GitHub Actions workflows."
    ok=false
  fi
  
  $ok || exit 1
}

cmd_status() {
  echo -e "${BLUE}=== Act Runner Status ===${NC}"
  echo ""
  
  if command -v act &>/dev/null; then
    echo -e "act:    ${GREEN}$(act --version 2>/dev/null)${NC}"
  else
    echo -e "act:    ${RED}Not installed${NC}"
  fi
  
  if command -v docker &>/dev/null; then
    if docker info &>/dev/null 2>&1; then
      echo -e "Docker: ${GREEN}Running$(docker --version | grep -oP 'Docker version \K[^,]+')${NC}"
    else
      echo -e "Docker: ${YELLOW}Installed but not running${NC}"
    fi
  else
    echo -e "Docker: ${RED}Not installed${NC}"
  fi
  
  echo ""
  echo "Images:"
  docker images --filter "reference=catthehacker/*" --format "  {{.Repository}}:{{.Tag}} ({{.Size}})" 2>/dev/null || echo "  None"
  
  if [ -f "$HOME/.actrc" ]; then
    echo ""
    echo "Config (~/.actrc):"
    sed 's/^/  /' "$HOME/.actrc"
  fi
}

cmd_list() {
  check_deps
  echo -e "${BLUE}=== Available Workflows ===${NC}"
  act -l "$@"
}

cmd_run() {
  check_deps
  local event="${1:-push}"
  shift 2>/dev/null || true
  echo -e "${BLUE}▶ Running event: ${event}${NC}"
  act "$event" "$@"
}

cmd_job() {
  check_deps
  local job="${1:?Job ID required. Use 'list' to see available jobs.}"
  shift
  echo -e "${BLUE}▶ Running job: ${job}${NC}"
  act -j "$job" "$@"
}

cmd_dry_run() {
  check_deps
  local event="${1:-push}"
  shift 2>/dev/null || true
  echo -e "${BLUE}=== Execution Plan (${event}) ===${NC}"
  act -n "$event" "$@"
}

cmd_secrets() {
  echo -e "${BLUE}=== Secret Configuration ===${NC}"
  
  if [ -f ".env" ]; then
    echo -e "${GREEN}✅ .env file found${NC} ($(wc -l < .env) lines)"
    echo "  Keys: $(grep -v '^#' .env | grep '=' | cut -d= -f1 | tr '\n' ', ' | sed 's/,$//')"
  else
    echo -e "${YELLOW}⚠️  No .env file${NC}"
  fi
  
  if [ -f ".secrets" ]; then
    echo -e "${GREEN}✅ .secrets file found${NC}"
  fi
  
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo -e "${GREEN}✅ GITHUB_TOKEN set in environment${NC}"
  else
    echo -e "${YELLOW}⚠️  GITHUB_TOKEN not set${NC}"
  fi
  
  echo ""
  echo "Usage: act -s KEY=VALUE or act --secret-file .env"
}

# Main
COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  list|ls)       cmd_list "$@" ;;
  run|r)         cmd_run "$@" ;;
  job|j)         cmd_job "$@" ;;
  dry-run|dry|n) cmd_dry_run "$@" ;;
  secrets|sec)   cmd_secrets ;;
  status|st)     cmd_status ;;
  help|--help|-h) usage ;;
  *)             echo "Unknown command: $COMMAND"; usage; exit 1 ;;
esac
