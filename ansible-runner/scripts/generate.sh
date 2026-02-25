#!/bin/bash
# Ansible Playbook Runner — Playbook Generator
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLES_DIR="$SCRIPT_DIR/examples"

usage() {
  echo "Usage:"
  echo "  $0 server-setup [--packages PKG1,PKG2] [--user USER]"
  echo "  $0 deploy [--repo REPO_URL] [--path DEPLOY_PATH] [--service SERVICE_NAME]"
  echo "  $0 db-backup [--type postgres|mysql] [--db DBNAME] [--dest BACKUP_DIR]"
  echo "  $0 docker-deploy [--image IMAGE] [--port PORT] [--name CONTAINER_NAME]"
}

gen_server_setup() {
  local packages="nginx,certbot,fail2ban,ufw"
  local user="deploy"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --packages) packages="$2"; shift 2 ;;
      --user) user="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  IFS=',' read -ra PKG_ARRAY <<< "$packages"
  local pkg_list=""
  for p in "${PKG_ARRAY[@]}"; do
    pkg_list="$pkg_list\n        - $p"
  done

  local outfile="$EXAMPLES_DIR/generated-server-setup.yml"
  cat > "$outfile" << PLAYBOOK
---
- name: Server Setup & Hardening
  hosts: all
  become: true
  vars:
    deploy_user: ${user}
    packages:$(echo -e "$pkg_list")

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install packages
      apt:
        name: "{{ packages }}"
        state: present

    - name: Create deploy user
      user:
        name: "{{ deploy_user }}"
        shell: /bin/bash
        groups: sudo
        append: yes
        create_home: yes

    - name: Allow deploy user sudo without password
      lineinfile:
        path: /etc/sudoers.d/{{ deploy_user }}
        line: "{{ deploy_user }} ALL=(ALL) NOPASSWD:ALL"
        create: yes
        mode: '0440'

    - name: Configure UFW defaults
      ufw:
        state: enabled
        policy: deny
        direction: incoming
      when: "'ufw' in packages"

    - name: Allow SSH through UFW
      ufw:
        rule: allow
        port: '22'
        proto: tcp
      when: "'ufw' in packages"

    - name: Allow HTTP/HTTPS through UFW
      ufw:
        rule: allow
        port: "{{ item }}"
        proto: tcp
      loop:
        - '80'
        - '443'
      when: "'ufw' in packages"

    - name: Enable fail2ban
      service:
        name: fail2ban
        state: started
        enabled: yes
      when: "'fail2ban' in packages"
PLAYBOOK

  echo "✅ Generated: $outfile"
  echo "   Run: bash scripts/run.sh playbook examples/generated-server-setup.yml"
}

gen_deploy() {
  local repo="" path="/opt/app" service="app"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --repo) repo="$2"; shift 2 ;;
      --path) path="$2"; shift 2 ;;
      --service) service="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$repo" ]; then
    echo "❌ --repo is required"
    exit 1
  fi

  local outfile="$EXAMPLES_DIR/generated-deploy.yml"
  cat > "$outfile" << PLAYBOOK
---
- name: Deploy Application
  hosts: all
  become: true
  vars:
    repo_url: "${repo}"
    deploy_path: "${path}"
    service_name: "${service}"
    app_version: "{{ version | default('main') }}"

  tasks:
    - name: Ensure git is installed
      apt:
        name: git
        state: present

    - name: Clone/update repository
      git:
        repo: "{{ repo_url }}"
        dest: "{{ deploy_path }}"
        version: "{{ app_version }}"
        force: yes
      register: git_result

    - name: Install dependencies (Node.js)
      command: npm install --production
      args:
        chdir: "{{ deploy_path }}"
      when: git_result.changed
      ignore_errors: yes

    - name: Install dependencies (Python)
      command: pip3 install -r requirements.txt
      args:
        chdir: "{{ deploy_path }}"
      when: git_result.changed
      ignore_errors: yes

    - name: Restart service
      systemd:
        name: "{{ service_name }}"
        state: restarted
        daemon_reload: yes
      when: git_result.changed

    - name: Wait for service to start
      wait_for:
        port: 3000
        delay: 5
        timeout: 30
      ignore_errors: yes

    - name: Health check
      uri:
        url: "http://localhost:3000/health"
        status_code: 200
      register: health
      ignore_errors: yes

    - name: Report status
      debug:
        msg: "Deploy {{ 'succeeded' if health.status == 200 else 'completed (health check failed)' }} — version: {{ app_version }}"
PLAYBOOK

  echo "✅ Generated: $outfile"
  echo "   Run: bash scripts/run.sh playbook examples/generated-deploy.yml --extra-vars 'version=v2.1.0'"
}

gen_db_backup() {
  local dbtype="postgres" dbname="myapp" dest="/backups"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --type) dbtype="$2"; shift 2 ;;
      --db) dbname="$2"; shift 2 ;;
      --dest) dest="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local outfile="$EXAMPLES_DIR/generated-db-backup.yml"

  local dump_cmd
  if [ "$dbtype" = "postgres" ]; then
    dump_cmd="pg_dump -U postgres {{ db_name }} | gzip > {{ backup_dest }}/{{ db_name }}_{{ ansible_date_time.iso8601_basic_short }}.sql.gz"
  else
    dump_cmd="mysqldump -u root {{ db_name }} | gzip > {{ backup_dest }}/{{ db_name }}_{{ ansible_date_time.iso8601_basic_short }}.sql.gz"
  fi

  cat > "$outfile" << PLAYBOOK
---
- name: Database Backup
  hosts: databases
  become: true
  vars:
    db_name: "${dbname}"
    db_type: "${dbtype}"
    backup_dest: "${dest}"
    keep_days: 7

  tasks:
    - name: Create backup directory
      file:
        path: "{{ backup_dest }}"
        state: directory
        mode: '0750'

    - name: Dump database
      shell: >
        ${dump_cmd}
      register: backup_result

    - name: Remove old backups
      shell: >
        find {{ backup_dest }} -name "{{ db_name }}_*.sql.gz" -mtime +{{ keep_days }} -delete
      changed_when: false

    - name: Report backup size
      shell: "ls -lh {{ backup_dest }}/{{ db_name }}_*.sql.gz | tail -1"
      register: backup_size
      changed_when: false

    - name: Show result
      debug:
        msg: "✅ Backup complete: {{ backup_size.stdout }}"
PLAYBOOK

  echo "✅ Generated: $outfile"
  echo "   Run: bash scripts/run.sh playbook examples/generated-db-backup.yml"
}

# Main
case "${1:-}" in
  server-setup)
    shift; gen_server_setup "$@" ;;
  deploy)
    shift; gen_deploy "$@" ;;
  db-backup)
    shift; gen_db_backup "$@" ;;
  *)
    usage ;;
esac
