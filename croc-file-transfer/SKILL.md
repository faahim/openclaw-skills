---
name: croc-file-transfer
description: >-
  Send and receive files between any two computers securely with end-to-end encryption. Works through NATs and firewalls.
categories: [communication, productivity]
dependencies: [croc]
---

# Croc File Transfer

## What This Does

Send files and folders between any two computers using end-to-end encrypted transfer. No port forwarding, no SSH keys, no cloud upload — sender runs one command, gets a secret code, receiver enters the same code. Works across networks, through firewalls, and between different operating systems.

**Example:** "Send a 2GB folder from your laptop to your server using a secret code."

## Quick Start (2 minutes)

### 1. Install Croc

```bash
bash scripts/install.sh
```

### 2. Send a File

```bash
# Send a file — croc generates a secret
croc send myfile.txt

# Output:
# Sending 'myfile.txt' (4.2 kB)
# Your secret code is displayed — share it with the receiver
# The receiver sets CROC_SECRET=<code> and runs: croc
```

### 3. Receive a File

```bash
# On the receiving computer, set the secret and receive
CROC_SECRET=<the-code> croc

# Or interactively:
croc
# Enter receive code: <the-code>
```

## Core Workflows

### Workflow 1: Send a Single File

```bash
croc send path/to/file.pdf
```

Croc displays a secret code. Share it with the receiver through any channel (chat, voice, etc.).

### Workflow 2: Send a Folder

```bash
croc send path/to/folder/
```

Croc automatically compresses, transfers, and decompresses the folder.

### Workflow 3: Send with Custom Code

```bash
# Set your own secret via environment variable
CROC_SECRET=my-secret-phrase croc send file.tar.gz
```

### Workflow 4: Send Multiple Files

```bash
croc send file1.txt file2.pdf file3.png
```

### Workflow 5: Send Text Directly

```bash
croc send --text "Hello from server A"
```

### Workflow 6: Use a Custom Relay

```bash
# Self-host a relay (on a VPS with open port)
croc relay --ports 9009,9010-9013

# Send using your relay
croc --relay yourserver.com:9009 send file.txt

# Receive using your relay
CROC_SECRET=<code> croc --relay yourserver.com:9009
```

### Workflow 7: Send with QR Code

```bash
# Display QR code for easy sharing of the receive command
croc send --qr file.txt
```

## Configuration

### Environment Variables

```bash
# Set a custom secret code for sending/receiving
export CROC_SECRET="my-secret-phrase"

# Use a specific relay server
export CROC_RELAY="myrelay.example.com:9009"

# Relay password (if relay requires auth)
export CROC_PASS="relay-password"
```

### Useful Flags

```bash
# Automatically accept incoming files
croc --yes

# Redirect received file to stdout
croc --stdout

# Send without local network discovery (force relay)
croc send --no-local file.txt

# Zip folder before sending
croc send --zip folder/

# Exclude files matching patterns
croc send --exclude ".git,.env" folder/

# Respect .gitignore when sending folders
croc send --git folder/

# Custom relay port
croc send --port 9009 file.txt

# Show QR code for receive command
croc send --qr file.txt

# Use built-in DNS resolver
croc --internal-dns send file.txt

# Choose hash algorithm (xxhash, imohash, md5)
croc send --hash md5 file.txt
```

## Advanced Usage

### Self-Host a Relay Server

By default, croc uses public relay servers. For privacy or speed, host your own:

```bash
# Start relay (runs on port 9009 + transfer ports)
croc relay

# Run as systemd service
sudo bash scripts/setup-relay.sh

# Clients use your relay
croc --relay yourserver.com:9009 send file.txt
```

### Scripted / Automated Transfers

```bash
# Sender: set known secret, send file
CROC_SECRET=known-phrase croc send file.txt &

# Receiver: use same secret, auto-accept
CROC_SECRET=known-phrase croc --yes
```

### Benchmark Transfer Speed

```bash
dd if=/dev/zero of=/tmp/test-100mb bs=1M count=100
croc send /tmp/test-100mb
```

## Troubleshooting

### Issue: "croc: command not found"

```bash
bash scripts/install.sh
```

### Issue: Transfer stuck / not connecting

1. **Firewall blocking:** Try `croc send --no-local file.txt` to force relay
2. **Relay down:** Use `croc --relay different-relay.com:9009 send file.txt`
3. **Corporate proxy:** Croc uses TCP port 9009. Self-host relay on port 443.

### Issue: Slow transfer on LAN

Croc auto-detects local network. If not working, ensure both machines are on the same subnet and local discovery isn't blocked by firewall rules.

### Issue: "room not ready, maybe peer disconnected"

The receiver needs to be running when the sender is active. Start both within a few minutes of each other.

## How It Works

1. **PAKE (Password-Authenticated Key Exchange):** The secret code establishes a secure channel
2. **End-to-end encryption:** Files are encrypted before leaving the sender
3. **Relay-assisted NAT traversal:** Relay servers help punch through firewalls (relay never sees unencrypted data)
4. **Local network detection:** If both machines are on the same network, transfers happen directly (faster)
5. **Multiplexed transfers:** Uses multiple connections for speed

## Dependencies

- `croc` (single binary, ~10 MB — installed by scripts/install.sh)
- No runtime dependencies — statically compiled Go binary

## Key Principles

1. **Simple** — One command to send, one to receive
2. **Secure** — End-to-end encrypted, PAKE key exchange, secrets via env vars
3. **Universal** — Works on Linux, macOS, Windows, FreeBSD, Android
4. **NAT-friendly** — Works through firewalls without port forwarding
5. **Fast** — Local network detection + multiplexed transfers
