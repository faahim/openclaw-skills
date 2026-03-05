---
name: taskfile-manager
description: >-
  Install and manage Task (go-task) — a modern, simpler alternative to Make for running project tasks and automation.
categories: [dev-tools, productivity]
dependencies: [bash, curl]
---

# Taskfile Manager

## What This Does

Installs and manages [Task](https://taskfile.dev) (go-task/task) — a modern task runner that replaces Makefiles with simple YAML. Define project tasks, dependencies, environment variables, and watch mode in a clean `Taskfile.yml`. No tabs-vs-spaces headaches, no shell quirks.

**Example:** "Install Task, scaffold a Taskfile for your project, run `task build` instead of remembering complex CLI commands."

## Quick Start (2 minutes)

### 1. Install Task

```bash
bash scripts/install.sh
```

### 2. Initialize a Taskfile

```bash
bash scripts/init.sh
# Creates Taskfile.yml in current directory
```

### 3. Run a Task

```bash
task hello
# Output: Hello from Task! 🎯
```

## Core Workflows

### Workflow 1: Install Task

```bash
bash scripts/install.sh
# Detects OS/arch, downloads latest release, installs to ~/.local/bin or /usr/local/bin
```

Verifies installation:
```
✅ Task v3.40.1 installed at /usr/local/bin/task
```

### Workflow 2: Scaffold a Project Taskfile

```bash
bash scripts/init.sh [--template node|python|go|rust|docker|generic]
```

Templates include common tasks for each stack:
- **node**: install, dev, build, test, lint, format, clean
- **python**: venv, install, test, lint, format, run
- **go**: build, test, lint, run, clean
- **rust**: build, test, run, clean, release
- **docker**: build, up, down, logs, clean
- **generic** (default): build, test, run, clean

### Workflow 3: List Available Tasks

```bash
task --list
# Or short form:
task -l
```

Output:
```
* build:    Build the project
* test:     Run tests
* dev:      Start development server
* clean:    Remove build artifacts
```

### Workflow 4: Run Tasks with Variables

```bash
task deploy ENV=production
task build OUTPUT=./dist/app
```

### Workflow 5: Watch Mode

```bash
task dev --watch
# Reruns task when source files change
```

### Workflow 6: Run Multiple Tasks

```bash
task build test deploy
# Runs in sequence
```

### Workflow 7: Generate Taskfile from Makefile

```bash
bash scripts/convert-makefile.sh [path/to/Makefile]
# Parses Makefile targets and generates equivalent Taskfile.yml
```

## Configuration

### Taskfile.yml Format

```yaml
version: '3'

vars:
  APP_NAME: myapp
  BUILD_DIR: ./dist

env:
  CGO_ENABLED: '0'

tasks:
  default:
    desc: Show available tasks
    cmds:
      - task --list

  build:
    desc: Build the project
    sources:
      - ./src/**/*.go
    generates:
      - '{{.BUILD_DIR}}/{{.APP_NAME}}'
    cmds:
      - go build -o {{.BUILD_DIR}}/{{.APP_NAME}} ./cmd/main.go

  test:
    desc: Run tests
    cmds:
      - go test ./... -v -cover

  dev:
    desc: Start development server
    watch: true
    sources:
      - ./**/*.go
    cmds:
      - go run ./cmd/main.go

  clean:
    desc: Remove build artifacts
    cmds:
      - rm -rf {{.BUILD_DIR}}

  lint:
    desc: Run linter
    cmds:
      - golangci-lint run ./...

  docker:build:
    desc: Build Docker image
    cmds:
      - docker build -t {{.APP_NAME}}:latest .

  deploy:
    desc: Deploy to production
    deps: [build, test]
    cmds:
      - echo "Deploying {{.APP_NAME}}..."
```

### Key Features

- **`sources` / `generates`**: Skip task if outputs are newer than inputs (like Make)
- **`deps`**: Run dependency tasks first (parallel by default)
- **`watch`**: Auto-rerun on file changes
- **`dotenv`**: Load `.env` files automatically
- **`platforms`**: Restrict tasks to specific OS (linux, darwin, windows)
- **`internal`**: Hide tasks from `--list`
- **Namespaces**: Use `:` separator for grouped tasks (`docker:build`, `docker:push`)

### Environment & Dotenv

```yaml
version: '3'

dotenv: ['.env', '.env.local']

tasks:
  deploy:
    env:
      DEPLOY_ENV: '{{.CLI_ARGS}}'
    cmds:
      - ./deploy.sh
```

## Advanced Usage

### Task Dependencies (Parallel)

```yaml
tasks:
  ci:
    deps: [lint, test, build]
    cmds:
      - echo "CI complete ✅"
```

`lint`, `test`, `build` run in parallel; `echo` runs after all complete.

### Conditional Execution

```yaml
tasks:
  install:
    status:
      - test -d node_modules
    cmds:
      - npm install
```

Skips `npm install` if `node_modules` exists.

### Include Other Taskfiles

```yaml
version: '3'

includes:
  docker: ./taskfiles/Docker.yml
  ci: ./taskfiles/CI.yml
```

Run with `task docker:build` or `task ci:test`.

### Platform-Specific Tasks

```yaml
tasks:
  open:
    platforms: [darwin]
    cmds:
      - open ./dist/index.html

  open:
    platforms: [linux]
    cmds:
      - xdg-open ./dist/index.html
```

## Troubleshooting

### Issue: "task: command not found"

**Fix:** Ensure `~/.local/bin` is in PATH:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: "task: No Taskfile found"

**Fix:** Create one with `bash scripts/init.sh` or ensure you're in the right directory.

### Issue: Task keeps re-running (sources not working)

**Fix:** Check `sources` globs match your files. Use `task --verbose` to debug.

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- Task binary (installed by `scripts/install.sh`)
