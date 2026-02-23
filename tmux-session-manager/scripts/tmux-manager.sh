#!/usr/bin/env bash
# Tmux Session Manager — Create, save, restore tmux sessions
set -euo pipefail

SESSIONS_DIR="${TMUX_SESSIONS_DIR:-$HOME/.tmux-sessions}"
PROFILES_DIR="$SESSIONS_DIR/profiles"
SAVED_DIR="$SESSIONS_DIR/saved"

mkdir -p "$PROFILES_DIR" "$SAVED_DIR"

# --- Helpers ---

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { echo "❌ Error: $*" >&2; exit 1; }

check_tmux() {
  command -v tmux >/dev/null 2>&1 || die "tmux not found. Install: sudo apt-get install -y tmux"
}

session_exists() {
  tmux has-session -t "$1" 2>/dev/null
}

# --- Commands ---

cmd_create() {
  local name="$1"; shift
  check_tmux

  if session_exists "$name"; then
    log "Session '$name' already exists. Attaching..."
    tmux attach-session -t "$name" 2>/dev/null || tmux switch-client -t "$name" 2>/dev/null || true
    return 0
  fi

  local windows=()
  local layouts=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window)
        windows+=("$2"); shift 2 ;;
      --layout)
        layouts+=("$2"); shift 2 ;;
      *)
        die "Unknown option: $1" ;;
    esac
  done

  # Create session with first window or default
  if [[ ${#layouts[@]} -gt 0 ]]; then
    local layout_spec="${layouts[0]}"
    local layout_type="${layout_spec%%:*}"
    local layout_cmds="${layout_spec#*:}"
    local cmd1="${layout_cmds%%|*}"
    local cmd2="${layout_cmds#*|}"

    tmux new-session -d -s "$name" -n "main"
    tmux send-keys -t "$name:main" "$cmd1" C-m

    case "$layout_type" in
      split-h)
        tmux split-window -h -t "$name:main"
        tmux send-keys -t "$name:main.1" "$cmd2" C-m
        ;;
      split-v)
        tmux split-window -v -t "$name:main"
        tmux send-keys -t "$name:main.1" "$cmd2" C-m
        ;;
    esac
  elif [[ ${#windows[@]} -gt 0 ]]; then
    local first="${windows[0]}"
    local win_name="${first%%:*}"
    local win_cmd="${first#*:}"
    tmux new-session -d -s "$name" -n "$win_name"
    [[ -n "$win_cmd" ]] && tmux send-keys -t "$name:$win_name" "$win_cmd" C-m
    windows=("${windows[@]:1}")
  else
    tmux new-session -d -s "$name"
  fi

  # Create additional windows
  for w in "${windows[@]}"; do
    local win_name="${w%%:*}"
    local win_cmd="${w#*:}"
    tmux new-window -t "$name" -n "$win_name"
    [[ -n "$win_cmd" ]] && tmux send-keys -t "$name:$win_name" "$win_cmd" C-m
  done

  # Select first window
  tmux select-window -t "$name:0"

  log "✅ Session '$name' created ($(tmux list-windows -t "$name" | wc -l) windows)"
}

cmd_save() {
  local name="$1"
  check_tmux

  if ! session_exists "$name"; then
    die "Session '$name' not found"
  fi

  local save_file="$SAVED_DIR/${name}.yaml"

  {
    echo "# Saved: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "name: $name"
    echo "windows:"

    tmux list-windows -t "$name" -F '#{window_index} #{window_name} #{pane_current_path}' | while read -r idx wname wpath; do
      echo "  - name: $wname"
      echo "    path: $wpath"

      local pane_count
      pane_count=$(tmux list-panes -t "$name:$idx" | wc -l)

      if [[ $pane_count -gt 1 ]]; then
        echo "    panes:"
        tmux list-panes -t "$name:$idx" -F '#{pane_current_path} #{pane_current_command}' | while read -r ppath pcmd; do
          echo "      - path: $ppath"
          echo "        command: $pcmd"
        done
      fi
    done
  } > "$save_file"

  log "✅ Session '$name' saved to $save_file"
}

cmd_save_all() {
  check_tmux
  local count=0

  tmux list-sessions -F '#{session_name}' 2>/dev/null | while read -r sname; do
    cmd_save "$sname"
    ((count++))
  done

  log "✅ All sessions saved"
}

cmd_restore() {
  local name="$1"
  check_tmux

  local save_file="$SAVED_DIR/${name}.yaml"
  [[ -f "$save_file" ]] || die "No saved session '$name' found at $save_file"

  if session_exists "$name"; then
    log "Session '$name' already running. Skipping restore."
    return 0
  fi

  # Simple YAML parser for our format
  local first_window=true
  local current_path=""

  while IFS= read -r line; do
    # Skip comments and metadata
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ "$line" =~ ^name:.*$ ]] && continue
    [[ "$line" =~ ^windows:.*$ ]] && continue

    # Window entry: "  - name: xxx"
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]name:[[:space:]]*(.*) ]]; then
      local wname="${BASH_REMATCH[1]}"
      current_path=""
      continue
    fi

    # Path: "    path: /some/path"
    if [[ "$line" =~ ^[[:space:]]*path:[[:space:]]*(.*) ]]; then
      current_path="${BASH_REMATCH[1]}"

      if $first_window; then
        tmux new-session -d -s "$name" -n "$wname" -c "$current_path"
        first_window=false
      else
        tmux new-window -t "$name" -n "$wname" -c "$current_path"
      fi
      continue
    fi
  done < "$save_file"

  tmux select-window -t "$name:0" 2>/dev/null || true
  log "✅ Session '$name' restored from $save_file"
}

cmd_restore_all() {
  check_tmux
  local count=0

  for f in "$SAVED_DIR"/*.yaml; do
    [[ -f "$f" ]] || continue
    local sname
    sname=$(basename "$f" .yaml)
    cmd_restore "$sname" || log "⚠️  Failed to restore '$sname'"
    ((count++))
  done

  log "✅ Restored $count sessions"
}

cmd_list() {
  check_tmux

  echo "=== Active Sessions ==="
  if tmux list-sessions 2>/dev/null; then
    :
  else
    echo "  (none)"
  fi

  echo ""
  echo "=== Saved Sessions ==="
  local found=false
  for f in "$SAVED_DIR"/*.yaml; do
    [[ -f "$f" ]] || continue
    found=true
    local sname
    sname=$(basename "$f" .yaml)
    local saved_at
    saved_at=$(head -1 "$f" | sed 's/# Saved: //')
    local wcount
    wcount=$(grep -c '  - name:' "$f" 2>/dev/null || echo 0)
    printf "  %-20s %d windows  (saved %s)\n" "$sname" "$wcount" "$saved_at"
  done
  $found || echo "  (none)"
}

cmd_kill() {
  local name="$1"
  check_tmux

  if session_exists "$name"; then
    tmux kill-session -t "$name"
    log "✅ Session '$name' killed"
  else
    die "Session '$name' not found"
  fi
}

cmd_attach() {
  local name="$1"
  check_tmux

  if ! session_exists "$name"; then
    # Try to restore from saved
    if [[ -f "$SAVED_DIR/${name}.yaml" ]]; then
      cmd_restore "$name"
    else
      log "Session '$name' not found. Creating empty session..."
      tmux new-session -d -s "$name"
    fi
  fi

  tmux attach-session -t "$name" 2>/dev/null || tmux switch-client -t "$name" 2>/dev/null || log "Use: tmux attach -t $name"
}

cmd_template() {
  local template="$1"
  local root="${2:-$(pwd)}"

  case "$template" in
    dev)
      cmd_create "dev" \
        --window "editor:cd $root && vim ." \
        --window "server:cd $root" \
        --window "git:cd $root && git log --oneline -20"
      ;;
    ops)
      cmd_create "ops" \
        --layout "split-h:htop|journalctl -f" \
        --window "shell:bash"
      ;;
    fullstack)
      cmd_create "fullstack" \
        --window "frontend:cd $root/frontend 2>/dev/null || cd $root" \
        --window "backend:cd $root/backend 2>/dev/null || cd $root/api 2>/dev/null || cd $root" \
        --window "database:cd $root" \
        --window "shell:cd $root"
      ;;
    *)
      die "Unknown template: $template. Available: dev, ops, fullstack"
      ;;
  esac
}

cmd_export() {
  local name="$1"
  local save_file="$SAVED_DIR/${name}.yaml"

  if [[ -f "$save_file" ]]; then
    cat "$save_file"
  elif session_exists "$name"; then
    cmd_save "$name"
    cat "$save_file"
  else
    die "Session '$name' not found (active or saved)"
  fi
}

cmd_import() {
  local file="$1"
  [[ -f "$file" ]] || die "File not found: $file"

  local sname
  sname=$(grep '^name:' "$file" | head -1 | awk '{print $2}')
  [[ -n "$sname" ]] || die "No session name found in $file"

  cp "$file" "$SAVED_DIR/${sname}.yaml"
  log "✅ Imported session '$sname'. Use 'restore $sname' to launch."
}

cmd_profile() {
  local profile_name="$1"
  local profile_file="$PROFILES_DIR/${profile_name}.yaml"

  [[ -f "$profile_file" ]] || die "Profile not found: $profile_file"

  # Parse profile YAML and create session
  local sname=""
  local root=""
  local windows_args=()

  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue

    if [[ "$line" =~ ^name:[[:space:]]*(.*) ]]; then
      sname="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^root:[[:space:]]*(.*) ]]; then
      root="${BASH_REMATCH[1]}"
      root="${root/#\~/$HOME}"
    elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]name:[[:space:]]*(.*) ]]; then
      local wname="${BASH_REMATCH[1]}"
      # Read next line for command
      IFS= read -r next_line || true
      local wcmd=""
      if [[ "$next_line" =~ ^[[:space:]]*command:[[:space:]]*(.*) ]]; then
        wcmd="${BASH_REMATCH[1]}"
      fi
      if [[ -n "$root" && -n "$wcmd" ]]; then
        windows_args+=(--window "$wname:cd $root && $wcmd")
      elif [[ -n "$root" ]]; then
        windows_args+=(--window "$wname:cd $root")
      elif [[ -n "$wcmd" ]]; then
        windows_args+=(--window "$wname:$wcmd")
      else
        windows_args+=(--window "$wname:bash")
      fi
    fi
  done < "$profile_file"

  [[ -n "$sname" ]] || sname="$profile_name"
  cmd_create "$sname" "${windows_args[@]}"
}

# --- Main ---

usage() {
  cat <<EOF
Tmux Session Manager

Usage: $0 <command> [args]

Commands:
  create <name> [--window "name:cmd"] [--layout "type:cmd1|cmd2"]
  save <name>           Save session layout to disk
  save-all              Save all active sessions
  restore <name>        Restore saved session
  restore-all           Restore all saved sessions
  list                  List active and saved sessions
  kill <name>           Kill a session
  attach <name>         Attach to session (restore/create if needed)
  template <name> [dir] Create from template (dev, ops, fullstack)
  profile <name>        Create from YAML profile
  export <name>         Export session config to stdout
  import <file>         Import session config from YAML file

Environment:
  TMUX_SESSIONS_DIR     Save directory (default: ~/.tmux-sessions)
EOF
}

[[ $# -ge 1 ]] || { usage; exit 1; }

CMD="$1"; shift

case "$CMD" in
  create)      [[ $# -ge 1 ]] || die "Usage: create <name> [options]"; cmd_create "$@" ;;
  save)        [[ $# -ge 1 ]] || die "Usage: save <name>"; cmd_save "$1" ;;
  save-all)    cmd_save_all ;;
  restore)     [[ $# -ge 1 ]] || die "Usage: restore <name>"; cmd_restore "$1" ;;
  restore-all) cmd_restore_all ;;
  list)        cmd_list ;;
  kill)        [[ $# -ge 1 ]] || die "Usage: kill <name>"; cmd_kill "$1" ;;
  attach)      [[ $# -ge 1 ]] || die "Usage: attach <name>"; cmd_attach "$1" ;;
  template)    [[ $# -ge 1 ]] || die "Usage: template <name> [dir]"; cmd_template "$@" ;;
  profile)     [[ $# -ge 1 ]] || die "Usage: profile <name>"; cmd_profile "$1" ;;
  export)      [[ $# -ge 1 ]] || die "Usage: export <name>"; cmd_export "$1" ;;
  import)      [[ $# -ge 1 ]] || die "Usage: import <file>"; cmd_import "$1" ;;
  help|--help|-h) usage ;;
  *)           die "Unknown command: $CMD. Run '$0 help' for usage." ;;
esac
