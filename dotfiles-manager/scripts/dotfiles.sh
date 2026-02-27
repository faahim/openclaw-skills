#!/bin/bash
# Dotfiles Manager — Backup, restore, and sync dotfiles with Git + GNU Stow
# Usage: bash dotfiles.sh <command> [options]

set -euo pipefail

# --- Configuration ---
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_CONFIG="$DOTFILES_DIR/.dotfiles.yml"
BACKUP_SUFFIX="dotfiles-backup.$(date +%Y%m%d%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $*${NC}"; }
log_info() { echo -e "${BLUE}📦 $*${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_err()  { echo -e "${RED}❌ $*${NC}" >&2; }
log_link() { echo -e "${BLUE}🔗 $*${NC}"; }

# --- Dependency Check ---
check_deps() {
  local missing=()
  for cmd in git stow; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_err "Missing dependencies: ${missing[*]}"
    echo "Install with:"
    echo "  Ubuntu/Debian: sudo apt-get install ${missing[*]}"
    echo "  macOS:         brew install ${missing[*]}"
    exit 1
  fi
}

# --- Commands ---

cmd_init() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log_warn "Dotfiles repo already exists at $DOTFILES_DIR"
    return 0
  fi

  mkdir -p "$DOTFILES_DIR"
  cd "$DOTFILES_DIR"
  git init

  # Create default packages
  local default_pkgs=(bash git vim ssh tmux)
  for pkg in "${default_pkgs[@]}"; do
    mkdir -p "$pkg"
  done

  # Create config file
  cat > "$DOTFILES_CONFIG" <<EOF
# Dotfiles Manager Configuration
dotfiles_dir: $DOTFILES_DIR
target: $HOME
machine_tag: $(hostname)
auto_apply:
  - bash
  - git
EOF

  # Create .gitignore
  cat > "$DOTFILES_DIR/.gitignore" <<EOF
# SSH private keys (NEVER commit these)
ssh/.ssh/id_*
ssh/.ssh/*.pem
!ssh/.ssh/config
*.dotfiles-backup.*
EOF

  git add -A
  git commit -m "Initial dotfiles setup"

  log_ok "Created $DOTFILES_DIR"
  log_ok "Initialized Git repo"
  log_info "Created package directories: ${default_pkgs[*]}"
  log_ok "Ready to adopt your configs"
}

cmd_adopt() {
  local force=false
  local tag=""
  local pkg=""
  local files=()

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=true; shift ;;
      --tag)   tag="$2"; shift 2 ;;
      *)
        if [[ -z "$pkg" ]]; then
          pkg="$1"
        else
          files+=("$1")
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$pkg" ]] || [[ ${#files[@]} -eq 0 ]]; then
    log_err "Usage: dotfiles adopt <package> <file1> [file2...] [--tag name] [--force]"
    exit 1
  fi

  # Apply tag to package name if specified
  local pkg_dir="$DOTFILES_DIR/$pkg"
  [[ -n "$tag" ]] && pkg_dir="$DOTFILES_DIR/${pkg}-${tag}"
  [[ -n "$tag" ]] && pkg="${pkg}-${tag}"

  mkdir -p "$pkg_dir"
  local adopted=0

  for file in "${files[@]}"; do
    local abs_file
    abs_file=$(realpath -m "$file")

    # Determine relative path from HOME
    local rel_path="${abs_file#$HOME/}"
    if [[ "$rel_path" == "$abs_file" ]]; then
      log_err "$file is not under \$HOME — can't adopt"
      continue
    fi

    local dest="$pkg_dir/$rel_path"
    local dest_dir
    dest_dir=$(dirname "$dest")
    mkdir -p "$dest_dir"

    if [[ -L "$abs_file" ]]; then
      log_warn "$file is already a symlink — skipping"
      continue
    fi

    if [[ -e "$abs_file" ]]; then
      # Backup existing file
      if [[ -e "$dest" ]] && [[ "$force" != true ]]; then
        log_warn "$rel_path already in package '$pkg' — use --force to overwrite"
        continue
      fi

      cp -a "$abs_file" "$dest"
      log_info "Adopted $rel_path → $pkg_dir/$rel_path"
      adopted=$((adopted + 1))
    else
      log_warn "$file does not exist — skipping"
    fi
  done

  if [[ $adopted -gt 0 ]]; then
    # Now stow: remove originals and create symlinks
    _stow_package "$pkg"
    log_ok "$adopted file(s) adopted into '$pkg' package"
  fi
}

cmd_apply() {
  local all=false
  local restow=false
  local dry_run=false
  local tag=""
  local packages=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)     all=true; shift ;;
      --restow)  restow=true; shift ;;
      --dry-run) dry_run=true; shift ;;
      --tag)     tag="$2"; shift 2 ;;
      *)         packages+=("$1"); shift ;;
    esac
  done

  cd "$DOTFILES_DIR"

  if $all; then
    # Get all directories (packages)
    for d in */; do
      [[ -d "$d" ]] && packages+=("${d%/}")
    done
  fi

  if [[ ${#packages[@]} -eq 0 ]]; then
    log_err "No packages specified. Use --all or list packages."
    exit 1
  fi

  local stow_opts=(-t "$HOME" -d "$DOTFILES_DIR")
  $restow && stow_opts+=(--restow)
  $dry_run && stow_opts+=(--simulate -v)

  for pkg in "${packages[@]}"; do
    # Skip if tag filtering and package doesn't match
    if [[ -n "$tag" ]] && [[ "$pkg" == *-* ]]; then
      local pkg_tag="${pkg##*-}"
      [[ "$pkg_tag" != "$tag" ]] && continue
    fi

    if [[ ! -d "$DOTFILES_DIR/$pkg" ]]; then
      log_warn "Package '$pkg' not found — skipping"
      continue
    fi

    # Count files
    local count
    count=$(find "$DOTFILES_DIR/$pkg" -type f ! -name '.gitkeep' | wc -l)

    if $dry_run; then
      echo "Would stow '$pkg' ($count files)"
      stow "${stow_opts[@]}" "$pkg" 2>&1 || true
    else
      # Backup conflicting files first
      _backup_conflicts "$pkg"
      stow "${stow_opts[@]}" "$pkg" 2>/dev/null || stow "${stow_opts[@]}" --restow "$pkg"
      log_link "Stowed $pkg → $count file(s)"
    fi
  done

  $dry_run || log_ok "All packages applied"
}

cmd_clone() {
  local remote="$1"

  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log_warn "Dotfiles repo already exists at $DOTFILES_DIR"
    echo "Use 'dotfiles sync' to pull updates."
    return 1
  fi

  git clone "$remote" "$DOTFILES_DIR"
  log_ok "Cloned dotfiles to $DOTFILES_DIR"
}

cmd_sync() {
  cd "$DOTFILES_DIR"

  # Pull latest
  local before
  before=$(git rev-parse HEAD)
  git pull --rebase 2>/dev/null || git pull

  local after
  after=$(git rev-parse HEAD)

  if [[ "$before" == "$after" ]]; then
    log_ok "Already up to date"
    return 0
  fi

  local commits
  commits=$(git rev-list --count "$before".."$after")
  log_info "Pulled $commits new commit(s)"

  # Re-stow all packages
  for d in */; do
    [[ -d "$d" ]] || continue
    local pkg="${d%/}"
    stow -t "$HOME" -d "$DOTFILES_DIR" --restow "$pkg" 2>/dev/null && \
      log_link "Re-stowed $pkg" || \
      log_warn "Failed to restow $pkg"
  done

  log_ok "All packages synced"
}

cmd_push() {
  local msg="${1:-Update dotfiles $(date +%Y-%m-%d)}"
  cd "$DOTFILES_DIR"

  git add -A
  if git diff --cached --quiet; then
    log_ok "Nothing to commit"
    return 0
  fi

  git commit -m "$msg"
  git push
  log_ok "Pushed dotfiles"
}

cmd_status() {
  cd "$DOTFILES_DIR"

  echo -e "\n${BLUE}📦 Packages:${NC}"
  for d in */; do
    [[ -d "$d" ]] || continue
    local pkg="${d%/}"
    local count
    count=$(find "$DOTFILES_DIR/$pkg" -type f ! -name '.gitkeep' | wc -l)

    # Check if stowed (check first file)
    local stowed="⚠️  not stowed"
    local first_file
    first_file=$(find "$DOTFILES_DIR/$pkg" -type f ! -name '.gitkeep' -print -quit 2>/dev/null)
    if [[ -n "$first_file" ]]; then
      local rel="${first_file#$DOTFILES_DIR/$pkg/}"
      if [[ -L "$HOME/$rel" ]]; then
        stowed="✅ stowed"
      fi
    fi

    printf "  %-16s → %d file(s) (%s)\n" "$pkg" "$count" "$stowed"
  done

  echo -e "\n${BLUE}📝 Git status:${NC}"
  git status --short | head -20
  local total
  total=$(git status --short | wc -l)
  [[ $total -gt 20 ]] && echo "  ... and $((total - 20)) more"
}

cmd_unstow() {
  local pkg="$1"
  if [[ -z "$pkg" ]]; then
    log_err "Usage: dotfiles unstow <package>"
    exit 1
  fi

  cd "$DOTFILES_DIR"
  stow -t "$HOME" -d "$DOTFILES_DIR" -D "$pkg"
  log_ok "Unstowed $pkg (symlinks removed, files kept in repo)"
}

cmd_remove() {
  local pkg="$1"
  if [[ -z "$pkg" ]]; then
    log_err "Usage: dotfiles remove <package>"
    exit 1
  fi

  cmd_unstow "$pkg"
  rm -rf "$DOTFILES_DIR/$pkg"
  log_ok "Removed package '$pkg' from dotfiles repo"
}

cmd_diff() {
  cd "$DOTFILES_DIR"
  git fetch origin 2>/dev/null
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  git diff "origin/$branch" 2>/dev/null || log_info "No remote to diff against"
}

cmd_export() {
  cd "$DOTFILES_DIR"
  local remote
  remote=$(git remote get-url origin 2>/dev/null || echo "YOUR_REPO_URL")

  cat <<SCRIPT
#!/bin/bash
# Auto-generated dotfiles setup script
set -e

DOTFILES_DIR="\$HOME/dotfiles"

# Install dependencies
if ! command -v stow &>/dev/null; then
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y stow git
  elif command -v brew &>/dev/null; then
    brew install stow git
  else
    echo "Please install git and stow manually"
    exit 1
  fi
fi

# Clone dotfiles
if [ ! -d "\$DOTFILES_DIR" ]; then
  git clone "$remote" "\$DOTFILES_DIR"
fi

cd "\$DOTFILES_DIR"

# Stow all packages
for d in */; do
  [ -d "\$d" ] || continue
  pkg="\${d%/}"
  echo "Stowing \$pkg..."
  stow -t "\$HOME" -d "\$DOTFILES_DIR" --restow "\$pkg" 2>/dev/null || true
done

echo "✅ Dotfiles applied!"
SCRIPT
}

# --- Helpers ---

_stow_package() {
  local pkg="$1"
  cd "$DOTFILES_DIR"

  # Remove original files that stow will replace
  while IFS= read -r -d '' file; do
    local rel="${file#$DOTFILES_DIR/$pkg/}"
    local target="$HOME/$rel"
    if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
      local backup="$target.$BACKUP_SUFFIX"
      mv "$target" "$backup"
      log_info "Backed up $rel → ${backup##*/}"
    fi
  done < <(find "$DOTFILES_DIR/$pkg" -type f -print0)

  stow -t "$HOME" -d "$DOTFILES_DIR" "$pkg"
  log_link "Stowed $pkg"
}

_backup_conflicts() {
  local pkg="$1"
  while IFS= read -r -d '' file; do
    local rel="${file#$DOTFILES_DIR/$pkg/}"
    local target="$HOME/$rel"
    if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
      local backup="$target.$BACKUP_SUFFIX"
      mv "$target" "$backup"
      log_info "Backed up $rel"
    fi
  done < <(find "$DOTFILES_DIR/$pkg" -type f -print0)
}

# --- Main ---

check_deps

CMD="${1:-help}"
shift || true

case "$CMD" in
  init)    cmd_init "$@" ;;
  adopt)   cmd_adopt "$@" ;;
  apply)   cmd_apply "$@" ;;
  clone)   cmd_clone "$@" ;;
  sync)    cmd_sync "$@" ;;
  push)    cmd_push "$@" ;;
  status)  cmd_status "$@" ;;
  unstow)  cmd_unstow "$@" ;;
  remove)  cmd_remove "$@" ;;
  diff)    cmd_diff "$@" ;;
  export)  cmd_export "$@" ;;
  help|--help|-h)
    echo "Dotfiles Manager — Backup, restore & sync dotfiles with Git + Stow"
    echo ""
    echo "Usage: dotfiles <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init                          Initialize dotfiles repo"
    echo "  adopt <pkg> <files...>        Add files to a package"
    echo "  apply [--all] [pkg...]        Apply (stow) packages"
    echo "  clone <url>                   Clone dotfiles from remote"
    echo "  sync                          Pull + re-stow all packages"
    echo "  push [msg]                    Commit and push changes"
    echo "  status                        Show packages and git status"
    echo "  unstow <pkg>                  Remove symlinks (keep files)"
    echo "  remove <pkg>                  Remove package entirely"
    echo "  diff                          Show remote vs local changes"
    echo "  export                        Generate standalone setup script"
    echo ""
    echo "Options:"
    echo "  --force                       Overwrite existing files"
    echo "  --tag <name>                  Machine-specific tag"
    echo "  --all                         Apply all packages"
    echo "  --restow                      Re-stow (fix broken links)"
    echo "  --dry-run                     Preview without changes"
    ;;
  *)
    log_err "Unknown command: $CMD"
    echo "Run 'dotfiles help' for usage."
    exit 1
    ;;
esac
