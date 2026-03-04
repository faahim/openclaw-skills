#!/bin/bash
# Create Zellij layout files from presets or custom specs
set -euo pipefail

LAYOUT_DIR="${HOME}/.config/zellij/layouts"
mkdir -p "$LAYOUT_DIR"

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[zellij-layout]${NC} $1"; }

PRESET="${1:-}"
LAYOUT_NAME=""
CUSTOM_PANES=""

# Parse args
shift || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --name) LAYOUT_NAME="$2"; shift 2 ;;
        --panes) CUSTOM_PANES="$2"; shift 2 ;;
        *) shift ;;
    esac
done

create_dev_layout() {
    local name="${LAYOUT_NAME:-dev}"
    cat > "$LAYOUT_DIR/${name}.kdl" << 'LAYOUT'
layout {
    pane size=1 borderless=true {
        plugin location="compact-bar"
    }
    pane split_direction="vertical" {
        pane size="60%" name="editor" focus=true
        pane split_direction="horizontal" {
            pane size="50%" name="terminal"
            pane size="50%" name="logs"
        }
    }
}
LAYOUT
    log "Created dev layout: $LAYOUT_DIR/${name}.kdl"
}

create_monitor_layout() {
    local name="${LAYOUT_NAME:-monitor}"
    cat > "$LAYOUT_DIR/${name}.kdl" << 'LAYOUT'
layout {
    pane size=1 borderless=true {
        plugin location="compact-bar"
    }
    pane split_direction="horizontal" {
        pane split_direction="vertical" size="60%" {
            pane size="50%" name="system" {
                command "htop"
            }
            pane size="50%" name="logs" {
                command "journalctl"
                args "-f" "--no-hostname"
            }
        }
        pane size="40%" name="custom"
    }
}
LAYOUT
    log "Created monitor layout: $LAYOUT_DIR/${name}.kdl"
}

create_api_layout() {
    local name="${LAYOUT_NAME:-api}"
    cat > "$LAYOUT_DIR/${name}.kdl" << 'LAYOUT'
layout {
    pane size=1 borderless=true {
        plugin location="compact-bar"
    }
    pane split_direction="horizontal" {
        pane split_direction="vertical" size="65%" {
            pane size="33%" name="server"
            pane size="33%" name="client"
            pane size="34%" name="logs"
        }
        pane size="35%" name="tests"
    }
}
LAYOUT
    log "Created API layout: $LAYOUT_DIR/${name}.kdl"
}

create_three_col_layout() {
    local name="${LAYOUT_NAME:-three-col}"
    cat > "$LAYOUT_DIR/${name}.kdl" << 'LAYOUT'
layout {
    pane size=1 borderless=true {
        plugin location="compact-bar"
    }
    pane split_direction="vertical" {
        pane size="33%" name="left"
        pane size="34%" name="center" focus=true
        pane size="33%" name="right"
    }
}
LAYOUT
    log "Created three-column layout: $LAYOUT_DIR/${name}.kdl"
}

create_custom_layout() {
    local name="${LAYOUT_NAME:-custom}"
    if [[ -z "$CUSTOM_PANES" ]]; then
        echo "Usage: $0 custom --name <name> --panes 'name1:size%,name2:size%,...'"
        exit 1
    fi

    local header='layout {\n    pane size=1 borderless=true {\n        plugin location="compact-bar"\n    }\n    pane split_direction="vertical" {'

    local body=""
    IFS=',' read -ra PANES <<< "$CUSTOM_PANES"
    local first=true
    for pane in "${PANES[@]}"; do
        local pname="${pane%%:*}"
        local psize="${pane##*:}"
        local focus=""
        if $first; then focus=' focus=true'; first=false; fi
        body+="\n        pane size=\"${psize}\" name=\"${pname}\"${focus}"
    done

    local footer='\n    }\n}'

    echo -e "${header}${body}${footer}" > "$LAYOUT_DIR/${name}.kdl"
    log "Created custom layout: $LAYOUT_DIR/${name}.kdl"
}

case "$PRESET" in
    dev) create_dev_layout ;;
    monitor) create_monitor_layout ;;
    api) create_api_layout ;;
    three-col) create_three_col_layout ;;
    custom) create_custom_layout ;;
    list)
        log "Available presets: dev, monitor, api, three-col, custom"
        log ""
        log "Existing layouts in $LAYOUT_DIR:"
        ls "$LAYOUT_DIR"/*.kdl 2>/dev/null | while read f; do
            echo "  - $(basename "$f" .kdl)"
        done
        ;;
    *)
        echo "Usage: $0 <preset|list> [--name <name>] [--panes 'name:size,...']"
        echo ""
        echo "Presets: dev, monitor, api, three-col, custom"
        echo ""
        echo "Examples:"
        echo "  $0 dev                              # Standard dev layout"
        echo "  $0 dev --name myproject              # Dev layout named 'myproject'"
        echo "  $0 custom --name work --panes 'code:70%,term:30%'"
        exit 1
        ;;
esac
