#!/bin/bash
# Crontab Manager — Manage cron jobs with human-readable schedules, backup, validation, and monitoring
# Version: 1.0.0

set -euo pipefail

MANAGER_DIR="${CRONTAB_MANAGER_DIR:-$HOME/.crontab-manager}"
BACKUP_DIR="$MANAGER_DIR/backups"
LOG_DIR="$MANAGER_DIR/logs"
MAX_BACKUPS="${CRONTAB_MANAGER_MAX_BACKUPS:-30}"
LOG_DAYS="${CRONTAB_MANAGER_LOG_DAYS:-90}"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# ─── Human-readable schedule → cron expression ───────────────────────
parse_schedule() {
    local input="${1,,}" # lowercase
    
    case "$input" in
        "every minute")                     echo "* * * * *" ;;
        "every "*)
            local rest="${input#every }"
            case "$rest" in
                *" minutes"|*" mins")
                    local n=$(echo "$rest" | grep -oP '^\d+')
                    echo "*/$n * * * *" ;;
                *" hours"|*" hrs")
                    local n=$(echo "$rest" | grep -oP '^\d+')
                    echo "0 */$n * * *" ;;
                "hour")                     echo "0 * * * *" ;;
                "monday at "*)              echo "0 $(parse_time "${rest#monday at }") * * 1" ;;
                "tuesday at "*)             echo "0 $(parse_time "${rest#tuesday at }") * * 2" ;;
                "wednesday at "*)           echo "0 $(parse_time "${rest#wednesday at }") * * 3" ;;
                "thursday at "*)            echo "0 $(parse_time "${rest#thursday at }") * * 4" ;;
                "friday at "*)              echo "0 $(parse_time "${rest#friday at }") * * 5" ;;
                "saturday at "*)            echo "0 $(parse_time "${rest#saturday at }") * * 6" ;;
                "sunday at "*)              echo "0 $(parse_time "${rest#sunday at }") * * 0" ;;
                "15th at "*)                echo "0 $(parse_time "${rest#15th at }") 15 * *" ;;
                *)                          echo "" ;;
            esac ;;
        "daily at "*)
            local time="${input#daily at }"
            local parsed=$(parse_time "$time")
            local min=$(echo "$parsed" | cut -d' ' -f1)
            local hr=$(echo "$parsed" | cut -d' ' -f2)
            echo "$min $hr * * *" ;;
        "weekdays at "*)
            local time="${input#weekdays at }"
            local parsed=$(parse_time "$time")
            local min=$(echo "$parsed" | cut -d' ' -f1)
            local hr=$(echo "$parsed" | cut -d' ' -f2)
            echo "$min $hr * * 1-5" ;;
        "weekends at "*)
            local time="${input#weekends at }"
            local parsed=$(parse_time "$time")
            local min=$(echo "$parsed" | cut -d' ' -f1)
            local hr=$(echo "$parsed" | cut -d' ' -f2)
            echo "$min $hr * * 0,6" ;;
        "monthly on 1st at "*)
            local time="${input#monthly on 1st at }"
            local parsed=$(parse_time "$time")
            local min=$(echo "$parsed" | cut -d' ' -f1)
            local hr=$(echo "$parsed" | cut -d' ' -f2)
            echo "$min $hr 1 * *" ;;
        "yearly on jan 1")                  echo "0 0 1 1 *" ;;
        *)                                  echo "" ;;
    esac
}

# Parse time like "2am", "11:30pm", "14:00", "noon", "midnight"
parse_time() {
    local t="${1,,}"
    case "$t" in
        "midnight")   echo "0 0" ;;
        "noon")       echo "0 12" ;;
        *":"*)
            # Handle HH:MM or HH:MMam/pm
            local hr min
            if [[ "$t" =~ ([0-9]+):([0-9]+)(am|pm)? ]]; then
                hr="${BASH_REMATCH[1]}"
                min="${BASH_REMATCH[2]}"
                local ampm="${BASH_REMATCH[3]}"
                if [[ "$ampm" == "pm" && "$hr" -lt 12 ]]; then hr=$((hr + 12)); fi
                if [[ "$ampm" == "am" && "$hr" -eq 12 ]]; then hr=0; fi
            fi
            echo "$min $hr" ;;
        *"am")
            local hr="${t%am}"
            [[ "$hr" -eq 12 ]] && hr=0
            echo "0 $hr" ;;
        *"pm")
            local hr="${t%pm}"
            [[ "$hr" -lt 12 ]] && hr=$((hr + 12))
            echo "0 $hr" ;;
        *)
            echo "0 $t" ;;
    esac
}

# ─── Validate cron expression ────────────────────────────────────────
validate_cron() {
    local expr="$1"
    local -a fields
    read -ra fields <<< "$expr"
    
    if [[ ${#fields[@]} -ne 5 ]]; then
        echo "❌ Invalid: Expected 5 fields, got ${#fields[@]}"
        return 1
    fi
    
    # Validate ranges
    validate_field "${fields[0]}" 0 59 "minute" || return 1
    validate_field "${fields[1]}" 0 23 "hour" || return 1
    validate_field "${fields[2]}" 1 31 "day of month" || return 1
    validate_field "${fields[3]}" 1 12 "month" || return 1
    validate_field "${fields[4]}" 0 7 "day of week" || return 1
    
    echo "✅ Valid: $(explain_cron "$expr")"
    return 0
}

validate_field() {
    local field="$1" min="$2" max="$3" name="$4"
    
    [[ "$field" == "*" ]] && return 0
    
    # Handle */N
    if [[ "$field" =~ ^\*/([0-9]+)$ ]]; then
        local step="${BASH_REMATCH[1]}"
        if [[ "$step" -lt 1 || "$step" -gt "$max" ]]; then
            echo "❌ Invalid: $name step must be 1-$max (got $step)"
            return 1
        fi
        return 0
    fi
    
    # Handle comma-separated and ranges
    local IFS=','
    for part in $field; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local lo="${BASH_REMATCH[1]}" hi="${BASH_REMATCH[2]}"
            if [[ "$lo" -lt "$min" || "$hi" -gt "$max" || "$lo" -gt "$hi" ]]; then
                echo "❌ Invalid: $name range $lo-$hi out of bounds ($min-$max)"
                return 1
            fi
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            if [[ "$part" -lt "$min" || "$part" -gt "$max" ]]; then
                echo "❌ Invalid: $name must be $min-$max (got $part)"
                return 1
            fi
        else
            echo "❌ Invalid: Unrecognized $name value '$part'"
            return 1
        fi
    done
    return 0
}

# ─── Explain cron expression in English ──────────────────────────────
explain_cron() {
    local expr="$1"
    local -a fields
    read -ra fields <<< "$expr"
    local min="${fields[0]}" hr="${fields[1]}" dom="${fields[2]}" mon="${fields[3]}" dow="${fields[4]}"
    local desc=""
    
    # Time part
    if [[ "$min" == "*" && "$hr" == "*" ]]; then
        desc="Every minute"
    elif [[ "$min" =~ ^\*/([0-9]+)$ && "$hr" == "*" ]]; then
        desc="Every ${BASH_REMATCH[1]} minutes"
    elif [[ "$min" == "0" && "$hr" =~ ^\*/([0-9]+)$ ]]; then
        desc="Every ${BASH_REMATCH[1]} hours"
    elif [[ "$min" == "0" && "$hr" == "*" ]]; then
        desc="Every hour"
    elif [[ "$hr" != "*" && "$min" != "*" ]]; then
        local h="$hr" m="$min" ampm="AM"
        if [[ "$h" -ge 12 ]]; then ampm="PM"; [[ "$h" -gt 12 ]] && h=$((h - 12)); fi
        [[ "$h" -eq 0 ]] && h=12
        [[ "$m" -eq 0 ]] && m="00" || m=$(printf "%02d" "$m")
        desc="At ${h}:${m} ${ampm}"
    fi
    
    # Day part
    if [[ "$dow" == "1-5" ]]; then
        desc="$desc on weekdays"
    elif [[ "$dow" == "0,6" ]]; then
        desc="$desc on weekends"
    elif [[ "$dow" != "*" ]]; then
        local days=("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")
        desc="$desc on ${days[$dow]}"
    fi
    
    if [[ "$dom" != "*" ]]; then
        desc="$desc on day $dom of the month"
    fi
    
    if [[ "$mon" != "*" ]]; then
        local months=("" "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
        desc="$desc in ${months[$mon]}"
    fi
    
    echo "$desc"
}

# ─── List crontab entries with IDs ───────────────────────────────────
cmd_list() {
    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null) || { echo "No crontab for $(whoami)"; return 0; }
    
    echo "ID  Schedule              Command                                    Enabled"
    echo "──  ────────────────────  ─────────────────────────────────────────  ───────"
    
    local id=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local enabled="✅"
        local actual="$line"
        if [[ "$line" =~ ^#DISABLED# ]]; then
            enabled="⏸️"
            actual="${line#\#DISABLED#}"
        elif [[ "$line" =~ ^# ]]; then
            continue
        fi
        
        id=$((id + 1))
        local fields=($actual)
        local sched="${fields[0]} ${fields[1]} ${fields[2]} ${fields[3]} ${fields[4]}"
        local cmd="${fields[@]:5}"
        
        printf "%-3d %-21s %-42s %s\n" "$id" "$sched" "${cmd:0:42}" "$enabled"
    done <<< "$crontab_content"
    
    [[ "$id" -eq 0 ]] && echo "(no jobs)"
}

# ─── Add a cron job ──────────────────────────────────────────────────
cmd_add() {
    local cron_expr="" command="" use_log=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --schedule) 
                cron_expr=$(parse_schedule "$2")
                if [[ -z "$cron_expr" ]]; then
                    echo "❌ Could not parse schedule: $2"
                    echo "Try: 'every 5 minutes', 'daily at 2am', 'weekdays at 9am'"
                    return 1
                fi
                shift 2 ;;
            --cron)
                cron_expr="$2"
                shift 2 ;;
            --command)
                command="$2"
                shift 2 ;;
            --log)
                use_log=true
                shift ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
    done
    
    if [[ -z "$cron_expr" || -z "$command" ]]; then
        echo "Usage: crontab-manager add --schedule 'daily at 2am' --command '/path/to/script.sh'"
        return 1
    fi
    
    # Validate
    if ! validate_cron "$cron_expr" > /dev/null 2>&1; then
        validate_cron "$cron_expr"
        return 1
    fi
    
    # Auto-backup before modifying
    cmd_backup quiet
    
    # Wrap with logging if requested
    local final_cmd="$command"
    if $use_log; then
        local job_hash=$(echo "$command" | md5sum | cut -c1-8)
        local job_log_dir="$LOG_DIR/$job_hash"
        mkdir -p "$job_log_dir"
        final_cmd="$MANAGER_DIR/scripts/log-wrapper.sh '$command' '$job_log_dir'"
    fi
    
    # Append to crontab
    (crontab -l 2>/dev/null; echo "$cron_expr $final_cmd") | crontab -
    
    echo "✅ Added: $cron_expr $command"
    echo "   $(explain_cron "$cron_expr")"
}

# ─── Remove a job by ID ──────────────────────────────────────────────
cmd_remove() {
    local target_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id) target_id="$2"; shift 2 ;;
            *) echo "Unknown: $1"; return 1 ;;
        esac
    done
    
    [[ -z "$target_id" ]] && { echo "Usage: crontab-manager remove --id N"; return 1; }
    
    cmd_backup quiet
    
    local crontab_content id=0 new_content=""
    crontab_content=$(crontab -l 2>/dev/null) || return 1
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^#[^D] ]] && { new_content+="$line"$'\n'; continue; }
        id=$((id + 1))
        if [[ "$id" -eq "$target_id" ]]; then
            echo "✅ Removed job $target_id: $line"
        else
            new_content+="$line"$'\n'
        fi
    done <<< "$crontab_content"
    
    echo "$new_content" | crontab -
}

# ─── Disable/Enable a job ────────────────────────────────────────────
cmd_disable() {
    local target_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in --id) target_id="$2"; shift 2 ;; *) shift ;; esac
    done
    toggle_job "$target_id" "disable"
}

cmd_enable() {
    local target_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in --id) target_id="$2"; shift 2 ;; *) shift ;; esac
    done
    toggle_job "$target_id" "enable"
}

toggle_job() {
    local target_id="$1" action="$2"
    [[ -z "$target_id" ]] && { echo "Usage: crontab-manager $action --id N"; return 1; }
    
    cmd_backup quiet
    
    local crontab_content id=0 new_content=""
    crontab_content=$(crontab -l 2>/dev/null) || return 1
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ^#[^D] ]]; then
            new_content+="$line"$'\n'
            continue
        fi
        id=$((id + 1))
        if [[ "$id" -eq "$target_id" ]]; then
            if [[ "$action" == "disable" ]]; then
                local clean="${line#\#DISABLED#}"
                new_content+="#DISABLED#$clean"$'\n'
                echo "⏸️ Disabled job $target_id: $clean"
            else
                local clean="${line#\#DISABLED#}"
                new_content+="$clean"$'\n'
                echo "✅ Enabled job $target_id: $clean"
            fi
        else
            new_content+="$line"$'\n'
        fi
    done <<< "$crontab_content"
    
    echo "$new_content" | crontab -
}

# ─── Backup ──────────────────────────────────────────────────────────
cmd_backup() {
    local quiet="${1:-}"
    local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local file="$BACKUP_DIR/${ts}.crontab"
    
    crontab -l > "$file" 2>/dev/null || { [[ -z "$quiet" ]] && echo "No crontab to backup"; return 0; }
    
    [[ -z "$quiet" ]] && echo "✅ Backed up to $file"
    
    # Prune old backups
    local count=$(ls -1 "$BACKUP_DIR"/*.crontab 2>/dev/null | wc -l)
    if [[ "$count" -gt "$MAX_BACKUPS" ]]; then
        ls -1t "$BACKUP_DIR"/*.crontab | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
    fi
}

# ─── List backups ────────────────────────────────────────────────────
cmd_backups() {
    local id=0
    for f in $(ls -1t "$BACKUP_DIR"/*.crontab 2>/dev/null); do
        id=$((id + 1))
        local jobs=$(grep -c -v '^#\|^$' "$f" 2>/dev/null || echo 0)
        local name=$(basename "$f")
        echo "$id. $name ($jobs jobs)"
    done
    [[ "$id" -eq 0 ]] && echo "No backups found"
}

# ─── Restore from backup ─────────────────────────────────────────────
cmd_restore() {
    local target_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in --id) target_id="$2"; shift 2 ;; *) shift ;; esac
    done
    
    [[ -z "$target_id" ]] && { echo "Usage: crontab-manager restore --id N"; return 1; }
    
    # Backup current first
    cmd_backup quiet
    
    local file=$(ls -1t "$BACKUP_DIR"/*.crontab 2>/dev/null | sed -n "${target_id}p")
    [[ -z "$file" ]] && { echo "❌ Backup $target_id not found"; return 1; }
    
    crontab "$file"
    echo "✅ Restored from $(basename "$file")"
}

# ─── Diff current vs backup ──────────────────────────────────────────
cmd_diff() {
    local target_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in --id) target_id="$2"; shift 2 ;; *) shift ;; esac
    done
    
    [[ -z "$target_id" ]] && { echo "Usage: crontab-manager diff --id N"; return 1; }
    
    local file=$(ls -1t "$BACKUP_DIR"/*.crontab 2>/dev/null | sed -n "${target_id}p")
    [[ -z "$file" ]] && { echo "❌ Backup $target_id not found"; return 1; }
    
    diff --color=auto <(crontab -l 2>/dev/null) "$file" || true
}

# ─── Validate expression ─────────────────────────────────────────────
cmd_validate() {
    validate_cron "$1"
}

# ─── Explain expression ──────────────────────────────────────────────
cmd_explain() {
    echo "$(explain_cron "$1")"
}

# ─── Check cron service status ────────────────────────────────────────
cmd_status() {
    echo "=== Cron Service ==="
    if command -v systemctl &>/dev/null; then
        systemctl is-active cron 2>/dev/null || systemctl is-active crond 2>/dev/null || echo "inactive"
    elif command -v service &>/dev/null; then
        service cron status 2>/dev/null || service crond status 2>/dev/null || echo "unknown"
    else
        echo "Could not determine cron status"
    fi
    
    echo ""
    echo "=== Jobs ==="
    cmd_list
    
    echo ""
    echo "=== Backups ==="
    local bc=$(ls -1 "$BACKUP_DIR"/*.crontab 2>/dev/null | wc -l)
    echo "$bc backups stored"
}

# ─── History (from syslog) ────────────────────────────────────────────
cmd_history() {
    echo "=== Recent Cron Executions ==="
    if [[ -f /var/log/syslog ]]; then
        grep -i "cron\[" /var/log/syslog 2>/dev/null | tail -20
    elif [[ -f /var/log/cron ]]; then
        tail -20 /var/log/cron
    else
        journalctl -u cron --no-pager -n 20 2>/dev/null || echo "No cron logs found"
    fi
}

# ─── Failures ─────────────────────────────────────────────────────────
cmd_failures() {
    local days=7
    while [[ $# -gt 0 ]]; do
        case "$1" in --days) days="$2"; shift 2 ;; *) shift ;; esac
    done
    
    echo "=== Cron Failures (last $days days) ==="
    
    # Check log-wrapper logs
    local found=0
    for logdir in "$LOG_DIR"/*/; do
        [[ -d "$logdir" ]] || continue
        find "$logdir" -name "*.log" -mtime -"$days" -exec grep -l "EXIT_CODE=[^0]" {} \; 2>/dev/null | while read -r logfile; do
            found=1
            local ts=$(basename "$logfile" .log)
            local code=$(grep "EXIT_CODE=" "$logfile" | tail -1 | cut -d= -f2)
            local cmd=$(head -1 "$logfile" | sed 's/^# Command: //')
            echo "❌ $ts $cmd — exit $code"
        done
    done
    
    [[ "$found" -eq 0 ]] && echo "No failures found (only tracks jobs added with --log flag)"
}

# ─── Main ─────────────────────────────────────────────────────────────
main() {
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        list)       cmd_list ;;
        add)        cmd_add "$@" ;;
        remove)     cmd_remove "$@" ;;
        disable)    cmd_disable "$@" ;;
        enable)     cmd_enable "$@" ;;
        backup)     cmd_backup ;;
        backups)    cmd_backups ;;
        restore)    cmd_restore "$@" ;;
        diff)       cmd_diff "$@" ;;
        validate)   cmd_validate "$@" ;;
        explain)    cmd_explain "$@" ;;
        status)     cmd_status ;;
        history)    cmd_history ;;
        failures)   cmd_failures "$@" ;;
        help|--help|-h)
            echo "Crontab Manager — Manage cron jobs with human-readable schedules"
            echo ""
            echo "Commands:"
            echo "  list                          List all cron jobs"
            echo "  add --schedule '...' --command '...'  Add a job (human-readable)"
            echo "  add --cron '...' --command '...'      Add a job (cron expression)"
            echo "  remove --id N                 Remove a job"
            echo "  disable --id N                Disable a job (keeps it)"
            echo "  enable --id N                 Re-enable a disabled job"
            echo "  backup                        Backup current crontab"
            echo "  backups                       List backups"
            echo "  restore --id N                Restore from backup"
            echo "  diff --id N                   Diff current vs backup"
            echo "  validate '* * * * *'          Validate cron expression"
            echo "  explain '* * * * *'           Explain cron expression"
            echo "  status                        Show cron service + job status"
            echo "  history                       Show recent executions"
            echo "  failures [--days N]           Show failed jobs"
            ;;
        *)
            echo "Unknown command: $cmd (try 'help')"
            return 1 ;;
    esac
}

main "$@"
