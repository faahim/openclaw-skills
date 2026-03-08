# Mise Tool Manager — Examples

## Example 1: Full-Stack Web Project

```toml
# .mise.toml
[tools]
node = "22"
python = "3.12"

[env]
DATABASE_URL = "postgres://localhost:5432/myapp"
REDIS_URL = "redis://localhost:6379"
NODE_ENV = "development"

[tasks.dev]
run = "npm run dev"
description = "Start dev server"

[tasks.api]
run = "uvicorn api.main:app --reload"
description = "Start API server"

[tasks.db-migrate]
run = "python manage.py migrate"
description = "Run database migrations"
```

## Example 2: Microservices Monorepo

```toml
# services/auth/.mise.toml
[tools]
go = "1.22"

[env]
JWT_SECRET = "dev-secret"
PORT = "8001"

[tasks.run]
run = "go run ./cmd/auth"

[tasks.test]
run = "go test ./..."
```

```toml
# services/web/.mise.toml
[tools]
node = "22"
bun = "1.1"

[env]
PORT = "3000"
API_URL = "http://localhost:8001"

[tasks.dev]
run = "bun run dev"
```

## Example 3: Data Science Project

```toml
# .mise.toml
[tools]
python = "3.11"  # Match production version

[env]
PYTHONPATH = "{{config_root}}/src"
JUPYTER_CONFIG_DIR = "{{config_root}}/.jupyter"

[tasks.notebook]
run = "jupyter lab"

[tasks.train]
run = "python src/train.py"

[tasks.test]
run = "pytest tests/ -v"
```

## Example 4: CI/CD with GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v2
      - run: mise run test
```

## Common Commands Cheat Sheet

```bash
# Installation
mise use --global node@lts      # Set global Node
mise use python@3.12             # Set project Python
mise install                     # Install all from .mise.toml

# Inspection
mise current                     # Show active versions
mise ls                          # List all installed
mise ls-remote python            # Available Python versions
mise where node                  # Show install path

# Cleanup
mise prune                       # Remove unused versions
mise uninstall node@18           # Remove specific version

# Tasks
mise run dev                     # Run a task
mise tasks                       # List available tasks

# Troubleshooting
mise doctor                      # Diagnose issues
mise self-update                 # Update mise itself
```
