#!/bin/bash
# Modern CLI Toolkit — Shell Configuration
# Sets up aliases and integrations for installed tools
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect shell
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *zsh* ]]; then
  RC_FILE="$HOME/.zshrc"
  SHELL_NAME="zsh"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == *bash* ]]; then
  RC_FILE="$HOME/.bashrc"
  SHELL_NAME="bash"
elif [[ "$SHELL" == *fish* ]]; then
  RC_FILE="$HOME/.config/fish/config.fish"
  SHELL_NAME="fish"
  echo -e "${YELLOW}Fish shell detected — aliases use different syntax. Adding abbreviations.${NC}"
else
  RC_FILE="$HOME/.bashrc"
  SHELL_NAME="bash"
fi

echo -e "${BLUE}Configuring Modern CLI Toolkit for $SHELL_NAME ($RC_FILE)${NC}"
echo ""

MARKER_START="# >>> Modern CLI Toolkit >>>"
MARKER_END="# <<< Modern CLI Toolkit <<<"

# Remove old config if present
if grep -q "$MARKER_START" "$RC_FILE" 2>/dev/null; then
  echo -e "${YELLOW}Removing old Modern CLI Toolkit config...${NC}"
  sed -i "/$MARKER_START/,/$MARKER_END/d" "$RC_FILE"
fi

# Build config block
CONFIG="$MARKER_START"

# Aliases (only for installed tools)
if command -v eza &>/dev/null; then
  CONFIG+=$'\n'"alias ls='eza'"
  CONFIG+=$'\n'"alias ll='eza -la --icons --git'"
  CONFIG+=$'\n'"alias lt='eza --tree --level=2'"
  CONFIG+=$'\n'"alias la='eza -a'"
  echo -e "${GREEN}✅ eza aliases (ls, ll, lt, la)${NC}"
fi

if command -v bat &>/dev/null; then
  CONFIG+=$'\n'"alias cat='bat --paging=never'"
  CONFIG+=$'\n'"alias catp='bat'"
  CONFIG+=$'\n'"export BAT_THEME=\"Dracula\""
  echo -e "${GREEN}✅ bat aliases (cat, catp)${NC}"
fi

if command -v fd &>/dev/null; then
  CONFIG+=$'\n'"alias find='fd'"
  echo -e "${GREEN}✅ fd alias (find)${NC}"
fi

if command -v rg &>/dev/null; then
  CONFIG+=$'\n'"alias grep='rg'"
  echo -e "${GREEN}✅ ripgrep alias (grep)${NC}"
fi

if command -v dust &>/dev/null; then
  CONFIG+=$'\n'"alias du='dust'"
  echo -e "${GREEN}✅ dust alias (du)${NC}"
fi

if command -v duf &>/dev/null; then
  CONFIG+=$'\n'"alias df='duf'"
  echo -e "${GREEN}✅ duf alias (df)${NC}"
fi

if command -v procs &>/dev/null; then
  CONFIG+=$'\n'"alias ps='procs'"
  echo -e "${GREEN}✅ procs alias (ps)${NC}"
fi

if command -v btm &>/dev/null; then
  CONFIG+=$'\n'"alias top='btm'"
  echo -e "${GREEN}✅ bottom alias (top)${NC}"
fi

if command -v sd &>/dev/null; then
  # Don't alias sed→sd globally (too disruptive for scripts)
  # Just make sd available
  echo -e "${GREEN}✅ sd available (use 'sd' directly, not aliased over sed)${NC}"
fi

if command -v zoxide &>/dev/null; then
  CONFIG+=$'\n'"eval \"\$(zoxide init $SHELL_NAME)\""
  echo -e "${GREEN}✅ zoxide init (z, zi commands)${NC}"
fi

if command -v tokei &>/dev/null; then
  echo -e "${GREEN}✅ tokei available (use 'tokei' directly)${NC}"
fi

CONFIG+=$'\n'"$MARKER_END"

# Write config
echo "$CONFIG" >> "$RC_FILE"

# Configure git delta
if command -v delta &>/dev/null; then
  echo ""
  echo -e "${BLUE}Configuring git to use delta...${NC}"
  git config --global core.pager delta 2>/dev/null || true
  git config --global interactive.diffFilter "delta --color-only" 2>/dev/null || true
  git config --global delta.navigate true 2>/dev/null || true
  git config --global delta.side-by-side true 2>/dev/null || true
  git config --global delta.line-numbers true 2>/dev/null || true
  echo -e "${GREEN}✅ delta configured as git pager${NC}"
fi

# Create ripgrep config
if command -v rg &>/dev/null && [[ ! -f "$HOME/.ripgreprc" ]]; then
  echo ""
  echo -e "${BLUE}Creating ripgrep config...${NC}"
  cat > "$HOME/.ripgreprc" << 'EOF'
--smart-case
--hidden
--glob=!.git
--glob=!node_modules
--glob=!.next
--glob=!dist
--glob=!build
EOF
  # Add RIPGREP_CONFIG_PATH if not in rc
  if ! grep -q "RIPGREP_CONFIG_PATH" "$RC_FILE" 2>/dev/null; then
    sed -i "/$MARKER_END/i export RIPGREP_CONFIG_PATH=\"\$HOME/.ripgreprc\"" "$RC_FILE"
  fi
  echo -e "${GREEN}✅ ripgrep config created (~/.ripgreprc)${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  Configuration complete!${NC}"
echo -e "${GREEN}  Run: source $RC_FILE${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
