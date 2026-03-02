---
name: modern-cli-toolkit
description: >-
  Install and configure modern replacements for core Unix CLI tools.
  Transform your terminal with faster, friendlier, more powerful commands.
categories: [dev-tools, productivity]
dependencies: [bash, curl]
---

# Modern CLI Toolkit

## What This Does

Installs 10+ modern replacements for core Unix commands — faster, more colorful, more intuitive. One command transforms your entire terminal experience with tools like `eza` (ls), `bat` (cat), `fd` (find), `rg` (grep), `delta` (diff), and more. Configures shell aliases so you get the benefits without changing muscle memory.

**Before & After:** Your plain `ls` becomes a color-coded, git-aware file listing. Your `cat` gets syntax highlighting. Your `find` becomes 5x faster. Your `diff` gets side-by-side colored output.

## Quick Start (5 minutes)

### 1. Install Everything

```bash
# Detect OS and install all tools
bash scripts/install.sh

# Or install specific tools only
bash scripts/install.sh --only eza,bat,fd,rg
```

### 2. Configure Shell Aliases

```bash
# Set up aliases (adds to ~/.bashrc or ~/.zshrc)
bash scripts/configure.sh

# Apply immediately
source ~/.bashrc  # or source ~/.zshrc
```

### 3. Verify Installation

```bash
bash scripts/verify.sh
# Output:
# ✅ eza (ls replacement) — v0.19.4
# ✅ bat (cat replacement) — v0.24.0
# ✅ fd (find replacement) — v10.2.0
# ✅ rg (grep replacement) — v14.1.1
# ✅ delta (diff replacement) — v0.18.2
# ✅ dust (du replacement) — v1.1.1
# ✅ duf (df replacement) — v0.8.1
# ✅ procs (ps replacement) — v0.14.8
# ✅ btm (top replacement) — v0.10.2
# ✅ zoxide (cd replacement) — v0.9.6
# ✅ sd (sed replacement) — v1.0.0
# ✅ tokei (line counter) — v12.1.2
```

## The Tools

### eza → replaces `ls`

```bash
# Tree view with git status
eza --tree --level=2 --git

# Long listing with icons
eza -la --icons --git

# Sort by modified time
eza -la --sort=modified
```

### bat → replaces `cat`

```bash
# Syntax-highlighted file viewing
bat script.py

# Show specific line range
bat --line-range 10:20 config.yaml

# Plain output (for piping)
bat --plain file.txt | wc -l
```

### fd → replaces `find`

```bash
# Find files by name (5x faster than find)
fd "\.py$"

# Find and execute command
fd "\.log$" --exec gzip {}

# Respect .gitignore by default
fd "config" --hidden --no-ignore
```

### ripgrep (rg) → replaces `grep`

```bash
# Search recursively (blazing fast)
rg "TODO" --type py

# Search with context
rg "error" -C 3 --glob "*.log"

# Count matches per file
rg "import" --count
```

### delta → replaces `diff`

```bash
# Side-by-side diff with syntax highlighting
delta file1.txt file2.txt

# Git integration (set as default pager)
git diff  # automatically uses delta
```

### dust → replaces `du`

```bash
# Visual disk usage (bar chart)
dust

# Show specific depth
dust -d 2 /var/log

# Reverse sort (smallest first)
dust -r
```

### duf → replaces `df`

```bash
# Beautiful disk usage table
duf

# Show only local filesystems
duf --only local

# JSON output for scripting
duf --json
```

### procs → replaces `ps`

```bash
# Colored process list with tree view
procs --tree

# Search processes
procs --keyword nginx

# Watch mode (like top but better)
procs --watch
```

### bottom (btm) → replaces `top`/`htop`

```bash
# Interactive system monitor
btm

# Battery widget included
btm --battery

# Minimal mode
btm --basic
```

### zoxide → replaces `cd`

```bash
# Jump to frequently used dirs
z projects    # jumps to ~/projects
z doc         # jumps to ~/Documents

# Interactive selection
zi

# Add directory manually
zoxide add /path/to/dir
```

### sd → replaces `sed`

```bash
# Simple find and replace (no escape hell)
sd 'before' 'after' file.txt

# Regex support
sd 'v(\d+)' 'version_$1' changelog.md

# Preview changes
sd -p 'old' 'new' file.txt
```

### tokei → code statistics

```bash
# Count lines of code by language
tokei

# Specific directory
tokei src/

# Exclude directories
tokei --exclude vendor
```

## Configuration

### Git Integration (delta)

The install script automatically configures git to use delta:

```gitconfig
# Added to ~/.gitconfig
[core]
    pager = delta
[interactive]
    diffFilter = delta --color-only
[delta]
    navigate = true
    side-by-side = true
    line-numbers = true
```

### Shell Aliases

The configure script adds these aliases:

```bash
# Added to ~/.bashrc or ~/.zshrc
alias ls='eza'
alias ll='eza -la --icons --git'
alias lt='eza --tree --level=2'
alias cat='bat --paging=never'
alias find='fd'
alias grep='rg'
alias du='dust'
alias df='duf'
alias ps='procs'
alias top='btm'
alias sed='sd'
alias diff='delta'
```

### Zoxide Shell Init

```bash
# Added to shell rc file
eval "$(zoxide init bash)"   # or zsh/fish
```

## Advanced Usage

### Custom bat Theme

```bash
# List available themes
bat --list-themes

# Set theme
export BAT_THEME="Dracula"
# Or add to shell rc for persistence
```

### Ripgrep Config

```bash
# Create ~/.ripgreprc
echo '--smart-case
--hidden
--glob=!.git
--glob=!node_modules' > ~/.ripgreprc

export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
```

### Selective Installation

```bash
# Install only specific tools
bash scripts/install.sh --only eza,bat,rg,fd

# Skip tools you already have
bash scripts/install.sh --skip procs,btm

# Update all tools to latest
bash scripts/install.sh --update
```

### Uninstall

```bash
# Remove all tools and aliases
bash scripts/uninstall.sh

# Remove specific tool
bash scripts/uninstall.sh --only eza
```

## Troubleshooting

### Issue: "command not found" after installation

**Fix:** Source your shell config or open a new terminal:
```bash
source ~/.bashrc  # or ~/.zshrc
```

### Issue: Icons not showing (eza)

**Fix:** Install a Nerd Font:
```bash
# The icons flag requires a patched font
# Download from: https://www.nerdfonts.com/
# Or use without icons: eza -la --git
```

### Issue: bat not detecting language

**Fix:** Use `--language` flag:
```bash
bat --language=json config
```

### Issue: Aliases conflict with existing tools

**Fix:** Use original commands with full path:
```bash
/usr/bin/ls        # original ls
/usr/bin/cat       # original cat
command ls         # also works
```

## Platform Support

| Tool | Linux (apt) | Linux (brew) | macOS (brew) | Cargo |
|------|-------------|--------------|--------------|-------|
| eza | ✅ | ✅ | ✅ | ✅ |
| bat | ✅ | ✅ | ✅ | ✅ |
| fd | ✅ | ✅ | ✅ | ✅ |
| rg | ✅ | ✅ | ✅ | ✅ |
| delta | ✅ | ✅ | ✅ | ✅ |
| dust | ✅ | ✅ | ✅ | ✅ |
| duf | ✅ | ✅ | ✅ | — |
| procs | ✅ | ✅ | ✅ | ✅ |
| btm | ✅ | ✅ | ✅ | ✅ |
| zoxide | ✅ | ✅ | ✅ | ✅ |
| sd | ✅ | ✅ | ✅ | ✅ |
| tokei | ✅ | ✅ | ✅ | ✅ |

## Dependencies

- `bash` (4.0+)
- `curl` (for downloading)
- Package manager: `apt`, `brew`, or `cargo`
