#!/bin/bash
# Initialize a Taskfile.yml in the current directory
set -euo pipefail

TEMPLATE="${1:-generic}"
# Strip --template prefix if provided
[[ "$TEMPLATE" == "--template" ]] && TEMPLATE="${2:-generic}"

OUTPUT="Taskfile.yml"

if [[ -f "$OUTPUT" ]]; then
  echo "⚠️  Taskfile.yml already exists."
  read -r -p "Overwrite? [y/N] " REPLY
  [[ "$REPLY" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

case "$TEMPLATE" in
  node)
    cat > "$OUTPUT" << 'EOF'
version: '3'

dotenv: ['.env', '.env.local']

vars:
  NODE_ENV: development

tasks:
  default:
    desc: Show available tasks
    cmds: [task --list]

  install:
    desc: Install dependencies
    status: [test -d node_modules]
    cmds: [npm install]

  dev:
    desc: Start development server
    deps: [install]
    cmds: [npm run dev]

  build:
    desc: Build for production
    deps: [install]
    env:
      NODE_ENV: production
    cmds: [npm run build]

  test:
    desc: Run tests
    deps: [install]
    cmds: [npm test]

  lint:
    desc: Run linter
    deps: [install]
    cmds: [npx eslint .]

  format:
    desc: Format code
    cmds: [npx prettier --write .]

  clean:
    desc: Remove build artifacts
    cmds:
      - rm -rf node_modules dist .next out
EOF
    ;;

  python)
    cat > "$OUTPUT" << 'EOF'
version: '3'

dotenv: ['.env']

vars:
  VENV: .venv
  PYTHON: '{{.VENV}}/bin/python'
  PIP: '{{.VENV}}/bin/pip'

tasks:
  default:
    desc: Show available tasks
    cmds: [task --list]

  venv:
    desc: Create virtual environment
    status: [test -d {{.VENV}}]
    cmds: [python3 -m venv {{.VENV}}]

  install:
    desc: Install dependencies
    deps: [venv]
    cmds: ['{{.PIP}} install -r requirements.txt']

  run:
    desc: Run the application
    deps: [install]
    cmds: ['{{.PYTHON}} -m app']

  test:
    desc: Run tests
    deps: [install]
    cmds: ['{{.PYTHON}} -m pytest -v']

  lint:
    desc: Run linter
    deps: [install]
    cmds: ['{{.PYTHON}} -m ruff check .']

  format:
    desc: Format code
    deps: [install]
    cmds: ['{{.PYTHON}} -m ruff format .']

  clean:
    desc: Remove build artifacts
    cmds:
      - rm -rf {{.VENV}} __pycache__ .pytest_cache dist *.egg-info
EOF
    ;;

  go)
    cat > "$OUTPUT" << 'EOF'
version: '3'

vars:
  APP_NAME:
    sh: basename $(pwd)
  BUILD_DIR: ./dist

tasks:
  default:
    desc: Show available tasks
    cmds: [task --list]

  build:
    desc: Build the binary
    sources: [./**/*.go, go.mod, go.sum]
    generates: ['{{.BUILD_DIR}}/{{.APP_NAME}}']
    cmds:
      - mkdir -p {{.BUILD_DIR}}
      - go build -o {{.BUILD_DIR}}/{{.APP_NAME}} .

  run:
    desc: Run the application
    cmds: [go run .]

  test:
    desc: Run tests
    cmds: [go test ./... -v -cover]

  lint:
    desc: Run linter
    cmds: [golangci-lint run ./...]

  tidy:
    desc: Tidy go modules
    cmds: [go mod tidy]

  clean:
    desc: Remove build artifacts
    cmds: [rm -rf {{.BUILD_DIR}}]
EOF
    ;;

  rust)
    cat > "$OUTPUT" << 'EOF'
version: '3'

tasks:
  default:
    desc: Show available tasks
    cmds: [task --list]

  build:
    desc: Build (debug)
    cmds: [cargo build]

  release:
    desc: Build (release)
    cmds: [cargo build --release]

  run:
    desc: Run the application
    cmds: [cargo run]

  test:
    desc: Run tests
    cmds: [cargo test]

  lint:
    desc: Run clippy
    cmds: [cargo clippy -- -D warnings]

  format:
    desc: Format code
    cmds: [cargo fmt]

  clean:
    desc: Remove build artifacts
    cmds: [cargo clean]
EOF
    ;;

  docker)
    cat > "$OUTPUT" << 'EOF'
version: '3'

vars:
  IMAGE_NAME:
    sh: basename $(pwd)
  COMPOSE_FILE: docker-compose.yml

tasks:
  default:
    desc: Show available tasks
    cmds: [task --list]

  build:
    desc: Build Docker image
    cmds: [docker build -t {{.IMAGE_NAME}}:latest .]

  up:
    desc: Start services
    cmds: [docker compose -f {{.COMPOSE_FILE}} up -d]

  down:
    desc: Stop services
    cmds: [docker compose -f {{.COMPOSE_FILE}} down]

  logs:
    desc: Follow logs
    cmds: [docker compose -f {{.COMPOSE_FILE}} logs -f]

  ps:
    desc: List running containers
    cmds: [docker compose -f {{.COMPOSE_FILE}} ps]

  exec:
    desc: Exec into service (use -- SERVICE CMD)
    cmds: ['docker compose -f {{.COMPOSE_FILE}} exec {{.CLI_ARGS}}']

  clean:
    desc: Remove containers, images, volumes
    cmds:
      - docker compose -f {{.COMPOSE_FILE}} down -v --rmi local
      - docker image prune -f
EOF
    ;;

  generic|*)
    cat > "$OUTPUT" << 'EOF'
version: '3'

vars:
  APP_NAME:
    sh: basename $(pwd)

tasks:
  default:
    desc: Show available tasks
    cmds: [task --list]

  hello:
    desc: Verify Task is working
    cmds:
      - echo "Hello from Task! 🎯"

  build:
    desc: Build the project
    cmds:
      - echo "Building {{.APP_NAME}}..."
      # Add your build commands here

  test:
    desc: Run tests
    cmds:
      - echo "Running tests..."
      # Add your test commands here

  run:
    desc: Run the project
    cmds:
      - echo "Running {{.APP_NAME}}..."
      # Add your run commands here

  clean:
    desc: Remove build artifacts
    cmds:
      - echo "Cleaning up..."
      # Add your clean commands here
EOF
    ;;
esac

echo "✅ Created ${OUTPUT} (template: ${TEMPLATE})"
echo ""
echo "Next steps:"
echo "  task --list     # See available tasks"
echo "  task hello      # Run a task (generic template)"
echo "  task build      # Build the project"
