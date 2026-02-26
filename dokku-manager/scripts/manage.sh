#!/bin/bash
# Dokku Manager — Wrapper for common Dokku operations
# Provides a unified interface with validation and helpful output
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[dokku]${NC} $1"; }
warn() { echo -e "${YELLOW}[dokku]${NC} $1"; }
err() { echo -e "${RED}[dokku]${NC} $1" >&2; }
info() { echo -e "${CYAN}[dokku]${NC} $1"; }

# Plugin URLs
declare -A PLUGIN_URLS=(
    [postgres]="https://github.com/dokku/dokku-postgres.git"
    [redis]="https://github.com/dokku/dokku-redis.git"
    [mysql]="https://github.com/dokku/dokku-mysql.git"
    [mongo]="https://github.com/dokku/dokku-mongo.git"
    [letsencrypt]="https://github.com/dokku/dokku-letsencrypt.git"
    [rabbitmq]="https://github.com/dokku/dokku-rabbitmq.git"
    [elasticsearch]="https://github.com/dokku/dokku-elasticsearch.git"
    [memcached]="https://github.com/dokku/dokku-memcached.git"
    [mariadb]="https://github.com/dokku/dokku-mariadb.git"
    [couchdb]="https://github.com/dokku/dokku-couchdb.git"
    [nats]="https://github.com/dokku/dokku-nats.git"
    [clickhouse]="https://github.com/dokku/dokku-clickhouse.git"
)

check_dokku() {
    if ! command -v dokku &>/dev/null; then
        err "Dokku is not installed. Run: sudo bash scripts/install.sh"
        exit 1
    fi
}

# ---- App Management ----

cmd_app_create() {
    local app="${1:?Usage: manage.sh app:create <app-name>}"
    log "Creating app '${app}'..."
    dokku apps:create "$app"
    log "App '${app}' created. Deploy with: git push dokku@$(hostname):${app} main"
}

cmd_app_destroy() {
    local app="${1:?Usage: manage.sh app:destroy <app-name>}"
    warn "This will permanently destroy '${app}' and all its data."
    dokku apps:destroy "$app"
}

cmd_apps_list() {
    info "Deployed apps:"
    dokku apps:list
}

# ---- Config Management ----

cmd_config() {
    local app="${1:?Usage: manage.sh config <app-name>}"
    dokku config:show "$app"
}

cmd_config_set() {
    local app="${1:?Usage: manage.sh config:set <app-name> KEY=VALUE ...}"
    shift
    if [[ $# -eq 0 ]]; then
        err "Provide at least one KEY=VALUE pair"
        exit 1
    fi
    log "Setting config for '${app}'..."
    dokku config:set "$app" "$@"
    log "Config updated (app will restart)"
}

cmd_config_unset() {
    local app="${1:?Usage: manage.sh config:unset <app-name> KEY ...}"
    shift
    dokku config:unset "$app" "$@"
}

# ---- Domain Management ----

cmd_domains_set() {
    local app="${1:?Usage: manage.sh domains:set <app-name> <domain>}"
    local domain="${2:?Provide a domain}"
    log "Setting domain '${domain}' for '${app}'..."
    dokku domains:set "$app" "$domain"
}

cmd_domains_add() {
    local app="${1:?Usage: manage.sh domains:add <app-name> <domain>}"
    local domain="${2:?Provide a domain}"
    dokku domains:add "$app" "$domain"
    log "Domain '${domain}' added to '${app}'"
}

cmd_domains_remove() {
    local app="${1:?Usage: manage.sh domains:remove <app-name> <domain>}"
    local domain="${2:?Provide a domain}"
    dokku domains:remove "$app" "$domain"
}

cmd_domains_report() {
    local app="${1:-}"
    if [[ -n "$app" ]]; then
        dokku domains:report "$app"
    else
        dokku domains:report
    fi
}

# ---- Plugin Management ----

cmd_plugin_install() {
    local plugin="${1:?Usage: manage.sh plugin:install <plugin-name>}"
    local url="${PLUGIN_URLS[$plugin]:-}"
    if [[ -z "$url" ]]; then
        err "Unknown plugin: ${plugin}"
        err "Available: ${!PLUGIN_URLS[*]}"
        exit 1
    fi
    log "Installing plugin '${plugin}' from ${url}..."
    sudo dokku plugin:install "$url" "$plugin"
    log "Plugin '${plugin}' installed"
}

cmd_plugin_list() {
    dokku plugin:list
}

# ---- Database Shortcuts ----

cmd_db_action() {
    local db_type="$1"
    local action="$2"
    shift 2
    dokku "${db_type}:${action}" "$@"
}

# ---- SSL / Let's Encrypt ----

cmd_letsencrypt_enable() {
    local app="${1:?Usage: manage.sh letsencrypt:enable <app-name>}"
    log "Enabling Let's Encrypt SSL for '${app}'..."
    dokku letsencrypt:enable "$app"
    log "SSL enabled for '${app}'"
}

cmd_letsencrypt_cron() {
    local action="${1:---add}"
    dokku letsencrypt:cron-job "$action"
    log "Let's Encrypt cron job configured"
}

# ---- Process Management ----

cmd_ps_scale() {
    local app="${1:?Usage: manage.sh ps:scale <app-name> <type>=<count> ...}"
    shift
    dokku ps:scale "$app" "$@"
}

cmd_ps_report() {
    local app="${1:-}"
    if [[ "$app" == "--all" || -z "$app" ]]; then
        dokku ps:report
    else
        dokku ps:report "$app"
    fi
}

cmd_ps_restart() {
    local app="${1:?Usage: manage.sh ps:restart <app-name>}"
    log "Restarting '${app}'..."
    dokku ps:restart "$app"
}

cmd_logs() {
    local app="${1:?Usage: manage.sh logs <app-name> [--tail]}"
    shift
    dokku logs "$app" "$@"
}

# ---- Checks ----

cmd_checks_enable() {
    local app="${1:?Usage: manage.sh checks:enable <app-name>}"
    dokku checks:enable "$app"
}

cmd_checks_set() {
    local app="${1:?Usage: manage.sh checks:set <app-name> <path>}"
    local path="${2:-/}"
    echo "WAIT=10 TIMEOUT=60 ATTEMPTS=5 URL=${path}" | dokku checks:set "$app"
    log "Health check set: ${path}"
}

# ---- Storage ----

cmd_storage_mount() {
    local app="${1:?Usage: manage.sh storage:mount <app-name> <host-path>:<container-path>}"
    local mapping="${2:?Provide host:container path mapping}"
    dokku storage:mount "$app" "$mapping"
    log "Storage mounted for '${app}': ${mapping}"
}

# ---- Docker Options ----

cmd_docker_options_add() {
    local app="${1:?Usage: manage.sh docker-options:add <app-name> <phase> <option>}"
    local phase="${2:?Provide phase: build|deploy|run}"
    local option="${3:?Provide Docker option}"
    dokku docker-options:add "$app" "$phase" "$option"
}

# ---- Buildpacks ----

cmd_buildpacks_set() {
    local app="${1:?Usage: manage.sh buildpacks:set <app-name> <buildpack-url>}"
    local buildpack="${2:?Provide buildpack URL}"
    dokku buildpacks:set "$app" "$buildpack"
}

cmd_builder_set() {
    local app="${1:?Usage: manage.sh builder:set <app-name> <builder>}"
    local builder="${2:?Provide builder: herokuish|dockerfile|pack}"
    dokku builder:set "$app" selected "$builder"
}

# ---- Report ----

cmd_report() {
    info "=== Dokku Status Report ==="
    echo ""
    info "Version: $(dokku version)"
    echo ""
    info "--- Apps ---"
    dokku apps:list 2>/dev/null || echo "  (none)"
    echo ""
    info "--- Plugins ---"
    dokku plugin:list 2>/dev/null || echo "  (none)"
    echo ""
    info "--- Global Domains ---"
    dokku domains:report --global 2>/dev/null || echo "  (none)"
}

# ---- Main Router ----

main() {
    check_dokku

    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        app:create)          cmd_app_create "$@" ;;
        app:destroy)         cmd_app_destroy "$@" ;;
        apps:list)           cmd_apps_list ;;
        config)              cmd_config "$@" ;;
        config:set)          cmd_config_set "$@" ;;
        config:unset)        cmd_config_unset "$@" ;;
        domains:set)         cmd_domains_set "$@" ;;
        domains:add)         cmd_domains_add "$@" ;;
        domains:remove)      cmd_domains_remove "$@" ;;
        domains:report)      cmd_domains_report "$@" ;;
        plugin:install)      cmd_plugin_install "$@" ;;
        plugin:list)         cmd_plugin_list ;;
        postgres:*)          cmd_db_action postgres "${cmd#postgres:}" "$@" ;;
        redis:*)             cmd_db_action redis "${cmd#redis:}" "$@" ;;
        mysql:*)             cmd_db_action mysql "${cmd#mysql:}" "$@" ;;
        mongo:*)             cmd_db_action mongo "${cmd#mongo:}" "$@" ;;
        letsencrypt:enable)  cmd_letsencrypt_enable "$@" ;;
        letsencrypt:cron-job) cmd_letsencrypt_cron "$@" ;;
        ps:scale)            cmd_ps_scale "$@" ;;
        ps:report)           cmd_ps_report "$@" ;;
        ps:restart)          cmd_ps_restart "$@" ;;
        logs)                cmd_logs "$@" ;;
        checks:enable)       cmd_checks_enable "$@" ;;
        checks:set)          cmd_checks_set "$@" ;;
        storage:mount)       cmd_storage_mount "$@" ;;
        docker-options:add)  cmd_docker_options_add "$@" ;;
        buildpacks:set)      cmd_buildpacks_set "$@" ;;
        builder:set)         cmd_builder_set "$@" ;;
        report)              cmd_report ;;
        help|--help|-h)
            echo "Usage: manage.sh <command> [args...]"
            echo ""
            echo "App Management:"
            echo "  app:create <name>           Create a new app"
            echo "  app:destroy <name>          Destroy an app"
            echo "  apps:list                   List all apps"
            echo ""
            echo "Configuration:"
            echo "  config <app>                Show app config"
            echo "  config:set <app> K=V...     Set config variables"
            echo "  config:unset <app> KEY...   Remove config variables"
            echo ""
            echo "Domains:"
            echo "  domains:set <app> <domain>  Set app domain"
            echo "  domains:add <app> <domain>  Add domain to app"
            echo "  domains:remove <app> <dom>  Remove domain"
            echo "  domains:report [app]        Show domain config"
            echo ""
            echo "Plugins:"
            echo "  plugin:install <name>       Install a plugin"
            echo "  plugin:list                 List installed plugins"
            echo ""
            echo "Databases:"
            echo "  postgres:create <name>      Create Postgres DB"
            echo "  postgres:link <db> <app>    Link DB to app"
            echo "  postgres:export <db>        Export DB to stdout"
            echo "  postgres:import <db>        Import DB from stdin"
            echo "  redis:create/link/...       Same for Redis"
            echo "  mysql:create/link/...       Same for MySQL"
            echo ""
            echo "SSL:"
            echo "  letsencrypt:enable <app>    Enable SSL"
            echo "  letsencrypt:cron-job        Setup auto-renewal"
            echo ""
            echo "Processes:"
            echo "  ps:scale <app> web=N...     Scale processes"
            echo "  ps:report [app|--all]       Process report"
            echo "  ps:restart <app>            Restart app"
            echo "  logs <app> [--tail]         View logs"
            echo ""
            echo "Other:"
            echo "  checks:enable <app>         Enable deploy checks"
            echo "  checks:set <app> <path>     Set health check path"
            echo "  storage:mount <app> <map>   Mount persistent storage"
            echo "  docker-options:add ...      Add Docker options"
            echo "  buildpacks:set <app> <url>  Set buildpack"
            echo "  builder:set <app> <type>    Set builder type"
            echo "  report                      Full status report"
            ;;
        *)
            # Pass through to dokku directly
            dokku "$cmd" "$@"
            ;;
    esac
}

main "$@"
