#!/bin/bash
# Configure Zellij — keybindings, themes, shell integration
set -euo pipefail

CONFIG_DIR="$HOME/.config/zellij"
CONFIG_FILE="$CONFIG_DIR/config.kdl"
mkdir -p "$CONFIG_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log() { echo -e "${GREEN}[zellij-config]${NC} $1"; }
warn() { echo -e "${YELLOW}[zellij-config]${NC} $1"; }

ACTION="${1:-}"
shift || true

apply_keybindings() {
    # Backup existing config
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        warn "Backed up existing config to ${CONFIG_FILE}.bak"
    fi

    cat > "$CONFIG_FILE" << 'CONFIG'
// Zellij Configuration — Managed by zellij-manager
// Prefix: Ctrl+a (tmux-like)

keybinds clear-defaults=true {
    normal {
        // Pane management
        bind "Ctrl a" { SwitchToMode "tmux"; }
    }
    tmux {
        bind "Esc" "q" { SwitchToMode "Normal"; }
        // Panes
        bind "|" { NewPane "Right"; SwitchToMode "Normal"; }
        bind "-" { NewPane "Down"; SwitchToMode "Normal"; }
        bind "x" { CloseFocus; SwitchToMode "Normal"; }
        bind "z" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
        bind "f" { ToggleFloatingPanes; SwitchToMode "Normal"; }
        // Navigation
        bind "h" "Left" { MoveFocus "Left"; SwitchToMode "Normal"; }
        bind "j" "Down" { MoveFocus "Down"; SwitchToMode "Normal"; }
        bind "k" "Up" { MoveFocus "Up"; SwitchToMode "Normal"; }
        bind "l" "Right" { MoveFocus "Right"; SwitchToMode "Normal"; }
        // Tabs
        bind "c" { NewTab; SwitchToMode "Normal"; }
        bind "n" { GoToNextTab; SwitchToMode "Normal"; }
        bind "p" { GoToPreviousTab; SwitchToMode "Normal"; }
        bind "," { SwitchToMode "RenameTab"; }
        bind "w" { ToggleTab; SwitchToMode "Normal"; }
        bind "1" { GoToTab 1; SwitchToMode "Normal"; }
        bind "2" { GoToTab 2; SwitchToMode "Normal"; }
        bind "3" { GoToTab 3; SwitchToMode "Normal"; }
        bind "4" { GoToTab 4; SwitchToMode "Normal"; }
        bind "5" { GoToTab 5; SwitchToMode "Normal"; }
        // Session
        bind "d" { Detach; }
        bind "Space" { NextSwapLayout; SwitchToMode "Normal"; }
        // Resize
        bind "H" { Resize "Increase Left"; }
        bind "J" { Resize "Increase Down"; }
        bind "K" { Resize "Increase Up"; }
        bind "L" { Resize "Increase Right"; }
        // Scroll
        bind "[" { SwitchToMode "Scroll"; }
    }
    scroll {
        bind "Esc" "q" { SwitchToMode "Normal"; }
        bind "j" "Down" { ScrollDown; }
        bind "k" "Up" { ScrollUp; }
        bind "d" { HalfPageScrollDown; }
        bind "u" { HalfPageScrollUp; }
        bind "G" { ScrollToBottom; SwitchToMode "Normal"; }
    }
    renametab {
        bind "Esc" { UndoRenameTab; SwitchToMode "Normal"; }
        bind "Enter" { SwitchToMode "Normal"; }
    }
    shared_except "normal" "tmux" {
        bind "Ctrl a" { SwitchToMode "tmux"; }
    }
}

// General options
pane_frames false
default_layout "compact"
default_shell "bash"
scrollback_editor "nvim"
copy_on_select true
mouse_mode true
CONFIG

    log "✅ Applied tmux-like keybindings to $CONFIG_FILE"
    log ""
    log "Key bindings:"
    log "  Ctrl+a |     Split vertical"
    log "  Ctrl+a -     Split horizontal"
    log "  Ctrl+a h/j/k/l  Navigate panes"
    log "  Ctrl+a c     New tab"
    log "  Ctrl+a n/p   Next/prev tab"
    log "  Ctrl+a 1-5   Go to tab N"
    log "  Ctrl+a x     Close pane"
    log "  Ctrl+a z     Fullscreen pane"
    log "  Ctrl+a f     Float pane"
    log "  Ctrl+a d     Detach session"
    log "  Ctrl+a [     Scroll mode"
}

apply_theme() {
    local theme="${1:-}"

    case "$theme" in
        --list)
            log "Available themes:"
            echo "  dracula"
            echo "  catppuccin-mocha"
            echo "  nord"
            echo "  gruvbox-dark"
            echo "  tokyo-night"
            echo "  one-half-dark"
            echo "  solarized-dark"
            return
            ;;
        --apply)
            theme="${2:-}"
            if [[ -z "$theme" ]]; then
                echo "Usage: $0 themes --apply <theme-name>"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 themes --list | --apply <theme-name>"
            exit 1
            ;;
    esac

    # Check if config exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        warn "No config file found. Creating one first..."
        apply_keybindings
    fi

    # Remove existing theme line and append new one
    if grep -q "^theme " "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s/^theme .*/theme \"$theme\"/" "$CONFIG_FILE"
    else
        echo "" >> "$CONFIG_FILE"
        echo "theme \"$theme\"" >> "$CONFIG_FILE"
    fi

    log "✅ Applied theme: $theme"
    log "Restart Zellij to see changes."
}

setup_shell_integration() {
    local shell_rc=""
    local current_shell="$(basename "$SHELL")"

    case "$current_shell" in
        bash) shell_rc="$HOME/.bashrc" ;;
        zsh) shell_rc="$HOME/.zshrc" ;;
        fish) shell_rc="$HOME/.config/fish/config.fish" ;;
        *) warn "Unknown shell: $current_shell. Add manually."; return ;;
    esac

    local marker="# >>> zellij-manager >>>"
    if grep -q "$marker" "$shell_rc" 2>/dev/null; then
        warn "Shell integration already exists in $shell_rc"
        return
    fi

    cat >> "$shell_rc" << 'INTEGRATION'

# >>> zellij-manager >>>
# Auto-start Zellij (skip if already in session or in SSH without multiplexer)
if [[ -z "$ZELLIJ" && -z "$TMUX" ]]; then
    if command -v zellij &>/dev/null; then
        eval "$(zellij setup --generate-auto-start bash 2>/dev/null || true)"
    fi
fi
# <<< zellij-manager <<<
INTEGRATION

    log "✅ Added shell integration to $shell_rc"
    log "Restart your shell or run: source $shell_rc"
}

case "$ACTION" in
    keybindings|keys) apply_keybindings ;;
    themes|theme) apply_theme "$@" ;;
    shell-integration|shell) setup_shell_integration ;;
    *)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  keybindings          Apply tmux-like keybinding preset"
        echo "  themes --list        List available themes"
        echo "  themes --apply <n>   Apply a theme"
        echo "  shell-integration    Add auto-start to shell profile"
        exit 1
        ;;
esac
