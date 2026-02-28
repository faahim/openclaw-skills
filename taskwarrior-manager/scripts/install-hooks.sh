#!/bin/bash
# Install Taskwarrior hooks for automation
set -e

HOOKS_DIR="$HOME/.task/hooks"
mkdir -p "$HOOKS_DIR"

# On-complete hook: log completions
cat > "$HOOKS_DIR/on-complete.log-completion" << 'HOOK'
#!/bin/bash
# Log task completions to a file
LOG_FILE="$HOME/.task/completions.log"
while read -r line; do
  DESC=$(echo "$line" | jq -r '.description // "unknown"')
  PROJECT=$(echo "$line" | jq -r '.project // "none"')
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $DESC (project:$PROJECT)" >> "$LOG_FILE"
  echo "$line"
done
HOOK
chmod +x "$HOOKS_DIR/on-complete.log-completion"

# On-add hook: validate tasks have descriptions
cat > "$HOOKS_DIR/on-add.validate" << 'HOOK'
#!/bin/bash
# Reject tasks with empty descriptions
while read -r line; do
  DESC=$(echo "$line" | jq -r '.description // ""')
  if [[ -z "$DESC" || "$DESC" == "null" ]]; then
    echo "❌ Task must have a description" >&2
    exit 1
  fi
  echo "$line"
done
HOOK
chmod +x "$HOOKS_DIR/on-add.validate"

echo "✅ Hooks installed to $HOOKS_DIR"
echo "  - on-complete: logs completions to ~/.task/completions.log"
echo "  - on-add: validates tasks have descriptions"
echo ""
echo "View hooks: ls -la $HOOKS_DIR"
