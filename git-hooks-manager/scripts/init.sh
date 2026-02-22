#!/bin/bash
# Initialize pre-commit hooks in a repository
set -e

REPO_PATH="${1:-.}"
PROFILE="minimal"

# Parse args
shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --profile) PROFILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate repo
if [ ! -d "$REPO_PATH/.git" ]; then
  echo "❌ Not a git repository: $REPO_PATH"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$REPO_PATH/.pre-commit-config.yaml"

echo "🔧 Initializing git hooks in: $REPO_PATH"
echo "   Profile: $PROFILE"

# Generate config based on profile
generate_minimal() {
  cat <<'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ['--maxkb=500']
      - id: check-merge-conflict
      - id: mixed-line-ending
EOF
}

generate_security() {
  generate_minimal
  cat <<'EOF'

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: detect-private-key
EOF
}

generate_python() {
  generate_security
  cat <<'EOF'

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
EOF
}

generate_javascript() {
  generate_security
  cat <<'EOF'

  - repo: https://github.com/pre-commit/mirrors-eslint
    rev: v9.9.0
    hooks:
      - id: eslint
        additional_dependencies:
          - eslint@9.9.0

  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v4.0.0-alpha.8
    hooks:
      - id: prettier
EOF
}

generate_full() {
  generate_python
  cat <<'EOF'

  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v4.0.0-alpha.8
    hooks:
      - id: prettier
        types_or: [javascript, jsx, ts, tsx, json, yaml, markdown, css, scss]

  - repo: https://github.com/compilerla/conventional-pre-commit
    rev: v3.4.0
    hooks:
      - id: conventional-pre-commit
        stages: [commit-msg]
        args: [feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert]

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: check-toml
      - id: check-xml
      - id: check-symlinks
      - id: check-executables-have-shebangs
EOF
}

# Write config
case "$PROFILE" in
  minimal)    generate_minimal > "$CONFIG_FILE" ;;
  security)   generate_security > "$CONFIG_FILE" ;;
  python)     generate_python > "$CONFIG_FILE" ;;
  javascript) generate_javascript > "$CONFIG_FILE" ;;
  full)       generate_full > "$CONFIG_FILE" ;;
  *)          echo "❌ Unknown profile: $PROFILE"; echo "   Available: minimal, security, python, javascript, full"; exit 1 ;;
esac

echo "📄 Created: $CONFIG_FILE"

# Install hooks
cd "$REPO_PATH"
export PATH="$HOME/.local/bin:$PATH"

if command -v pre-commit &>/dev/null; then
  echo "📦 Installing hooks..."
  pre-commit install
  pre-commit install --hook-type commit-msg 2>/dev/null || true
  echo "✅ Git hooks installed! They'll run automatically on every commit."
  echo ""
  echo "   Test now: pre-commit run --all-files"
  echo "   Skip once: git commit --no-verify -m 'message'"
else
  echo "⚠️  pre-commit not found. Run 'bash scripts/install.sh' first."
  echo "   Config file created — hooks will work once pre-commit is installed."
fi
