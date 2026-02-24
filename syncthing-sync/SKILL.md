---
name: syncthing-sync
description: >-
  Install and manage Syncthing for peer-to-peer file synchronization across devices — no cloud required.
categories: [data, automation]
dependencies: [bash, curl, jq]
---

# Syncthing File Sync Manager

## What This Does

Installs, configures, and manages [Syncthing](https://syncthing.net/) — a continuous P2P file synchronization tool. Sync folders across multiple devices without any cloud service. All traffic is encrypted and authenticated.

**Example:** "Set up Syncthing, share my `~/projects` folder with my VPS, monitor sync status, get alerts on conflicts."

## Quick Start (5 minutes)

### 1. Install Syncthing

```bash
bash scripts/install.sh
```

This auto-detects your OS (Debian/Ubuntu/Fedora/Arch/macOS) and installs Syncthing via the official repo.

### 2. Start Syncthing

```bash
bash scripts/run.sh start
# Syncthing Web UI: http://127.0.0.1:8384
# API key auto-detected from config
```

### 3. Check Status

```bash
bash scripts/run.sh status
# Output:
# ✅ Syncthing running (PID 12345)
# 📂 Shared folders: 2
# 🖥️ Connected devices: 1/2
# 🔄 Sync: 100% complete
```

## Core Workflows

### Workflow 1: Add a Shared Folder

```bash
bash scripts/run.sh add-folder \
  --path ~/projects \
  --label "Projects" \
  --id projects
```

### Workflow 2: Add a Remote Device

```bash
bash scripts/run.sh add-device \
  --device-id "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH" \
  --name "My VPS"
```

### Workflow 3: Share Folder with Device

```bash
bash scripts/run.sh share-folder \
  --folder-id projects \
  --device-id "AAAAAAA-BBBBBBB-..."
```

### Workflow 4: Monitor Sync Progress

```bash
bash scripts/run.sh sync-status
# Output:
# 📂 Projects: ✅ Up to Date (1,234 files, 2.3 GB)
# 📂 Documents: 🔄 Syncing (89%, 45 files remaining)
# 📂 Photos: ⏸️ Paused
```

### Workflow 5: Check for Conflicts

```bash
bash scripts/run.sh conflicts
# Output:
# ⚠️ 2 sync conflicts found:
# - ~/projects/readme.md.sync-conflict-20260224-120000-ABCDEFG
# - ~/documents/notes.txt.sync-conflict-20260224-130000-HIJKLMN
```

### Workflow 6: Get Device ID (for pairing)

```bash
bash scripts/run.sh device-id
# Output: XXXXXXX-YYYYYYY-ZZZZZZZ-1111111-2222222-3333333-4444444-5555555
```

## Configuration

### Environment Variables

```bash
# Override API key (auto-detected from ~/.local/state/syncthing/config.xml by default)
export SYNCTHING_API_KEY="your-api-key"

# Override API URL (default: http://127.0.0.1:8384)
export SYNCTHING_URL="http://127.0.0.1:8384"

# Telegram alerts for conflicts/errors
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
```

## Advanced Usage

### Run as Systemd Service

```bash
bash scripts/run.sh enable-service
# Creates and enables syncthing systemd user service
# Auto-starts on boot
```

### Set Folder to Send-Only (Backup Mode)

```bash
bash scripts/run.sh set-folder-type \
  --folder-id projects \
  --type sendonly
```

Types: `sendreceive` (default), `sendonly`, `receiveonly`, `receiveencrypted`

### Ignore Patterns

```bash
bash scripts/run.sh set-ignores \
  --folder-id projects \
  --patterns "node_modules" ".git" "*.tmp" ".DS_Store"
```

### Scheduled Sync (Pause/Resume on Schedule)

```bash
# Pause sync during work hours, resume at night
bash scripts/run.sh pause --folder-id projects
bash scripts/run.sh resume --folder-id projects
```

### Get Full Config as JSON

```bash
bash scripts/run.sh config
```

## Troubleshooting

### Issue: "Syncthing not found"

```bash
bash scripts/install.sh  # Re-run installer
```

### Issue: Device not connecting

1. Check both devices are running: `bash scripts/run.sh status`
2. Verify device IDs match: `bash scripts/run.sh device-id`
3. Check firewall allows port 22000 (sync) and 21027 (discovery)
4. Try direct connection: `bash scripts/run.sh add-device --address tcp://IP:22000`

### Issue: Sync stuck

```bash
bash scripts/run.sh restart
bash scripts/run.sh sync-status --verbose
```

### Issue: Conflicts piling up

```bash
# List all conflicts
bash scripts/run.sh conflicts

# Auto-resolve by keeping newest
bash scripts/run.sh resolve-conflicts --strategy newest
```

## Dependencies

- `bash` (4.0+)
- `curl` (API calls)
- `jq` (JSON parsing)
- `syncthing` (installed by scripts/install.sh)
- Optional: `systemd` (for service management)
