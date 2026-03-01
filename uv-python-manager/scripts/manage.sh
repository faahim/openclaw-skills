#!/bin/bash
# UV Python Manager — Management Script
# Common uv operations wrapped for convenience

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[uv]${NC} $*"; }
warn()  { echo -e "${YELLOW}[uv]${NC} $*"; }
error() { echo -e "${RED}[uv]${NC} $*" >&2; }
header(){ echo -e "\n${CYAN}═══ $* ═══${NC}"; }

usage() {
    cat << 'EOF'
UV Python Manager — manage.sh

Usage: bash manage.sh <command> [args...]

Commands:
  status              Show uv version, installed Pythons, cache size
  install-python VER  Install a Python version (e.g., 3.12)
  new NAME [--lib]    Create a new project
  add PKG [PKG...]    Add dependencies to current project
  dev PKG [PKG...]    Add dev dependencies
  run CMD [ARGS...]   Run a command in the project environment
  tool NAME           Install a CLI tool globally (like pipx)
  tools               List installed tools
  migrate             Migrate requirements.txt to pyproject.toml
  clean               Clean uv cache
  update              Update uv to latest version
  health              Check project health (outdated deps, etc.)

Examples:
  bash manage.sh status
  bash manage.sh install-python 3.12
  bash manage.sh new my-api
  bash manage.sh add fastapi uvicorn sqlalchemy
  bash manage.sh dev pytest ruff
  bash manage.sh run python main.py
  bash manage.sh tool ruff
  bash manage.sh migrate
  bash manage.sh health
EOF
}

check_uv() {
    if ! command -v uv &>/dev/null; then
        error "uv is not installed. Run: bash scripts/install.sh"
        exit 1
    fi
}

cmd_status() {
    check_uv
    header "UV Status"
    echo "Version:  $(uv --version)"
    echo "Cache:    $(uv cache dir)"
    echo "Size:     $(du -sh "$(uv cache dir)" 2>/dev/null | cut -f1 || echo 'N/A')"
    
    header "Installed Pythons"
    uv python list --only-installed 2>/dev/null || echo "  (none)"
    
    header "Installed Tools"
    uv tool list 2>/dev/null || echo "  (none)"
    
    if [[ -f "pyproject.toml" ]]; then
        header "Current Project"
        grep '^name' pyproject.toml 2>/dev/null || true
        grep 'requires-python' pyproject.toml 2>/dev/null || true
        echo "Dependencies: $(grep -c '^\s\+"' pyproject.toml 2>/dev/null || echo 0)"
    fi
}

cmd_install_python() {
    check_uv
    local ver="${1:?Usage: manage.sh install-python VERSION}"
    info "Installing Python $ver..."
    uv python install "$ver"
    info "✅ Python $ver installed"
    uv python list --only-installed
}

cmd_new() {
    check_uv
    local name="${1:?Usage: manage.sh new PROJECT_NAME [--lib]}"
    shift
    info "Creating project: $name"
    uv init "$name" "$@"
    info "✅ Project created at ./$name"
    echo ""
    info "Next steps:"
    info "  cd $name"
    info "  uv add <packages>"
    info "  uv run python main.py"
}

cmd_add() {
    check_uv
    [[ $# -eq 0 ]] && { error "Usage: manage.sh add PKG [PKG...]"; exit 1; }
    info "Adding: $*"
    uv add "$@"
    info "✅ Dependencies added"
}

cmd_dev() {
    check_uv
    [[ $# -eq 0 ]] && { error "Usage: manage.sh dev PKG [PKG...]"; exit 1; }
    info "Adding dev dependencies: $*"
    uv add --dev "$@"
    info "✅ Dev dependencies added"
}

cmd_run() {
    check_uv
    [[ $# -eq 0 ]] && { error "Usage: manage.sh run CMD [ARGS...]"; exit 1; }
    uv run "$@"
}

cmd_tool() {
    check_uv
    local name="${1:?Usage: manage.sh tool TOOL_NAME}"
    info "Installing tool: $name"
    uv tool install "$name"
    info "✅ $name installed globally"
}

cmd_tools() {
    check_uv
    header "Installed Tools"
    uv tool list
}

cmd_migrate() {
    check_uv
    if [[ ! -f "requirements.txt" ]]; then
        error "No requirements.txt found in current directory"
        exit 1
    fi
    
    if [[ -f "pyproject.toml" ]]; then
        warn "pyproject.toml already exists. Adding deps from requirements.txt..."
    else
        info "Initializing project..."
        uv init .
    fi
    
    info "Adding dependencies from requirements.txt..."
    local deps
    deps=$(grep -v '^\s*#' requirements.txt | grep -v '^\s*$' | tr '\n' ' ')
    if [[ -n "$deps" ]]; then
        uv add $deps
        info "✅ Migrated $(echo "$deps" | wc -w | tr -d ' ') dependencies"
    else
        warn "No dependencies found in requirements.txt"
    fi
}

cmd_clean() {
    check_uv
    local before
    before=$(du -sh "$(uv cache dir)" 2>/dev/null | cut -f1)
    info "Cache size before: $before"
    uv cache prune
    local after
    after=$(du -sh "$(uv cache dir)" 2>/dev/null | cut -f1)
    info "Cache size after: $after"
    info "✅ Cache cleaned"
}

cmd_update() {
    check_uv
    local before
    before=$(uv --version)
    info "Current: $before"
    uv self update 2>/dev/null || {
        warn "Self-update unavailable, reinstalling..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
    }
    info "Updated: $(uv --version)"
}

cmd_health() {
    check_uv
    header "Project Health Check"
    
    if [[ ! -f "pyproject.toml" ]]; then
        error "No pyproject.toml found. Not in a uv project."
        exit 1
    fi
    
    echo "Project: $(grep '^name' pyproject.toml | head -1)"
    echo "Python:  $(grep 'requires-python' pyproject.toml | head -1)"
    
    # Check if lock file exists
    if [[ -f "uv.lock" ]]; then
        info "Lock file: ✅ present"
    else
        warn "Lock file: ❌ missing (run 'uv lock')"
    fi
    
    # Check if venv exists
    if [[ -d ".venv" ]]; then
        info "Virtual env: ✅ present"
    else
        warn "Virtual env: ❌ missing (run 'uv sync')"
    fi
    
    # Try to check for outdated
    info "Checking dependency resolution..."
    uv lock --check 2>/dev/null && info "Dependencies: ✅ in sync" || warn "Dependencies: ⚠️ out of sync (run 'uv lock')"
}

# Main dispatch
case "${1:-help}" in
    status)         shift; cmd_status "$@" ;;
    install-python) shift; cmd_install_python "$@" ;;
    new)            shift; cmd_new "$@" ;;
    add)            shift; cmd_add "$@" ;;
    dev)            shift; cmd_dev "$@" ;;
    run)            shift; cmd_run "$@" ;;
    tool)           shift; cmd_tool "$@" ;;
    tools)          shift; cmd_tools "$@" ;;
    migrate)        shift; cmd_migrate "$@" ;;
    clean)          shift; cmd_clean "$@" ;;
    update)         shift; cmd_update "$@" ;;
    health)         shift; cmd_health "$@" ;;
    help|--help|-h) usage ;;
    *)              error "Unknown command: $1"; usage; exit 1 ;;
esac
