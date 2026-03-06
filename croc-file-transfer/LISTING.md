# Listing Copy: Croc File Transfer

## Metadata
- **Type:** Skill
- **Name:** croc-file-transfer
- **Display Name:** Croc File Transfer
- **Categories:** [communication, productivity]
- **Price:** $8
- **Dependencies:** [croc]
- **Icon:** 🐊

## Tagline

Send files between any two computers securely with a simple code phrase

## Description

Transferring files between computers shouldn't require SSH keys, cloud uploads, or port forwarding. Yet here we are, uploading to Google Drive just to download on another machine.

Croc File Transfer installs and configures croc — a tool that lets you send files between any two computers with end-to-end encryption using just a code phrase. Sender runs one command, gets a code. Receiver enters the code. Done. Works through NATs, firewalls, across networks, and between operating systems.

**What it does:**
- 📁 Send files and folders with a single command
- 🔒 End-to-end encrypted (PAKE key exchange — no pre-shared keys)
- 🌐 Works through firewalls and NATs via relay servers
- ⚡ Auto-detects LAN for direct fast transfers
- 🔄 Resume interrupted transfers automatically
- 🖥️ Works on Linux, macOS, Windows, FreeBSD, Android
- 🏠 Self-host your own relay server for privacy
- 📊 Pipe support for streaming data between machines

**Who it's for:** Developers, sysadmins, and anyone who transfers files between machines and is tired of the scp/rsync/cloud-upload dance.

## Quick Start Preview

```bash
# Install croc
bash scripts/install.sh

# Send a file
croc send document.pdf
# → Code is: castle-mango-delta-seven

# On the other computer
croc castle-mango-delta-seven
# → File received!
```

## Core Capabilities

1. Single-file transfer — Send any file with one command
2. Folder transfer — Automatically compresses, transfers, and decompresses
3. Multi-file transfer — Send multiple files in one go
4. Custom codes — Choose your own code phrase for easy sharing
5. Pipe support — Stream command output between machines
6. Self-hosted relay — Run your own relay for privacy and speed
7. Auto-resume — Interrupted transfers pick up automatically
8. LAN detection — Direct transfer on same network (max speed)
9. Cross-platform — Linux, macOS, Windows, FreeBSD, Android
10. Speed throttling — Limit bandwidth for shared connections

## Dependencies
- `croc` (auto-installed by scripts/install.sh — single Go binary, ~10 MB)

## Installation Time
**2 minutes** — Run install script, start sending files
